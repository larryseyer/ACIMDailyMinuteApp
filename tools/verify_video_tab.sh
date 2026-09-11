#!/bin/bash
# Proves the Video tab plays YouTube on iPhone/iPad/Mac, and that the
# television still builds its picture from the MP3 — it has no WebKit.
#
# What this guards is a day that opens as a reading with a Listen button.
# The tab exists to play the video. Audio is the Listen tab. The Course
# text is the Read tab. A long-press "Watch video" on Listen is not a
# Video tab.
#
#   ./tools/verify_video_tab.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$REPO/ACIMDailyMinute/Views/Archive/ArchiveDateDetailView.swift"
IDS="$REPO/ACIMDailyMinute/Utilities/YouTubeID.swift"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$FILE" ]] || fail "ArchiveDateDetailView.swift missing"

# Television: still the MP3-built player. No YouTube embed.
grep -q 'openPlayer' "$FILE" \
    || fail "tvOS Video day no longer opens the MP3-built player"

# Phone, iPad, Mac: the day is a YouTube player.
grep -q 'LiteYouTubeCard' "$FILE" \
    || fail "iOS/macOS Video day has no YouTube player"

# Bare ids and watch URLs both resolve — archive rows ship one, the
# podcast <link> ships the other.
#
# A day that prefers DailyMinute.youtubeID over the podcast plays
# yesterday when the JSON has not caught up. A lesson that prefers the
# archive row over DailyLesson.youtubeID plays a dead re-upload. A card
# that gives up after one 404 thumbnail never reaches the live id.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation
func check(_ cond: Bool, _ msg: String) { if !cond { fputs("FAIL: \(msg)\n", stderr); exit(1) } }
check(YouTubeID.resolve("2_eAO5jBbHM") == "2_eAO5jBbHM", "bare id")
check(YouTubeID.resolve("https://www.youtube.com/watch?v=SlAhY7QszJo") == "SlAhY7QszJo", "watch URL")
check(YouTubeID.resolve("https://youtu.be/Spt75SO4HhE") == "Spt75SO4HhE", "short URL")
check(YouTubeID.resolve("") == nil, "empty")
check(YouTubeID.resolve(nil) == nil, "nil")

let minute = YouTubeID.candidates(
    kind: .minute,
    archiveID: nil,
    dailyID: "2_eAO5jBbHM",
    podcastIDs: [
        "https://www.youtube.com/watch?v=SlAhY7QszJo",
        "https://www.youtube.com/watch?v=i_eRulGtwmI"
    ]
)
check(minute.first != "2_eAO5jBbHM", "minute must not play yesterday from daily JSON")
check(minute.contains("i_eRulGtwmI"), "minute keeps today's podcast id")
check(minute.first == "SlAhY7QszJo" || minute.first == "i_eRulGtwmI", "minute starts on a podcast id")

let lesson = YouTubeID.candidates(
    kind: .lesson,
    archiveID: "KndugwfvYNM",
    dailyID: "Bk398csx8As",
    podcastIDs: [
        "https://www.youtube.com/watch?v=Bk398csx8As",
        "https://www.youtube.com/watch?v=KndugwfvYNM"
    ]
)
check(lesson.first == "Bk398csx8As", "lesson prefers the live daily id")

let hq = YouTubeID.thumbnailAdvance(useFallback: false, index: 0, count: 2)
check(hq.index == 0 && hq.useFallback && !hq.giveUp, "maxres miss retries hq of the same id")
let next = YouTubeID.thumbnailAdvance(useFallback: true, index: 0, count: 2)
check(next.index == 1 && !next.useFallback && !next.giveUp, "hq miss advances to the next id")
let last = YouTubeID.thumbnailAdvance(useFallback: true, index: 1, count: 2)
check(last.giveUp, "last hq miss gives up")

print("youtube ids resolve")
print("OK")
SWIFT
swiftc -O "$IDS" "$WORK/main.swift" -o "$WORK/verify"
"$WORK/verify"

echo "Video tab plays YouTube off the television"
echo "OK"
