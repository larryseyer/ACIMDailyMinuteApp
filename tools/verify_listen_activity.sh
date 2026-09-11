#!/bin/bash
# Proves Listen is the Course in voice, with activity as a ribbon.
#
# What this guards is the old activity tab: now playing / part-finished /
# downloaded / finished as the organising idea, unplayed audio invisible,
# Text and Manual homeless. The tab is the four shelves. Resume is chrome.
#
#   ./tools/verify_listen_activity.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
VIEW="$REPO/ACIMDailyMinute/Views/Listen/ListenView.swift"
RIBBON="$REPO/ACIMDailyMinute/Views/Listen/ListenResumeRibbon.swift"
ROW="$REPO/ACIMDailyMinute/Views/Listen/ListenPlayableRow.swift"
PROGRESS="$REPO/ACIMDailyMinute/Utilities/PlaybackProgress.swift"
SHELF="$REPO/ACIMDailyMinute/Utilities/CourseShelf.swift"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$SHELF" ]] || fail "CourseShelf.swift missing"
[[ -f "$RIBBON" ]] || fail "ListenResumeRibbon.swift missing"
[[ -f "$ROW" ]] || fail "ListenPlayableRow.swift missing"

grep -q 'ForEach(CourseShelf.allCases)' "$VIEW" \
    || fail "Listen picker is not CourseShelf.allCases"
grep -q 'shelf: CourseShelf = .lesson' "$VIEW" \
    || fail "default Listen shelf is not Lesson"
grep -q 'ListenResumeRibbon' "$VIEW" || fail "ListenView does not draw the resume ribbon"
grep -q 'ListenPlayableRow' "$VIEW" || fail "ListenView does not draw ListenPlayableRow"

if grep -q 'Section("Part finished")' "$VIEW"; then
    fail "ListenView still organises the tab as Part finished"
fi
if grep -q 'Section("Downloaded")' "$VIEW"; then
    fail "ListenView still organises the tab as Downloaded"
fi
if grep -q 'Section("Finished")' "$VIEW"; then
    fail "ListenView still organises the tab as Finished"
fi
if grep -q 'Nothing to resume' "$VIEW"; then
    fail "ListenView still has the activity empty state"
fi
if grep -q 'Picker("Feed"' "$VIEW"; then
    fail "ListenView still has the Minute/Lessons feed picker"
fi
if grep -q 'Daily Minute Playlist' "$VIEW"; then
    fail "ListenView still embeds the YouTube catalogue"
fi

grep -q 'ListenActivity.classify' "$VIEW" \
    || fail "ListenView does not classify through ListenActivity"
grep -q 'enum ListenActivity' "$PROGRESS" \
    || fail "ListenActivity is not in PlaybackProgress.swift"

grep -q 'ListenButton(' "$ROW" || fail "ListenPlayableRow does not use ListenButton"
grep -q 'playOrToggle' "$VIEW" || fail "ListenView never calls playOrToggle"
grep -q 'episodeID:' "$VIEW" || fail "ListenView plays without an episode identity — progress cannot resume"

echo "Listen is shelves plus a resume ribbon"
echo "OK"
