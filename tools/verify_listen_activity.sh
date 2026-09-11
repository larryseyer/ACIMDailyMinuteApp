#!/bin/bash
# Proves Listen is not an activity tab: no Part finished / Downloaded /
# Finished sections, and Course still has four books.
#
#   ./tools/verify_listen_activity.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
COURSE="$REPO/ACIMDailyMinute/Views/Course/CourseView.swift"
SHELF="$REPO/ACIMDailyMinute/Utilities/CourseShelf.swift"
PROGRESS="$REPO/ACIMDailyMinute/Utilities/PlaybackProgress.swift"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$SHELF" ]] || fail "CourseShelf.swift missing"
[[ -f "$COURSE" ]] || fail "CourseView.swift missing"

grep -q 'CourseShelf.allCases' "$COURSE" \
    || fail "Course contents is not CourseShelf.allCases"

if grep -q 'Section("Part finished")' "$COURSE"; then
    fail "Course still organises as Part finished"
fi
if grep -q 'Section("Downloaded")' "$COURSE"; then
    fail "Course still organises as Downloaded"
fi
if grep -q 'Section("Finished")' "$COURSE"; then
    fail "Course still organises as Finished"
fi
if grep -q 'Nothing to resume' "$COURSE"; then
    fail "Course still has the activity empty state"
fi
if grep -q 'Daily Minute Playlist' "$COURSE"; then
    fail "Course still embeds the YouTube catalogue"
fi

grep -q 'enum ListenActivity' "$PROGRESS" \
    || fail "ListenActivity is not in PlaybackProgress.swift"

echo "Course is four books, not an activity tab"
echo "OK"
