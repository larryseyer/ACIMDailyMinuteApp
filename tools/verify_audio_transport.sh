#!/bin/bash
# Proves a Listen position can be scrubbed, and that the bar the reader
# sees is a real player — elapsed / remaining, a fraction the slider can
# bind, a clamp so a drag past the end is the end.
#
# What this guards is MiniPlayerView's 40pt ProgressView. That view cannot
# be dragged, so Today and Listen had no way to move in the file except
# lock-screen skip. The clamp lives here, Foundation-only, so a seek is
# not a guess made inside AVPlayer.
#
#   ./tools/verify_audio_transport.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/ACIMDailyMinute/Utilities/AudioTransport.swift"
PBX="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"
PLAYER="$REPO/ACIMDailyMinute/Views/Listen/MiniPlayerView.swift"
MANAGER="$REPO/ACIMDailyMinute/Services/AudioManager.swift"
CONTENT="$REPO/ACIMDailyMinute/App/ContentView.swift"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$SRC" ]] || fail "AudioTransport.swift missing — there is no seek clamp"

count=$(grep -c "AudioTransport.swift" "$PBX" || true)
[[ "$count" -ge 6 ]] || fail "AudioTransport.swift has $count pbxproj lines; need the four build entries plus group child"

# The bar itself must expose a slider, times, and a way off. A ProgressView
# is not a player.
grep -q 'Slider' "$PLAYER" || fail "MiniPlayerView has no Slider — listen position cannot be set"
grep -q 'AudioTransport.timeLabel' "$PLAYER" || fail "MiniPlayerView does not draw elapsed time"
grep -q 'AudioTransport.remainingLabel' "$PLAYER" || fail "MiniPlayerView does not draw remaining time"
grep -q 'audioManager.seek' "$PLAYER" || fail "MiniPlayerView never seeks"
grep -q 'audioManager.stop' "$PLAYER" || fail "MiniPlayerView has no close"
if grep -q 'ProgressView' "$PLAYER"; then
    fail "MiniPlayerView still uses ProgressView — that cannot be dragged"
fi

# The manager must honour an absolute seek, not only skip-by.
grep -q 'func seek(to' "$MANAGER" || fail "AudioManager has no seek(to:)"
grep -q 'AudioTransport.clampedPosition' "$MANAGER" || fail "AudioManager seek does not clamp"

# Read is reading. Today's leftover bar must not sit on it.
if grep -n 'hasActiveAudio && selectedTab != 2' "$CONTENT"; then
    fail "ContentView still overlays the mini player on Read"
fi
grep -q 'selectedTab != 1 && selectedTab != 2' "$CONTENT" \
    || fail "ContentView does not hide the overlay on Read and Listen"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

func check(_ cond: Bool, _ msg: String) {
    if !cond { fputs("FAIL: \(msg)\n", stderr); exit(1) }
}

check(AudioTransport.clampedPosition(12, duration: 60) == 12, "in-range stays")
check(AudioTransport.clampedPosition(-4, duration: 60) == 0, "negative clamps to 0")
check(AudioTransport.clampedPosition(90, duration: 60) == 60, "past the end clamps to duration")
check(AudioTransport.clampedPosition(.nan, duration: 60) == 0, "NaN position is 0, not a lying place")
check(AudioTransport.clampedPosition(12, duration: .nan) == 0, "NaN duration cannot place")
check(AudioTransport.clampedPosition(12, duration: 0) == 0, "unknown duration cannot place")
check(AudioTransport.clampedPosition(.infinity, duration: 60) == 60, "infinity clamps to the end")

check(AudioTransport.sliderFraction(position: 15, duration: 60) == 0.25, "a quarter of the file")
check(AudioTransport.sliderFraction(position: 0, duration: 60) == 0, "start is 0")
check(AudioTransport.sliderFraction(position: 60, duration: 60) == 1, "end is 1")
check(AudioTransport.sliderFraction(position: 12, duration: 0) == 0, "unknown duration is 0, not NaN")
check(AudioTransport.sliderFraction(position: .nan, duration: 60) == 0, "NaN fraction is 0")

check(AudioTransport.timeLabel(0) == "0:00", "zero")
check(AudioTransport.timeLabel(12) == "0:12", "twelve seconds")
check(AudioTransport.timeLabel(75) == "1:15", "a minute and a bit")
check(AudioTransport.timeLabel(-3) == "0:00", "negative time is not a label")
check(AudioTransport.timeLabel(.nan) == "0:00", "NaN time is not a label")

check(AudioTransport.remainingLabel(position: 12, duration: 72) == "-1:00", "a minute left")
check(AudioTransport.remainingLabel(position: 0, duration: 60) == "-1:00", "whole file remaining")
check(AudioTransport.remainingLabel(position: 60, duration: 60) == "-0:00", "finished remaining")
check(AudioTransport.remainingLabel(position: 12, duration: 0) == "-0:00", "unknown duration remaining")

print("audio transport")
print("OK")
SWIFT

swiftc -O "$SRC" "$WORK/main.swift" -o "$WORK/verify"
"$WORK/verify"

echo "audio transport can be scrubbed"
echo "OK"
