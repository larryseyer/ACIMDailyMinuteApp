#!/bin/bash
# Proves iPhone chrome: calendar days without a recording are not
# selectable, YouTube is a landscape cover with Close, composed player
# can be left without audio.
#
#   ./tools/verify_iphone_player_chrome.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }

CAL="$REPO/ACIMDailyMinute/Views/Archive/ArchiveCalendarView.swift"
DETAIL="$REPO/ACIMDailyMinute/Views/Archive/ArchiveDateDetailView.swift"
PLAYER="$REPO/ACIMDailyMinute/Views/TVPlayerView.swift"
COVER="$REPO/ACIMDailyMinute/Views/Listen/FullScreenVideoCover.swift"
COURSE="$REPO/ACIMDailyMinute/Views/Course/CourseView.swift"

grep -q 'ArchiveCalendarState.isRecorded' "$CAL" \
    || fail "ArchiveCalendarView still lets every cell be selected"
grep -q 'availableDateStrings' "$CAL" || fail "calendar lost its recorded-day set"

if grep -q 'LiteYouTubeCard' "$COURSE" "$DETAIL"; then
    fail "Course or the day still embeds LiteYouTubeCard — that is the trap"
fi
grep -q 'FullScreenVideoCover' "$DETAIL" \
    || fail "Video day does not present FullScreenVideoCover for YouTube"
grep -q 'lockLandscape' "$COVER" || fail "FullScreenVideoCover no longer locks landscape"

if awk '
    /if hasAudio, showTransport/ { gated=1 }
    gated && /Button\("Close"\)/ { found=1 }
    END { exit found?0:1 }
' "$PLAYER"; then
    fail "composed Close is still gated on audio — a silent crawl cannot be left"
fi
grep -q 'Close video' "$PLAYER" || grep -q 'accessibilityLabel("Close' "$PLAYER" \
    || fail "composed player has no labelled Close"
grep -q 'OrientationController.lockLandscape' "$PLAYER" \
    || fail "composed player does not lock landscape on iPhone"

echo "iPhone player chrome is consistent"
echo "OK"
