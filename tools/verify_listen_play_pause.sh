#!/bin/bash
# Proves a playing episode can be paused from the same control that started it.
#
# What this guards is a play-only surface. Today and the compact Now Playing
# bar both call playOrToggle / togglePlayback so a second tap pauses.
#
#   ./tools/verify_listen_play_pause.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONTROL="$REPO/ACIMDailyMinute/Views/ReadingPlayControl.swift"
CONTENT="$REPO/ACIMDailyMinute/App/ContentView.swift"
PLAYER="$REPO/ACIMDailyMinute/Views/Listen/MiniPlayerView.swift"
FULL="$REPO/ACIMDailyMinute/Views/Listen/NowPlayingView.swift"

fail() { echo "FAIL: $1"; exit 1; }

grep -q 'ListenButton' "$CONTROL" || fail "ReadingPlayControl does not use ListenButton"
grep -q 'playOrToggle' "$CONTROL" || fail "ReadingPlayControl never calls playOrToggle"
grep -q 'togglePlayback' "$PLAYER" || fail "MiniPlayerView has no pause"
grep -q 'MiniPlayerView()' "$CONTENT" || fail "ContentView does not draw MiniPlayerView"
grep -q 'togglePlayback' "$FULL" || fail "NowPlayingView has no pause"
if grep -q 'selectedTab != 2' "$CONTENT"; then
    fail "ContentView still hides the overlay on a Listen tab"
fi

echo "play/pause matches Today"
echo "OK"
