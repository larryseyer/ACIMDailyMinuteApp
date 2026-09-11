#!/bin/bash
# Proves Video shows the Course, including rows with no YouTube.
#
# What this guards is the old Archive tab: a day without an id was
# "No video for this day", and Text / Manual had no home. Absence of a
# recording is not an empty state. Apple TV always composes — it has no
# WebKit. iPhone / iPad / Mac play YouTube when ids exist.
#
#   ./tools/verify_video_compose.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$REPO/ACIMDailyMinute/Utilities/VideoLibrary.swift"
PBX="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$LIB" ]] || fail "VideoLibrary.swift missing"

count=$(grep -c "VideoLibrary.swift" "$PBX" || true)
[[ "$count" -ge 6 ]] || fail "VideoLibrary.swift has $count pbxproj lines; need the four build entries plus group child"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

func check(_ cond: Bool, _ msg: String) {
    if !cond { fputs("FAIL: \(msg)\n", stderr); exit(1) }
}

check(VideoLibrary.play(videoIDs: [], youtubeAvailable: true) == .compose,
      "empty ids compose even when YouTube can play")
check(VideoLibrary.play(videoIDs: ["SlAhY7QszJo"], youtubeAvailable: false) == .compose,
      "Apple TV always composes")
check(VideoLibrary.play(videoIDs: ["SlAhY7QszJo"], youtubeAvailable: true) == .youtube(["SlAhY7QszJo"]),
      "iPhone plays YouTube when an id exists")
check(VideoLibrary.play(videoIDs: ["  "], youtubeAvailable: true) == .compose,
      "whitespace is not an id")

let lessons = VideoLibrary.lessonRows(
    titles: [1: "Nothing real can be threatened"],
    videoIDsByLesson: [:],
    introductions: [(number: 0, title: "Introduction", insertBefore: 1)]
)
check(lessons.contains { $0.id == "intro:0" }, "introduction row is visible without YouTube")
check(lessons.contains { $0.id == "lesson:1" }, "lesson 1 is visible without YouTube")
check(lessons.contains { $0.id == "lesson:365" }, "lesson 365 is visible without YouTube")
check(lessons.count >= 366, "spine includes 365 lessons plus introductions")
check(lessons.allSatisfy { $0.videoIDs.isEmpty }, "a silent catalogue has no ids")

let withVideo = VideoLibrary.lessonRows(
    titles: [47: "Miracle receiving"],
    videoIDsByLesson: [47: ["Bk398csx8As"]],
    introductions: []
)
let fortySeven = withVideo.first { $0.id == "lesson:47" }!
check(fortySeven.videoIDs == ["Bk398csx8As"], "lesson 47 keeps its id")
check(withVideo.contains { $0.id == "lesson:48" && $0.videoIDs.isEmpty },
      "lesson 48 without YouTube still appears")

let text = VideoLibrary.textSectionRows(
    chapter: 1,
    sections: [(number: 1, title: "The Meaning of Miracles")],
    videoIDsBySection: [:]
)
check(text.count == 1, "a Text section without YouTube is still a row")
check(text[0].videoIDs.isEmpty, "Text without an id composes")
check(text[0].id == "text:1.1", "Text row id is chapter.section")
check(VideoLibrary.play(videoIDs: text[0].videoIDs, youtubeAvailable: true) == .compose,
      "Video opens a Text section with no YouTube by composing")

let manual = VideoLibrary.manualSectionRows(
    sections: [(number: 0, title: "Introduction"), (number: 1, title: "Who are God's teachers?")],
    videoIDsByNumber: [:]
)
check(manual.count == 2, "Manual sections without YouTube still appear")
check(manual.allSatisfy { $0.videoIDs.isEmpty }, "Manual without ids composes")

print("OK")
SWIFT

swiftc -O "$LIB" "$WORK/main.swift" -o "$WORK/verify"
"$WORK/verify"

echo "Video composes when YouTube is absent"
echo "OK"
