#!/bin/bash
# Proves a reading's play control is keyed by the feed, not invented.
#
# What this guards is a Listen button on a passage the publisher never
# recorded. Availability has to come from the feed, keyed by segment id
# or lesson number — never bundled (stale the next day), never computed
# from a filename. Archive entries today omit `segment_id`; until the
# pipeline emits it, the overlay key is absent and the control stays
# gone. That absence is the normal state, not a bug.
#
#   ./tools/verify_media_overlay.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# Comments are stripped first: a mention in prose is not a dependency
# and is not a derivation.
STRIPPED_OVERLAY="$(sed 's://.*::' "$REPO/ACIMDailyMinute/Utilities/MediaOverlay.swift")"
echo "$STRIPPED_OVERLAY" | grep -qE 'import[[:space:]]+(SwiftUI|SwiftData)|Bundle\.|CorpusService|filename|\.mp3' \
    && fail "MediaOverlay.swift imports a UI/storage framework, names Bundle/CorpusService, or derives a key from a filename"

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures: [String] = []
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

let decoder = JSONDecoder()

// 1. Today's archive JSON still decodes. Missing segment_id is not a
//    decode error and is not an invented key.
let currentArchive = """
{"date":"2026-09-09","text":"A passage.","source_reference":"Manual","audio_url":"https://archive.org/download/acim-daily-minute/2026-09-09.mp3"}
""".data(using: .utf8)!
let current = try decoder.decode(MediaOverlay.ArchiveMinute.self, from: currentArchive)
check(current.overlaySegmentId == nil, "current archive must not invent a segment id")
check(!current.audio_url.isEmpty, "current archive still carries its own audio for the Video row")

// 2. A zero or missing id is the same as absent: the overlay does not
//    treat them as a real segment.
let zero = try decoder.decode(
    MediaOverlay.ArchiveMinute.self,
    from: Data(#"{"date":"2026-09-09","text":"x","source_reference":"Text_A","audio_url":"https://x","segment_id":0}"#.utf8)
)
check(zero.overlaySegmentId == nil, "segment_id 0 is not a key")
check(MediaOverlay.overlaySegmentId(nil) == nil, "nil is not a key")
check(MediaOverlay.overlaySegmentId(0) == nil, "0 is not a key")
check(MediaOverlay.overlaySegmentId(-1) == nil, "a negative id is not a key")

// 3. When the pipeline emits the field, that integer is the overlay key.
let keyed = try decoder.decode(
    MediaOverlay.ArchiveMinute.self,
    from: Data(#"{"date":"2026-09-10","text":"x","source_reference":"Manual","audio_url":"https://archive.org/download/acim-daily-minute/2026-09-10.mp3","segment_id":11741,"youtube_id":"2_eAO5jBbHM"}"#.utf8)
)
check(keyed.overlaySegmentId == 11741, "pipeline segment_id is the overlay key, got \(String(describing: keyed.overlaySegmentId))")
check(keyed.youtube_id == "2_eAO5jBbHM", "youtube_id rides with the key")

// 4. Hit.resolve: the index wins when it has a value; the surface fills
// gaps; both empty is no overlay at all.
let both = MediaOverlay.Hit.resolve(
    indexAudio: "https://index/a.mp3",
    indexVideo: "abc",
    surfaceAudio: "https://surface/a.mp3",
    surfaceVideo: "zzz"
)
check(both?.audioURL == "https://index/a.mp3", "index audio wins over the surface")
check(both?.youtubeID == "abc", "index video wins over the surface")
check(both?.showsListen == true, "audio means Listen")
check(both?.showsWatch == true, "a video id means Watch")

let surfaceOnly = MediaOverlay.Hit.resolve(
    indexAudio: "",
    indexVideo: nil,
    surfaceAudio: "https://surface/a.mp3",
    surfaceVideo: nil
)
check(surfaceOnly?.audioURL == "https://surface/a.mp3", "empty index falls back to the surface")
check(surfaceOnly?.showsListen == true, "surface audio still shows Listen")
check(surfaceOnly?.showsWatch == false, "no video id means no Watch")

let videoOnly = MediaOverlay.Hit.resolve(
    indexAudio: nil,
    indexVideo: "abc",
    surfaceAudio: nil,
    surfaceVideo: nil
)
check(videoOnly?.showsListen == false, "video-only must not show Listen — audio-first")
check(videoOnly?.showsWatch == true, "video-only still offers Watch")

let none = MediaOverlay.Hit.resolve(
    indexAudio: "  ",
    indexVideo: "",
    surfaceAudio: nil,
    surfaceVideo: nil
)
check(none == nil, "whitespace is not a hit")

if failures.isEmpty {
    print("\(checks) checks, overlay keys only from the feed")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/MediaOverlay.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify"

# The live DTO must accept the same optional fields, or the harness is
# proving a type the app never decodes. Bounded to the struct itself so
# a nearby comment about the lesson endpoint cannot satisfy this.
DTO="$REPO/ACIMDailyMinute/Services/DataService.swift"
awk '/struct InlineArchiveMinuteDTO/,/^}/' "$DTO" | grep -q 'segment_id' \
    || fail "InlineArchiveMinuteDTO does not decode segment_id"
awk '/struct InlineArchiveMinuteDTO/,/^}/' "$DTO" | grep -q 'youtube_id' \
    || fail "InlineArchiveMinuteDTO does not decode youtube_id"

# Recording the pairing is the only way a later reading of the segment
# can find its MP3 after the rolling archive window has moved on.
grep -q 'SegmentMedia.record' "$REPO/ACIMDailyMinute/Services/ArchiveService.swift" \
    || fail "persistInlineMinutes never records SegmentMedia from archive segment_id"

# The Course reading of a Daily Minute passage is the overlay's home.
# The medium band is that overlay now — it still resolves through
# ReadingPlayControl / MediaOverlay, keyed by segment. A surface that
# inlines ListenButton against its own audioURL is not keyed by segment.
grep -q 'readingMediumBand' "$REPO/ACIMDailyMinute/Views/Segment/SegmentReadingView.swift" \
    || fail "SegmentReadingView has no feed-driven play overlay"

echo "media overlay is feed-keyed"
echo "OK"
