#!/bin/bash
# Proves the Video tab plays YouTube on iPhone/iPad/Mac, and that the
# television still builds its picture from the MP3 — it has no WebKit.
# Four shelves (Minute / Lesson / Text / Manual), default Lesson. A day
# without an id composes; Video does not open a reading.
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
DETAIL="$REPO/ACIMDailyMinute/Views/Archive/ArchiveDateDetailView.swift"
PLAYER="$REPO/ACIMDailyMinute/Views/TVPlayerView.swift"
CONTENT="$REPO/ACIMDailyMinute/App/ContentView.swift"
COURSE="$REPO/ACIMDailyMinute/Views/Course/CourseView.swift"
SHELF="$REPO/ACIMDailyMinute/Utilities/CourseShelf.swift"
PBX="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$FILE" ]] || fail "ArchiveDateDetailView.swift missing"
[[ -f "$SHELF" ]] || fail "CourseShelf.swift missing"
[[ -f "$COURSE" ]] || fail "CourseView.swift missing"

# Television: still the MP3-built player. No YouTube embed.
grep -q 'openPlayer' "$FILE" \
    || fail "tvOS Video day no longer opens the MP3-built player"

# Phone: the day is a landscape YouTube cover, not an inline embed
# whose fullscreen cannot be left.
grep -q 'FullScreenVideoCover' "$FILE" \
    || fail "iOS Video day has no full-screen YouTube cover"

grep -q 'CourseShelf.allCases' "$COURSE" \
    || fail "Course contents is not CourseShelf.allCases"
if grep -q 'LiteYouTubeCard' "$COURSE"; then
    fail "Course still embeds LiteYouTubeCard"
fi
grep -q 'FullScreenVideoCover' "$DETAIL" \
    || fail "iOS Video day has no full-screen YouTube cover"
grep -q 'openPlayer' "$DETAIL" \
    || fail "a day without YouTube no longer composes"

if grep -q 'No video for this day' "$DETAIL"; then
    fail "published day without YouTube is still an empty state"
fi

# Whole-file tvOS fence is gone; remote chrome stays wrapped.
# NR==2 must itself be the unindented fence — a later wrapped #if os(tvOS)
# must not keep the range open and fail a lifted file.
if awk 'NR==1,/^#if os\(tvOS\)$/{ if (NR==2 && /^#if os\(tvOS\)$/) found=1 } END { exit found?0:1 }' "$PLAYER"; then
    fail "TVPlayerView.swift is still fenced to tvOS for the whole file"
fi
grep -q 'onPlayPauseCommand' "$PLAYER" \
    || fail "tvOS remote play/pause was deleted"
grep -q 'typealias TVPlayerFont' "$PLAYER" \
    || fail "Mac has no font alias for the composed player"

# -F: the source has a literal backslash in environment(\.openPlayer.
# BRE 'environment(\.openPlayer' matches a dot, not the backslash.
grep -Fq 'environment(\.openPlayer' "$CONTENT" \
    || fail "ContentView does not install openPlayer"
grep -q 'fullScreenCover(item: $playerItem' "$CONTENT" \
    || fail "ContentView does not present TVPlayerView"
if grep -A3 'TVPlayerView(item: item)' "$CONTENT" | grep -q 'environment(audioManager)'; then
    :
else
    fail "TVPlayerView cover is not given AudioManager"
fi

for name in VideoLibrary.swift VideoPlayableRow.swift; do
    count=$(grep -c "$name" "$PBX" || true)
    [[ "$count" -ge 6 ]] || fail "$name has $count pbxproj lines"
done

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
