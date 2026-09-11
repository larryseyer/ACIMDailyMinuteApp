#!/bin/bash
# Proves Listen shows the Course, including rows with no MP3.
#
# What this guards is the old activity tab: unplayed, undownloaded audio
# never appeared, and Text / Manual had no listening home. Play is an
# overlay. A missing enclosure omits the control; it does not hide the row
# and it does not invent TTS.
#
#   ./tools/verify_listen_unplayed.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$REPO/ACIMDailyMinute/Utilities/ListenLibrary.swift"
NARRATION="$REPO/ACIMDailyMinute/Utilities/LessonNarration.swift"
VIEW="$REPO/ACIMDailyMinute/Views/Listen/ListenView.swift"
PBX="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$LIB" ]] || fail "ListenLibrary.swift missing"

grep -q 'ForEach(CourseShelf.allCases)' "$VIEW" \
    || fail "Listen picker is not CourseShelf.allCases"
grep -q 'shelf: CourseShelf = .lesson' "$VIEW" \
    || fail "default Listen shelf is not Lesson"
STRIPPED="$(sed 's://.*::' "$VIEW")"
echo "$STRIPPED" | grep -q 'LiteYouTubeCard' && fail "ListenView opens LiteYouTubeCard"
echo "$STRIPPED" | grep -q 'FullScreenVideoCover' && fail "ListenView opens FullScreenVideoCover"
echo "$STRIPPED" | grep -q 'TVPlayerItem' && fail "ListenView opens TVPlayerView"
echo "$STRIPPED" | grep -q 'Nothing to resume' && fail "ListenView still has the activity empty state"
grep -q 'ArchiveCalendarView' "$VIEW" \
    || fail "Minute shelf does not reuse ArchiveCalendarView"

CHAPTER="$REPO/ACIMDailyMinute/Views/Listen/ListenTextChapterView.swift"
[[ -f "$CHAPTER" ]] || fail "ListenTextChapterView.swift missing"
chapter_count=$(grep -c "ListenTextChapterView.swift" "$PBX" || true)
[[ "$chapter_count" -ge 6 ]] || fail "ListenTextChapterView.swift has $chapter_count pbxproj lines"

grep -q 'navigationDestination(for: ListenTextChapterRef.self)' "$VIEW" \
    || fail "Listen has no ListenTextChapterRef destination"
if grep -q 'navigationDestination(for: TextChapterRef.self)' "$VIEW"; then
    fail "Listen must not push Read's TextChapterView"
fi
if grep -q 'dismissForTextReading' "$VIEW" "$CHAPTER"; then
    fail "Listen Text must not dismiss the session"
fi

count=$(grep -c "ListenLibrary.swift" "$PBX" || true)
[[ "$count" -ge 6 ]] || fail "ListenLibrary.swift has $count pbxproj lines; need the four build entries plus group child"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

func check(_ cond: Bool, _ msg: String) {
    if !cond { fputs("FAIL: \(msg)\n", stderr); exit(1) }
}

check(!ListenLibrary.showsPlay(audioURL: ""), "empty audio must omit play")
check(!ListenLibrary.showsPlay(audioURL: "   "), "whitespace audio must omit play")
check(ListenLibrary.showsPlay(audioURL: "https://example/a.mp3"), "a URL must show play")

check(
    ListenLibrary.minuteAudio(daily: "/a.mp3", archived: "/b.mp3", podcast: "/c.mp3") == "/a.mp3",
    "daily wins"
)
check(
    ListenLibrary.minuteAudio(daily: "", archived: "/b.mp3", podcast: "/c.mp3") == "/b.mp3",
    "empty daily is not a URL"
)
check(
    ListenLibrary.minuteAudio(daily: nil, archived: nil, podcast: nil) == "",
    "no enclosure is empty, not invented"
)

let silentLessons = ListenLibrary.lessonRows(
    titles: [1: "Nothing real can be threatened"],
    audioByLesson: [:],
    episodeIDByLesson: [:],
    introductions: [(number: 0, title: "Introduction", insertBefore: 1)]
)
check(silentLessons.contains { $0.id == "intro:0" }, "introduction row is visible without audio")
check(silentLessons.contains { $0.id == "lesson:1" }, "lesson 1 is visible without audio")
check(silentLessons.contains { $0.id == "lesson:365" }, "lesson 365 is visible without audio")
check(silentLessons.count >= 366, "spine includes 365 lessons plus introductions")
check(silentLessons.allSatisfy { !ListenLibrary.showsPlay(audioURL: $0.audioURL) },
      "a silent catalogue must omit play on every row")

let withAudio = ListenLibrary.lessonRows(
    titles: [47: "Miracle receiving"],
    audioByLesson: [47: "https://example/lesson-047.mp3"],
    episodeIDByLesson: [47: "acim-lesson-047"],
    introductions: []
)
let fortySeven = withAudio.first { $0.id == "lesson:47" }!
check(ListenLibrary.showsPlay(audioURL: fortySeven.audioURL), "lesson 47 with an enclosure shows play")
check(fortySeven.episodeID == "acim-lesson-047", "episode id is the feed GUID")
check(withAudio.contains { $0.id == "lesson:48" && $0.audioURL.isEmpty },
      "lesson 48 without an enclosure still appears")

let text = ListenLibrary.textSectionRows(
    chapter: 1,
    sections: [(number: 1, title: "The Meaning of Miracles")],
    audioBySection: [:],
    episodeIDBySection: [:]
)
check(text.count == 1, "a Text section without audio is still a row")
check(!ListenLibrary.showsPlay(audioURL: text[0].audioURL), "Text without an enclosure omits play")
check(text[0].id == "text:1.1", "Text row id is chapter.section")

let manual = ListenLibrary.manualSectionRows(
    sections: [(number: 0, title: "Introduction"), (number: 1, title: "Who are God's teachers?")],
    audioByNumber: [:],
    episodeIDByNumber: [:]
)
check(manual.count == 2, "Manual sections without audio still appear")
check(manual.allSatisfy { !ListenLibrary.showsPlay(audioURL: $0.audioURL) },
      "Manual without enclosures omits play")

check(
    ListenLibrary.unrecordedCaption(availableOnFormatted: "2026-09-14") == "Available 2026-09-14",
    "a known day is named"
)
check(
    ListenLibrary.unrecordedCaption(availableOnFormatted: nil) == "Audio hasn't been published yet.",
    "Text and Manual without a schedule still say so"
)
check(
    ListenLibrary.unrecordedCaption(availableOnFormatted: "  ") == "Audio hasn't been published yet.",
    "whitespace is not a day"
)

let idle = ListenLibrary.resume(
    hasActiveAudio: false,
    nowPlayingTitle: "",
    nowPlayingURL: "",
    nowPlayingEpisodeID: "",
    inProgress: []
)
check(idle == nil, "no ribbon when nothing is playing and nothing is part-finished")

let playing = ListenLibrary.resume(
    hasActiveAudio: true,
    nowPlayingTitle: "Daily Minute",
    nowPlayingURL: "https://example/a.mp3",
    nowPlayingEpisodeID: "ep-a",
    inProgress: [(
        title: "Lesson 47",
        audioURL: "https://example/lesson-047.mp3",
        episodeID: "acim-lesson-047",
        updatedAt: Date(timeIntervalSince1970: 100)
    )]
)
check(playing?.kind == .nowPlaying, "now playing wins over continue")
check(playing?.episodeID == "ep-a", "ribbon identity is the session")

let cont = ListenLibrary.resume(
    hasActiveAudio: false,
    nowPlayingTitle: "",
    nowPlayingURL: "",
    nowPlayingEpisodeID: "",
    inProgress: [(
        title: "Lesson 47",
        audioURL: "https://example/lesson-047.mp3",
        episodeID: "acim-lesson-047",
        updatedAt: Date(timeIntervalSince1970: 50)
    ), (
        title: "Daily Minute",
        audioURL: "https://example/b.mp3",
        episodeID: "ep-b",
        updatedAt: Date(timeIntervalSince1970: 90)
    )]
)
check(cont?.kind == .continue, "part-finished becomes Continue")
check(cont?.episodeID == "ep-b", "Continue is the most recently updated in-progress row")

print("listen library")
print("OK")
SWIFT
swiftc -O "$LIB" "$NARRATION" "$WORK/main.swift" -o "$WORK/verify"
"$WORK/verify"

echo "Listen shows unplayed"
echo "OK"
