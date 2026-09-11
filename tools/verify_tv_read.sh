#!/bin/bash
# Proves tvOS Course opens the reading, not the composed player.
#
# Today stays player-first. Paging on tvOS now works, so a Course row
# that still calls openPlayer is the old television — Select starts a
# crawl instead of a pageable reading.
#
#   ./tools/verify_tv_read.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
COURSE="$REPO/ACIMDailyMinute/Views/Course/CourseView.swift"
WORKBOOK="$REPO/ACIMDailyMinute/Views/Course/CourseWorkbookSpine.swift"
ROW="$REPO/ACIMDailyMinute/Views/Lessons/LessonRow.swift"
CHAPTER="$REPO/ACIMDailyMinute/Views/Text/TextChapterView.swift"
SECTION="$REPO/ACIMDailyMinute/Views/Text/TextSectionView.swift"
NAV="$REPO/ACIMDailyMinute/Views/ReadingNavigation.swift"
TODAY="$REPO/ACIMDailyMinute/Views/Today/TodayView.swift"
TEXT="$REPO/ACIMDailyMinute/Views/SelectableReadingText.swift"
CORPUS="$REPO/ACIMDailyMinute/Resources/ACIMTextSections.json"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$COURSE" ]] || fail "CourseView.swift missing"
[[ -f "$WORKBOOK" ]] || fail "CourseWorkbookSpine.swift missing"
[[ -f "$ROW" ]] || fail "LessonRow.swift missing"
[[ -f "$CHAPTER" ]] || fail "TextChapterView.swift missing"
[[ -f "$SECTION" ]] || fail "TextSectionView.swift missing"
[[ -f "$NAV" ]] || fail "ReadingNavigation.swift missing"

for file in "$COURSE" "$WORKBOOK" "$ROW" "$CHAPTER"; do
    stripped="$(sed 's://.*::' "$file")"
    echo "$stripped" | grep -q 'openPlayer' \
        && fail "$(basename "$file") still calls openPlayer — Course opens the reading"
done

grep -q 'NavigationLink(value: lessonNumber)' "$ROW" \
    || fail "LessonRow is not a NavigationLink to the lesson"
grep -q 'NavigationLink' "$CHAPTER" \
    || fail "TextChapterView no longer links to a section"
grep -q 'TextSectionRef' "$CHAPTER" \
    || fail "TextChapterView does not push TextSectionRef"
grep -q 'NavigationLink(value: IntroductionRef' "$WORKBOOK" \
    || fail "Workbook introductions do not open as readings"

grep -q 'pendingJump' "$WORKBOOK" \
    || fail "CourseWorkbookSpine has nowhere to hold the jumped lesson until the sheet is gone"
grep -q 'onDismiss: openPendingJump' "$WORKBOOK" \
    || fail "CourseWorkbookSpine does not wait for the jump sheet to dismiss before pushing"
grep -A6 'private func openPendingJump' "$WORKBOOK" | grep -q 'path.append' \
    || fail "Jump to Lesson no longer pushes the reading after dismiss"
if grep -A6 'private func openPendingJump' "$WORKBOOK" | grep -q 'openPlayer'; then
    fail "Jump to Lesson still opens the player after dismiss"
fi

grep -q 'navigationDestination(for: TextSectionRef.self)' "$NAV" \
    || fail "readingDestinations no longer declares TextSectionRef"
if grep -q 'Read opens the player' "$NAV"; then
    fail "readingDestinations still refuses a pushed reading on the television"
fi
grep -q 'readingDestinations(path: $path)' "$COURSE" \
    || fail "Course does not install readingDestinations"

grep -q 'openPlayer(.minute' "$TODAY" \
    || fail "Today Minute card no longer opens the player"
grep -q 'openPlayer(.lesson' "$TODAY" \
    || fail "Today Lesson card no longer opens the player"

python3 - "$CORPUS" <<'PY' || fail "Principles of Miracles is missing or is not chapter 1 section 2"
import json, sys
path = sys.argv[1]
rows = json.load(open(path))
hit = next((r for r in rows if r.get("sectionTitle") == "Principles of Miracles"), None)
if hit is None:
    sys.exit(1)
if hit.get("chapterNumber") != 1 or hit.get("sectionNumber") != 2:
    sys.exit(1)
body = hit.get("body") or ""
if "53." not in body:
    sys.exit(1)
PY

grep -q 'recordsPosition: true' "$SECTION" \
    || fail "TextSectionView does not report a ribbon — the television cannot page it"
grep -q 'UIScreen.main.bounds.height \* 0.65' "$TEXT" \
    || fail "reading text no longer caps to a television viewport"
grep -q 'onKeyPress(.downArrow)' "$TEXT" \
    || fail "reading text no longer pages on the down arrow"
grep -q 'onKeyPress(.upArrow)' "$TEXT" \
    || fail "reading text no longer pages on the up arrow"

echo "tvOS Course opens the reading"
echo "OK"
