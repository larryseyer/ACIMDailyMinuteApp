#!/bin/bash
# Proves tvOS Read opens the reading, not the composed player.
#
# What this guards is the 2026-09-10 tab IA: Read is the words, Video is
# the picture, Today stays player-first. Paging on tvOS now works, so a
# Read row that still calls openPlayer is the old television — Select
# starts a crawl instead of a pageable reading. The acceptance reading is
# Text chapter 1, Principles of Miracles (principle 53).
#
# Today and Video still open the player; that is verify_tv_player.sh.
#
#   ./tools/verify_tv_read.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LESSONS="$REPO/ACIMDailyMinute/Views/Lessons/LessonsView.swift"
ROW="$REPO/ACIMDailyMinute/Views/Lessons/LessonRow.swift"
CHAPTER="$REPO/ACIMDailyMinute/Views/Text/TextChapterView.swift"
SECTION="$REPO/ACIMDailyMinute/Views/Text/TextSectionView.swift"
RIBBON="$REPO/ACIMDailyMinute/Views/ContinueReadingRow.swift"
NAV="$REPO/ACIMDailyMinute/Views/ReadingNavigation.swift"
TODAY="$REPO/ACIMDailyMinute/Views/Today/TodayView.swift"
VIDEO="$REPO/ACIMDailyMinute/Views/Archive/ArchiveView.swift"
TEXT="$REPO/ACIMDailyMinute/Views/SelectableReadingText.swift"
CORPUS="$REPO/ACIMDailyMinute/Resources/ACIMTextSections.json"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$LESSONS" ]] || fail "LessonsView.swift missing"
[[ -f "$ROW" ]] || fail "LessonRow.swift missing"
[[ -f "$CHAPTER" ]] || fail "TextChapterView.swift missing"
[[ -f "$SECTION" ]] || fail "TextSectionView.swift missing"
[[ -f "$RIBBON" ]] || fail "ContinueReadingRow.swift missing"
[[ -f "$NAV" ]] || fail "ReadingNavigation.swift missing"

# Read itself must not open the player. Comments naming the old crash are
# the guard, so strip them first.
for file in "$LESSONS" "$ROW" "$CHAPTER" "$RIBBON"; do
    stripped="$(sed 's://.*::' "$file")"
    echo "$stripped" | grep -q 'openPlayer' \
        && fail "$(basename "$file") still calls openPlayer — Read opens the reading"
done

grep -q 'NavigationLink(value: lessonNumber)' "$ROW" \
    || fail "LessonRow is not a NavigationLink to the lesson"
grep -q 'NavigationLink' "$CHAPTER" \
    || fail "TextChapterView no longer links to a section"
grep -q 'TextSectionRef' "$CHAPTER" \
    || fail "TextChapterView does not push TextSectionRef"
grep -q 'NavigationLink(value: IntroductionRef' "$LESSONS" \
    || fail "Workbook introductions do not open as readings"
grep -q 'NavigationLink(value: TextSectionRef' "$RIBBON" \
    || fail "Continue reading does not open a Text section as a reading"
grep -q 'NavigationLink(value: LessonRef' "$RIBBON" \
    || fail "Continue reading does not open a lesson as a reading"
grep -q 'NavigationLink(value: ManualSectionRef' "$RIBBON" \
    || fail "Continue reading does not open a Manual section as a reading"

# Jump waits for the sheet, then pushes the lesson — never the player.
grep -q 'pendingJump' "$LESSONS" \
    || fail "LessonsView has nowhere to hold the jumped lesson until the sheet is gone"
grep -q 'onDismiss: openPendingJump' "$LESSONS" \
    || fail "LessonsView does not wait for the jump sheet to dismiss before pushing"
grep -A6 'private func openPendingJump' "$LESSONS" | grep -q 'path.append' \
    || fail "Jump to Lesson no longer pushes the reading after dismiss"
if grep -A6 'private func openPendingJump' "$LESSONS" | grep -q 'openPlayer'; then
    fail "Jump to Lesson still opens the player after dismiss"
fi

# Deep link to a lesson lands on the reading, not the player.
if grep -A8 'deepLinkLesson' "$LESSONS" | grep -q 'openPlayer'; then
    fail "a lesson deep link still opens the player"
fi
grep -A8 'deepLinkLesson' "$LESSONS" | grep -q 'path.append' \
    || fail "a lesson deep link no longer pushes the reading"

# Previous / Next and a Text section Select need TextSectionRef on the stack.
grep -q 'navigationDestination(for: TextSectionRef.self)' "$NAV" \
    || fail "readingDestinations no longer declares TextSectionRef"
if grep -q 'Read opens the player' "$NAV"; then
    fail "readingDestinations still refuses a pushed reading on the television"
fi
grep -q 'readingDestinations(path: $path)' "$LESSONS" \
    || fail "Read does not install readingDestinations"

# Today stays player-first. Video stays the picture.
grep -q 'openPlayer(.minute' "$TODAY" \
    || fail "Today Minute card no longer opens the player"
grep -q 'openPlayer(.lesson' "$TODAY" \
    || fail "Today Lesson card no longer opens the player"
grep -q 'openPlayer' "$VIDEO" \
    || fail "Video no longer opens the composed player"

# Principles of Miracles is the paging acceptance reading: chapter 1,
# section 2, fifty-three principles. The screen must report a ribbon so
# the text view sizes to a viewport and pages on the arrows.
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

echo "tvOS Read opens the reading"
echo "OK"
