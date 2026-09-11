#!/bin/bash
# Proves the iPhone chrome the reader actually uses: Read Minute matches
# Listen, unrecorded rows say when, Video is landscape and can be left.
#
# What this guards is four freshman misses in one pass: a Today player
# leaking onto Read, a calendar of days with nothing to play, Listen rows
# that omit play with no sentence, and a Video cover that cannot be closed.
#
#   ./tools/verify_iphone_player_chrome.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }

LISTEN="$REPO/ACIMDailyMinute/Views/Listen/ListenView.swift"
READ="$REPO/ACIMDailyMinute/Views/Lessons/LessonsView.swift"
ROW="$REPO/ACIMDailyMinute/Views/Listen/ListenPlayableRow.swift"
CAL="$REPO/ACIMDailyMinute/Views/Archive/ArchiveCalendarView.swift"
ARCHIVE="$REPO/ACIMDailyMinute/Views/Archive/ArchiveView.swift"
DETAIL="$REPO/ACIMDailyMinute/Views/Archive/ArchiveDateDetailView.swift"
PLAYER="$REPO/ACIMDailyMinute/Views/TVPlayerView.swift"
COVER="$REPO/ACIMDailyMinute/Views/Listen/FullScreenVideoCover.swift"
TEXT="$REPO/ACIMDailyMinute/Views/Listen/ListenTextChapterView.swift"

# 1. Read Minute has the same play + now-playing chrome as Listen, above
#    the calendar — not a chevron-only "Open reading" card underneath it.
grep -q 'ListenResumeRibbon' "$READ" || fail "Read Minute has no Now Playing ribbon"
grep -q 'ListenPlayableRow' "$READ" || fail "Read Minute has no play row"

# Selected-day row must appear in source before the calendar on both tabs.
listen_order=$(awk '
    /ListenResumeRibbon/ { r=NR }
    /ListenPlayableRow/ && !p { p=NR }
    /ArchiveCalendarView/ && !c { c=NR }
    END { print r+0, p+0, c+0 }
' "$LISTEN")
read_order=$(awk '
    /ListenResumeRibbon/ { r=NR }
    /ListenPlayableRow/ && !p { p=NR }
    /ArchiveCalendarView/ && !c { c=NR }
    END { print r+0, p+0, c+0 }
' "$READ")
# shellcheck disable=SC2086
set -- $listen_order
[[ "$1" -gt 0 && "$2" -gt 0 && "$3" -gt 0 && "$1" -lt "$3" && "$2" -lt "$3" ]] \
    || fail "Listen does not place now-playing and play above the calendar (ribbon=$1 play=$2 cal=$3)"
set -- $read_order
[[ "$1" -gt 0 && "$2" -gt 0 && "$3" -gt 0 && "$1" -lt "$3" && "$2" -lt "$3" ]] \
    || fail "Read does not place now-playing and play above the calendar (ribbon=$1 play=$2 cal=$3)"

# 2. Unrecorded Listen rows state when, not a silent title.
grep -q 'unrecordedCaption' "$ROW" || fail "ListenPlayableRow never states when unrecorded audio will exist"
grep -q 'unrecordedCaption' "$LISTEN" || fail "Listen lesson/text/manual never pass an availability caption"
grep -q 'unrecordedCaption' "$TEXT" || fail "Listen Text sections never state when audio will exist"

# 3. Calendar days without a recording are not selectable.
grep -q 'ArchiveCalendarState.isRecorded' "$CAL" \
    || fail "ArchiveCalendarView still lets every cell be selected"
grep -q 'availableDateStrings' "$CAL" || fail "calendar lost its recorded-day set"

# 4. Video YouTube on iPhone is the landscape cover with a Close, not an
#    inline card whose YouTube fullscreen cannot be left.
if grep -q 'LiteYouTubeCard' "$ARCHIVE"; then
    fail "Video tab still embeds LiteYouTubeCard — that is the trap"
fi
grep -q 'FullScreenVideoCover' "$ARCHIVE" \
    || fail "Video tab does not present FullScreenVideoCover for YouTube"
grep -q 'FullScreenVideoCover' "$DETAIL" \
    || fail "Video day does not present FullScreenVideoCover for YouTube"
grep -q 'lockLandscape' "$COVER" || fail "FullScreenVideoCover no longer locks landscape"

# 5. Composed player (Text / Manual / unnarrated) always has Close, and
#    on iPhone locks landscape. Transport gated on audio is the trap.
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
