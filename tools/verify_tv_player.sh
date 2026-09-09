#!/bin/bash
# Proves a television lesson gets the MP3 the podcast feed already named,
# and that Select on a Text section has a player to open.
#
# What this guards:
#   1. Lessons 47 and 49 (and every other numbered lesson in the feed) have
#      narration at archive.org. Read used to attach audio only from the
#      DailyLesson JSON row — today's lesson — so Jump-to-47 played silent
#      while Listen had the file.
#   2. TextChapterView calls openPlayer. On tvOS a navigation destination
#      does not inherit an environment set on LessonsView's stack, and the
#      default OpenPlayerAction assertionFailure's: crash
#      ACIMDailyMinuteTV-2026-09-09-104129.ips. The player has to be
#      installed at ContentView, above the tabs.
#
# ⛔ LessonNarration.swift is compiled alone. It must stay free of SwiftUI
# and SwiftData, or the only way to prove a lesson number maps to an
# enclosure is by launching the television.
#
#   ./tools/verify_tv_player.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

var failures: [String] = []
func check(_ cond: Bool, _ message: String) {
    if !cond { failures.append(message) }
}

check(LessonNarration.number(fromTitle: "Lesson 47: “God is the Strength in which I trust.”") == 47,
      "title Lesson 47")
check(LessonNarration.number(fromTitle: "Lesson 49: “God’s Voice speaks to me all through the day.”") == 49,
      "title Lesson 49")
check(LessonNarration.number(fromTitle: "Introduction") == 0, "title Introduction")
check(LessonNarration.number(fromTitle: "Daily Minute") == nil, "title Daily Minute is not a lesson")

check(LessonNarration.number(fromGUID: "acim-lesson-047") == 47, "guid 047")
check(LessonNarration.number(fromGUID: "acim-lesson-049") == 49, "guid 049")
check(LessonNarration.number(fromGUID: "acim-lesson-000") == 0, "guid 000")
check(LessonNarration.number(fromGUID: "https://archive.org/download/x") == nil, "enclosure URL is not a guid")

check(LessonNarration.number(fromPlayerID: "lesson:47") == 47, "id lesson:47")
check(LessonNarration.number(fromPlayerID: "intro:0") == 0, "id intro:0")
check(LessonNarration.number(fromPlayerID: "archive-lesson:49") == 49, "id archive-lesson:49")
check(LessonNarration.number(fromPlayerID: "minute:abc") == nil, "id minute is not a lesson")

let podcast47 = "https://archive.org/download/acim-daily-lessons/lesson-047.mp3"
let podcast49 = "https://archive.org/download/acim-daily-lessons/lesson-049.mp3"
let daily88 = "https://archive.org/download/acim-daily-lessons/lesson-088.mp3"

check(
    LessonNarration.url(daily: daily88, archived: nil, podcast: podcast47) == daily88,
    "today's JSON wins when it has a file"
)
check(
    LessonNarration.url(daily: nil, archived: nil, podcast: podcast47) == podcast47,
    "podcast fills in when DailyLesson has no row — that is lessons 47 and 49"
)
check(
    LessonNarration.url(daily: "", archived: nil, podcast: podcast47) == podcast47,
    "empty DailyLesson URL is not a URL"
)
check(
    LessonNarration.url(daily: nil, archived: nil, podcast: nil) == nil,
    "unpublished stays silent rather than guessing a 404"
)

let episodes: [(id: String, title: String, audioURL: String)] = [
    (id: "acim-lesson-088", title: "Lesson 88: Today we will review these ideas:", audioURL: daily88),
    (id: "acim-lesson-047", title: "Lesson 47: “God is the Strength in which I trust.”", audioURL: podcast47),
    (id: "acim-lesson-049", title: "Lesson 49: “God’s Voice speaks to me all through the day.”", audioURL: podcast49),
    (id: "acim-lesson-000", title: "Introduction", audioURL: "https://archive.org/download/acim-daily-lessons/lesson-000.mp3"),
]
check(LessonNarration.podcastURL(forLesson: 47, episodes: episodes) == podcast47, "feed finds 47")
check(LessonNarration.podcastURL(forLesson: 49, episodes: episodes) == podcast49, "feed finds 49")
check(LessonNarration.podcastURL(forLesson: 0, episodes: episodes)?.hasSuffix("lesson-000.mp3") == true, "feed finds Introduction")
check(LessonNarration.podcastURL(forLesson: 200, episodes: episodes) == nil, "a lesson the feed has not named stays silent")

if failures.isEmpty {
    print("PASS — \(episodes.count) episodes, lesson 47 and 49 resolve")
} else {
    fputs(failures.map { "FAIL: \($0)" }.joined(separator: "\n") + "\n", stderr)
    exit(1)
}
SWIFT

SRC="$REPO/ACIMDailyMinute/Utilities/LessonNarration.swift"
if [ ! -f "$SRC" ]; then
    echo "FAIL: LessonNarration.swift is missing — Read cannot attach a podcast MP3 to a workbook lesson"
    exit 1
fi

swiftc -O "$SRC" "$WORK/main.swift" -o "$WORK/verify" 2>&1 | grep -v "^$" || true
"$WORK/verify"

CONTENT="$REPO/ACIMDailyMinute/App/ContentView.swift"
if ! grep -F 'environment(\.openPlayer' "$CONTENT" >/dev/null; then
    echo "FAIL: ContentView does not install openPlayer — TextChapterView Select still assertionFailure's"
    exit 1
fi
if ! grep -F 'fullScreenCover(item: $playerItem' "$CONTENT" >/dev/null; then
    echo "FAIL: ContentView does not present TVPlayerView — the environment has nowhere to send a section"
    exit 1
fi
if ! grep -q 'openPlayer(\.textSection' "$REPO/ACIMDailyMinute/Views/Text/TextChapterView.swift"; then
    echo "FAIL: TextChapterView no longer asks openPlayer for a section"
    exit 1
fi
echo "PASS — ContentView owns the television player"
