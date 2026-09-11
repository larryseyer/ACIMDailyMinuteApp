#!/bin/bash
# Proves the Read tab's Minute shelf opens a reading, not a YouTube card.
#
# What this guards is a calendar of past minutes that still dumps the
# reader into the Video tab's day. Read is the words. A date that opens
# LiteYouTubeCard, or a lesson from this spine that auto-presents video,
# is the old Archive wearing a Read label. Lesson numbers are Int, so
# the date destination cannot be String.
#
#   ./tools/verify_read_minute_shelf.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LESSONS="$REPO/ACIMDailyMinute/Views/Lessons/LessonsView.swift"
MINUTE="$REPO/ACIMDailyMinute/Views/Lessons/MinuteReadingView.swift"
SHELF="$REPO/ACIMDailyMinute/Utilities/CourseShelf.swift"
PBX="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$SHELF" ]] || fail "CourseShelf.swift missing"
[[ -f "$MINUTE" ]] || fail "MinuteReadingView.swift missing"
[[ -f "$LESSONS" ]] || fail "LessonsView.swift missing"

# Four pbxproj lines each: PBXBuildFile ×2 (app + tvOS), PBXFileReference,
# group child, both Sources phases. Pattern: SegmentReadingView.swift.
for name in CourseShelf.swift MinuteReadingView.swift; do
    count=$(grep -c "$name" "$PBX" || true)
    [[ "$count" -ge 6 ]] || fail "$name has $count pbxproj lines; need the four build entries plus group child"
done

grep -q 'navigationDestination(for: MinuteDateRef.self)' "$LESSONS" \
    || fail "Read has no MinuteDateRef destination"

if grep -q 'navigationDestination(for: String.self)' "$LESSONS"; then
    fail "Read must not route dates as String — that is the Video day's type"
fi

grep -q 'ArchiveCalendarView' "$LESSONS" \
    || fail "Minute shelf does not reuse ArchiveCalendarView"

# Default shelf stays Lesson so the Workbook landing does not jump to a calendar.
grep -q 'shelf: CourseShelf = .lesson' "$LESSONS" \
    || fail "default Read shelf is not Lesson"

# Minute is first in the picker because CaseIterable order is the picker order.
grep -q 'ForEach(CourseShelf.allCases)' "$LESSONS" \
    || fail "Read picker is not CourseShelf.allCases"

# Daily Minute holds no continue-reading ribbon.
ribbon=$(grep -B6 -A2 'ContinueReadingRow' "$LESSONS" || true)
echo "$ribbon" | grep -Eq 'ribbonBook|shelf != \.minute' \
    || fail "ContinueReadingRow is not gated off the Minute shelf"

# From the Read lesson spine, video does not auto-present.
int_dest=$(awk '
    /navigationDestination\(for: Int\.self\)/ { grab=1 }
    grab { print }
    grab && /LessonDetailView/ { exit }
' "$LESSONS")
echo "$int_dest" | grep -q 'presentsVideo: false' \
    || fail "Read Int lesson destination still auto-presents video"

# The day's minute is a reading. Never the Video tab's YouTube card.
# Comments are stripped first: naming the forbidden type in prose is the guard.
STRIPPED_MINUTE="$(sed 's://.*::' "$MINUTE")"
echo "$STRIPPED_MINUTE" | grep -q 'DailyMinuteCard' \
    || fail "MinuteDateRef destination never opens DailyMinuteCard"
echo "$STRIPPED_MINUTE" | grep -q 'ArchivedReadingCard' \
    || fail "MinuteDateRef destination never opens ArchivedReadingCard"
if echo "$STRIPPED_MINUTE" | grep -q 'LiteYouTubeCard'; then
    fail "Read Minute destination opens LiteYouTubeCard"
fi
grep -q 'struct MinuteDateRef: Hashable' "$MINUTE" \
    || fail "MinuteDateRef is missing or not Hashable"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation
func check(_ cond: Bool, _ msg: String) { if !cond { fputs("FAIL: \(msg)\n", stderr); exit(1) } }
check(CourseShelf.allCases.map(\.rawValue) == ["Minute", "Lesson", "Text", "Manual"],
      "picker order is Minute, Lesson, Text, Manual")
check(CourseShelf.minute.rawValue == "Minute", "minute label")
check(CourseShelf.lesson.rawValue == "Lesson", "lesson label is Lesson, not Workbook")
print("course shelf order")
print("OK")
SWIFT
swiftc -O "$SHELF" "$WORK/main.swift" -o "$WORK/verify"
"$WORK/verify"

echo "Read Minute shelf opens a reading"
echo "OK"
