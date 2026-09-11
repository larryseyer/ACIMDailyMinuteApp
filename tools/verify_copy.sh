#!/bin/bash
# Proves Video copy is the Course in picture, not the old Archive calendar.
#
# What this guards is onboarding, the App Store listing, and the support page
# still pitching Video as “browse by date.” The tab is four shelves. The
# calendar is the Minute shelf, not the tab.
#
#   ./tools/verify_copy.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ONBOARDING="$REPO/ACIMDailyMinute/Views/Onboarding/OnboardingView.swift"
LISTING="$REPO/APP_STORE_LISTING.md"
SUPPORT="$REPO/store-support-page.md"

failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

[[ -f "$ONBOARDING" ]] || fail "OnboardingView.swift missing"
[[ -f "$LISTING" ]] || fail "APP_STORE_LISTING.md missing"
[[ -f "$SUPPORT" ]] || fail "store-support-page.md missing"

if grep -q 'Browse past readings by date' "$ONBOARDING"; then
    fail "onboarding still describes Video as browse-by-date"
fi
if grep -q '("play.rectangle", "Video"' "$ONBOARDING"; then
    fail "onboarding still names the Video tab"
fi
if ! grep -q 'The Course' "$ONBOARDING"; then
    fail "onboarding lost the Course page"
fi

if grep -q 'calendar of every past daily minute' "$LISTING"; then
    fail "App Store listing still describes Video as a calendar"
fi
if grep -q 'Browse every past daily minute' "$LISTING"; then
    fail "App Store caption still says browse every past daily minute"
fi
if grep -q 'Video calendar' "$LISTING"; then
    fail "App Store screenshot scenes still name a Video calendar"
fi
if ! grep -q 'watch minutes, lessons, the Text, and the Manual' "$LISTING"; then
    fail "App Store listing Video bullet is gone"
fi

if grep -q 'A day on the Video tab has no reading' "$SUPPORT"; then
    fail "support page still treats Video as a day that may have no reading"
fi
if ! grep -q 'A Video row has no YouTube recording' "$SUPPORT"; then
    fail "support page no longer says a row without YouTube still plays"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL — $failures check(s) failed"
    exit 1
fi
echo "PASS — Video copy is the Course in picture, not a date browser"
