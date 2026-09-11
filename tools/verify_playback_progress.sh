#!/bin/bash
# Proves a Listen position survives the session that made it, and that Listen
# can tell now-playing from part-finished from downloaded from finished without
# becoming a second catalogue of the Course.
#
# What this guards is a tab that forgets. PlaybackHistory only records that an
# episode was opened; AudioManager.currentTime dies with the process. Without a
# stored position there is no "part-finished", and Listen cannot be activity —
# it can only be a list of feeds, which is the Course organised a second time.
#
# ⛔ The compile line names ONE source file and no others. The rule must stay
# free of SwiftUI, SwiftData, Bundle, UserDefaults, AudioManager and
# CorpusService, or a reader's place in a recording could only be exercised
# by launching the app.
#
#   ./tools/verify_playback_progress.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SRC="$REPO/ACIMDailyMinute/Utilities/PlaybackProgress.swift"

if [[ ! -f "$SRC" ]]; then
  echo "FAIL: PlaybackProgress.swift does not exist — Listen has no playback progress"
  exit 1
fi

# A lone-file `swiftc` links SwiftUI and SwiftData without complaint if the file
# imports them, so the compile alone cannot prove the boundary. Comments are
# stripped first: what must stay out of this file is a DEPENDENCY, and the doc
# comments name several of these very types precisely to say they are not used.
stripped="$(sed -e 's://.*::' "$SRC")"
for banned in SwiftUI SwiftData CorpusService UserDefaults Bundle AudioManager; do
  if grep -q "$banned" <<<"$stripped"; then
    echo "FAIL: PlaybackProgress.swift reaches $banned — a reader's listen place must not depend on it" >&2
    exit 1
  fi
done

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures: [String] = []
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

func date(_ offset: Double) -> Date {
    Date(timeIntervalSinceReferenceDate: 780_000_000 + offset)
}

// MARK: - 1. Nothing to record yields nothing at all

check(PlaybackProgress.make(episodeID: "", position: 12, duration: 60, at: date(0)) == nil,
      "an empty episode id must not set a place")
check(PlaybackProgress.make(episodeID: "   ", position: 12, duration: 60, at: date(0)) == nil,
      "a whitespace episode id must not set a place")

// MARK: - 2. Position is clamped, never refused, never NaN

if let p = PlaybackProgress.make(episodeID: "ep-1", position: -4, duration: 60, at: date(1)) {
    check(p.position == 0, "a negative position must clamp to 0, got \(p.position)")
} else {
    check(false, "a negative position must still record the episode")
}

if let p = PlaybackProgress.make(episodeID: "ep-1", position: 90, duration: 60, at: date(1)) {
    check(p.position == 60, "past the end must clamp to duration, got \(p.position)")
    check(p.isFinished, "clamping to duration must be finished")
} else {
    check(false, "a past-the-end position must still record the episode")
}

check(PlaybackProgress.make(episodeID: "ep-1", position: .nan, duration: 60, at: date(1)) == nil,
      "NaN position must not record a lying place")
check(PlaybackProgress.make(episodeID: "ep-1", position: 12, duration: .infinity, at: date(1)) == nil,
      "non-finite duration must not record a lying place")

// MARK: - 3. Finished is the last two seconds, and a Daily Minute is in that set

if let minute = PlaybackProgress.make(episodeID: "min", position: 58, duration: 60, at: date(2)) {
    check(minute.isFinished, "58s of a 60s minute must be finished")
    check(!minute.isInProgress, "finished is not in progress")
} else {
    check(false, "a minute near its end must record")
}

if let minute = PlaybackProgress.make(episodeID: "min", position: 57.9, duration: 60, at: date(2)) {
    check(!minute.isFinished, "57.9s of a 60s minute is still in progress")
    check(minute.isInProgress, "57.9s of a 60s minute must be in progress")
} else {
    check(false, "a minute mid-way must record")
}

if let short = PlaybackProgress.make(episodeID: "short", position: 3, duration: 5, at: date(2)) {
    check(short.isFinished, "remaining 2s of a 5s file must be finished")
} else {
    check(false, "a short file near its end must record")
}

if let unknown = PlaybackProgress.make(episodeID: "unk", position: 12, duration: 0, at: date(2)) {
    check(!unknown.isFinished, "duration 0 must never claim finished")
    check(unknown.isInProgress, "a known position with unknown duration is in progress")
} else {
    check(false, "unknown duration with a position must still record")
}

// MARK: - 4. A blip is not in progress, and finished starts over

if let blip = PlaybackProgress.make(episodeID: "ep-1", position: 0.4, duration: 60, at: date(3)) {
    check(!blip.isInProgress, "under one second must not be in progress")
    check(!blip.isFinished, "a blip is not finished")
} else {
    check(false, "a blip must still record so it can be ignored rather than crash")
}

if let done = PlaybackProgress.make(episodeID: "ep-1", position: 60, duration: 60, at: date(3)) {
    check(PlaybackProgress.resumePosition(done) == nil,
          "a finished reading must start over, not sit on its last frame")
} else {
    check(false, "a finished reading must record")
}

if let mid = PlaybackProgress.make(episodeID: "ep-1", position: 18.5, duration: 90, at: date(3)) {
    check(PlaybackProgress.resumePosition(mid) == 18.5,
          "an in-progress reading must resume where it stopped, got \(String(describing: PlaybackProgress.resumePosition(mid)))")
} else {
    check(false, "an in-progress reading must record")
}

check(PlaybackProgress.resumePosition(nil) == nil, "no progress means start at the beginning")

if let blip = PlaybackProgress.make(episodeID: "ep-1", position: 0.4, duration: 60, at: date(3)) {
    check(PlaybackProgress.resumePosition(blip) == nil,
          "a blip must start over rather than resume 400ms in")
}

// MARK: - 5. Round trip through the stored JSON

if let original = PlaybackProgress.make(episodeID: "guid-42", position: 33, duration: 120, at: date(4)) {
    let encoded = PlaybackProgress.encode(["guid-42": original])
    let decoded = PlaybackProgress.decode(encoded)
    check(decoded["guid-42"] == original, "a position must round-trip through its JSON")
    check(decoded.count == 1, "round trip must not invent a second episode")
} else {
    check(false, "a normal position must record")
}

check(PlaybackProgress.decode(Data()).isEmpty, "empty data yields no progress rather than a crash")
check(PlaybackProgress.decode(Data("not-json".utf8)).isEmpty,
      "garbage yields no progress rather than a crash")
check(PlaybackProgress.decode(Data("{}".utf8)).isEmpty, "an empty object is no progress")

let truncated = Data("{\"ep-1\":".utf8)
check(PlaybackProgress.decode(truncated).isEmpty, "truncated JSON yields no progress rather than a crash")

// An unknown key shape, or a later version's extra field, must not crash.
let extra = Data("{\"ep-1\":{\"episodeID\":\"ep-1\",\"position\":10,\"duration\":60,\"updatedAt\":780000010,\"extra\":true}}".utf8)
let extraDecoded = PlaybackProgress.decode(extra)
check(extraDecoded["ep-1"]?.position == 10, "a later key on a progress row must still read the place")

// MARK: - 6. Merge: later wins, never moves backwards, and the algebra holds

guard
    let early = PlaybackProgress.make(episodeID: "ep-1", position: 10, duration: 60, at: date(10)),
    let late = PlaybackProgress.make(episodeID: "ep-1", position: 40, duration: 60, at: date(20)),
    let other = PlaybackProgress.make(episodeID: "ep-2", position: 5, duration: 30, at: date(15))
else {
    check(false, "merge fixtures must record")
    // Keep going so the rest of the file still reports.
    fatalError("merge fixtures")
}

let mine = ["ep-1": early]
let theirs = ["ep-1": late, "ep-2": other]
let merged = PlaybackProgress.merged(mine, theirs)
check(merged["ep-1"]?.position == 40, "the later place is where the reader actually got to")
check(merged["ep-2"]?.position == 5, "an episode only the other device knows must arrive")

let backward = PlaybackProgress.merged(theirs, mine)
check(backward["ep-1"]?.position == 40, "merge must never move a place backwards in time")
check(merged == backward, "merge must be commutative")

let again = PlaybackProgress.merged(merged, theirs)
check(again == merged, "merge must be idempotent")

let third = PlaybackProgress.make(episodeID: "ep-3", position: 1, duration: 10, at: date(30))!
let abc = PlaybackProgress.merged(PlaybackProgress.merged(mine, theirs), ["ep-3": third])
let bc = PlaybackProgress.merged(theirs, ["ep-3": third])
let abc2 = PlaybackProgress.merged(mine, bc)
check(abc == abc2, "merge must be associative")

// Equal milliseconds: a total order, so the merge stays commutative.
let a = PlaybackProgress.make(episodeID: "tie", position: 10, duration: 60, at: date(7))!
let b = PlaybackProgress.make(episodeID: "tie", position: 20, duration: 60, at: date(7))!
let ab = PlaybackProgress.merged(["tie": a], ["tie": b])
let ba = PlaybackProgress.merged(["tie": b], ["tie": a])
check(ab == ba, "equal moments must still merge commutatively")
check(ab["tie"]?.position == 20, "the further place wins a tie, so a re-import does not rewind")

// MARK: - 7. Listen is activity: four buckets, exclusive, nothing unplayed

func bucket(
    active: Bool = false,
    progress: PlaybackProgress? = nil,
    listenedAt: Date? = nil,
    downloaded: Bool = false
) -> ListenActivity? {
    ListenActivity.classify(
        isActive: active,
        progress: progress,
        listenedAt: listenedAt,
        isDownloaded: downloaded
    )
}

check(bucket() == nil, "an unplayed, undownloaded episode is not activity — that is a catalogue")

let playing = PlaybackProgress.make(episodeID: "a", position: 12, duration: 60, at: date(1))!
check(bucket(active: true, progress: playing, listenedAt: date(1), downloaded: true) == .nowPlaying,
      "now playing wins over every other bucket")

let mid = PlaybackProgress.make(episodeID: "a", position: 12, duration: 60, at: date(1))!
check(bucket(progress: mid) == .inProgress, "a stored mid-point is part-finished")
check(bucket(progress: mid, listenedAt: date(1), downloaded: true) == .inProgress,
      "part-finished wins over downloaded and over a listened stamp")

let done = PlaybackProgress.make(episodeID: "a", position: 60, duration: 60, at: date(1))!
check(bucket(progress: done) == .finished, "played through is finished")
check(bucket(progress: done, downloaded: true) == .finished,
      "a finished download lives under finished, not downloaded")

check(bucket(listenedAt: date(1)) == .finished,
      "legacy PlaybackHistory with no progress is finished — that stamp meant opened")
check(bucket(listenedAt: date(1), downloaded: true) == .finished,
      "legacy listened plus a download is still finished")

check(bucket(downloaded: true) == .downloaded,
      "downloaded and never opened is downloaded")

let blipProgress = PlaybackProgress.make(episodeID: "a", position: 0.4, duration: 60, at: date(1))!
check(bucket(progress: blipProgress, downloaded: true) == .downloaded,
      "a blip plus a download is downloaded, not part-finished")
check(bucket(progress: blipProgress, listenedAt: date(1)) == .finished,
      "a blip plus a listened stamp is the legacy finished case")

check(bucket(active: true) == .nowPlaying,
      "now playing needs no stored progress")

if failures.isEmpty {
    print("\(checks) checks, a listen place round-trips and Listen stays activity")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

swiftc -O \
    "$SRC" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

if [[ ! -x "$WORK/verify" ]]; then
  echo "FAIL: PlaybackProgress.swift did not compile"
  exit 1
fi

"$WORK/verify"
