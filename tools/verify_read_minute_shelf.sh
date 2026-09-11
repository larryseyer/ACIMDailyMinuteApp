#!/bin/bash
# Proves the Course Minute spine opens a reading, not a YouTube card.
#
#   ./tools/verify_read_minute_shelf.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
COURSE="$REPO/ACIMDailyMinute/Views/Course/CourseView.swift"
MINUTE_SPINE="$REPO/ACIMDailyMinute/Views/Course/CourseMinuteSpine.swift"
WORKBOOK="$REPO/ACIMDailyMinute/Views/Course/CourseWorkbookSpine.swift"
MINUTE="$REPO/ACIMDailyMinute/Views/Lessons/MinuteReadingView.swift"
SHELF="$REPO/ACIMDailyMinute/Utilities/CourseShelf.swift"
PBX="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$SHELF" ]] || fail "CourseShelf.swift missing"
[[ -f "$MINUTE" ]] || fail "MinuteReadingView.swift missing"
[[ -f "$COURSE" ]] || fail "CourseView.swift missing"
[[ -f "$MINUTE_SPINE" ]] || fail "CourseMinuteSpine.swift missing"

for name in CourseShelf.swift MinuteReadingView.swift; do
    count=$(grep -c "$name" "$PBX" || true)
    [[ "$count" -ge 6 ]] || fail "$name has $count pbxproj lines; need the four build entries plus group child"
done

grep -q 'navigationDestination(for: MinuteDateRef.self)' "$COURSE" \
    || fail "Course has no MinuteDateRef destination"

if grep -q 'navigationDestination(for: String.self)' "$COURSE"; then
    fail "Course must not route dates as String — that is the Video day's type"
fi

grep -q 'ArchiveCalendarView' "$MINUTE_SPINE" \
    || fail "Minute spine does not reuse ArchiveCalendarView"

grep -q 'CourseShelf.allCases' "$COURSE" \
    || fail "Course contents is not CourseShelf.allCases"

int_dest=$(awk '
    /navigationDestination\(for: Int\.self\)/ { grab=1 }
    grab { print }
    grab && /LessonDetailView/ { exit }
' "$COURSE")
echo "$int_dest" | grep -q 'presentsVideo: false' \
    || fail "Course Int lesson destination still auto-presents video"

STRIPPED_MINUTE="$(sed 's://.*::' "$MINUTE")"
echo "$STRIPPED_MINUTE" | grep -q 'DailyMinuteCard' \
    || fail "MinuteDateRef destination never opens DailyMinuteCard"
echo "$STRIPPED_MINUTE" | grep -q 'ArchivedReadingCard' \
    || fail "MinuteDateRef destination never opens ArchivedReadingCard"
if echo "$STRIPPED_MINUTE" | grep -q 'LiteYouTubeCard'; then
    fail "Minute destination opens LiteYouTubeCard"
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
check(CourseShelf.lesson.bookName == "Workbook", "contents name is Workbook")
print("course shelf order")
print("OK")
SWIFT
swiftc -O "$SHELF" "$WORK/main.swift" -o "$WORK/verify"
"$WORK/verify"

echo "Course Minute spine opens a reading"
echo "OK"
