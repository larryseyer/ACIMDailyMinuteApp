#!/bin/bash
# Proves the Listen tab can pause the episode it started, the same way the
# Today header does.
#
# What this guards is a play-only list. ContentView hides the mini-player
# overlay on the Listen tab (a tap there only switches to Listen), and the
# rows used to start playback and then swap the glyph for a waveform — so
# once a Minute or Lesson was playing there was nowhere on this tab to
# pause it. The shared ListenButton plus playOrToggle is the same control
# the Today cards already use; the mini player has to be drawn here rather
# than merely reserved as empty space.
#
#   ./tools/verify_listen_play_pause.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROW="$REPO/ACIMDailyMinute/Views/Listen/ListenPlayableRow.swift"
VIEW="$REPO/ACIMDailyMinute/Views/Listen/ListenView.swift"
CONTENT="$REPO/ACIMDailyMinute/App/ContentView.swift"

fail() { echo "FAIL: $1"; exit 1; }

# 1. Each audio row uses the shared Listen/Play/Pause control. Hand-rolling
#    a Pause label is already forbidden by verify_card_header.sh.
grep -q 'ListenButton(' "$ROW" || fail "ListenPlayableRow does not use ListenButton"

# 2. A waveform cannot be paused. Playing is Pause, paused is Play.
if grep -q '"waveform"' "$ROW"; then
    fail "playing glyph is still a waveform, which has no pause"
fi

# 3. A second tap on the active episode must toggle, not restart.
grep -q 'playOrToggle' "$VIEW" || fail "ListenView never calls playOrToggle"

# 4. Identity is the URL, the same rule as the Today header. Matching on
#    title would paint Pause on every Daily Minute at once.
grep -q 'isActive(url:' "$VIEW" || fail "ListenView does not match the session on URL"

# 5. ContentView still hides the overlay on this tab — that is why ListenView
#    itself must construct MiniPlayerView. MiniPlayerView.height only sizes
#    a gap; it does not draw a pause control.
grep -q 'selectedTab != 2' "$CONTENT" || fail "ContentView no longer hides the overlay on Listen"
grep -q 'MiniPlayerView()' "$VIEW" || fail "ListenView reserves mini player space but never draws it"

echo "Listen tab play/pause matches Today"
echo "OK"
