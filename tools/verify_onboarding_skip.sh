#!/bin/bash
# Proves the introduction's Skip button cannot sit on the companion-note title.
#
# What this guards is a Mac sheet wide enough that "A Note About Using ACIM
# Daily Minute" is one line, at the same y as the overlaid Skip. Without a
# reserved trailing edge the last word draws under the button. Settings >
# About uses the same body without Skip, so the reserve has to live on the
# introduction's note stage, not inside CompanionNoteBody.
#
#   ./tools/verify_onboarding_skip.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$REPO/ACIMDailyMinute/Views/Onboarding/OnboardingView.swift"

failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

if ! grep -q 'skipOverlayReserve' "$FILE"; then
    fail "OnboardingView has no skipOverlayReserve — the Mac title has nothing keeping Skip off 'Minute'"
elif ! grep -A 40 'private var noteStage' "$FILE" | grep -q 'skipOverlayReserve'; then
    fail "skipOverlayReserve is not applied on noteStage"
fi
if ! grep -q 'A Note About Using ACIM Daily Minute' "$REPO/ACIMDailyMinute/Views/Settings/CompanionNoteView.swift"; then
    fail "the title this exists to protect is gone from CompanionNoteBody"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL — $failures check(s) failed"
    exit 1
fi
echo "PASS — the introduction's note stage keeps Skip off the title"
