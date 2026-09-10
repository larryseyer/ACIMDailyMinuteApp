#!/bin/bash
# Proves a Workbook lesson can be marked done without being listened to,
# and that a number that is not a lesson cannot be marked.
#
# What this guards is the Workbook as a practice, not a playlist. Listen
# already records that an episode was opened. Completing a lesson is a
# different fact: the reader did the day's work. Collapsing the two would
# tick off a lesson because a podcast row was tapped, and would hide the
# lessons that were done in silence.
#
# ⛔ The compile line names ONE source file. The rule must stay free of
# SwiftUI, SwiftData and the Listen history's own key, or "done" and
# "listened" can only be told apart by launching the app.
#
#   ./tools/verify_workbook_completion.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 20 { print("  \(message())") }
    }
}

let when = Date(timeIntervalSince1970: 1_788_000_000)

var entries: [Int: Date] = [:]
check(!WorkbookCompletion.isDone(84, in: entries), "an empty book has no completed lesson")

entries = WorkbookCompletion.marking(84, at: when, in: entries)
check(WorkbookCompletion.isDone(84, in: entries), "lesson 84 can be marked done")
check(!WorkbookCompletion.isDone(85, in: entries), "marking 84 does not mark 85")
check(entries[84] == when, "the day it was marked is kept")

entries = WorkbookCompletion.marking(0, at: when, in: entries)
check(entries[0] == nil, "lesson 0 is an introduction, not a lesson that can be done")
entries = WorkbookCompletion.marking(500, at: when, in: entries)
check(entries[500] == nil, "lesson 500 is an introduction, not a lesson that can be done")
entries = WorkbookCompletion.marking(366, at: when, in: entries)
check(entries[366] == nil, "there is no lesson 366")
entries = WorkbookCompletion.marking(-1, at: when, in: entries)
check(entries[-1] == nil, "a negative number is not a lesson")

entries = WorkbookCompletion.clearing(84, in: entries)
check(!WorkbookCompletion.isDone(84, in: entries), "a done lesson can be unmarked")

entries = WorkbookCompletion.marking(1, at: when, in: entries)
entries = WorkbookCompletion.marking(365, at: when, in: entries)
check(WorkbookCompletion.isDone(1, in: entries) && WorkbookCompletion.isDone(365, in: entries),
      "the first and last lessons can be marked")

check(PlaybackHistory.defaultsKey != WorkbookCompletion.defaultsKey,
      "done and listened must not share a store")

if failures == 0 {
    print("\(checks) checks, done is not listened")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/PlaybackHistory.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"

if ! grep -q 'isCompleted' "$REPO/ACIMDailyMinute/Views/Lessons/LessonRow.swift"; then
    echo "LessonRow never shows that a lesson is done"
    exit 1
fi
if ! grep -q 'WorkbookCompletion' "$REPO/ACIMDailyMinute/Views/Lessons/LessonDetailView.swift"; then
    echo "LessonDetailView never lets a lesson be marked done"
    exit 1
fi
if ! grep -q 'completedLessons' "$REPO/ACIMDailyMinute/Services/BackupDocument.swift"; then
    echo "a backup does not carry completed lessons"
    exit 1
fi
