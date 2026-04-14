#!/bin/bash
# build.sh — Fast Debug build verification for all 3 ACIM Daily Minute targets
# Builds to simulators only (no physical device, no install/launch).
# Use this for quick "does it compile?" checks during development.
set -e
set -o pipefail  # propagate failures through pipes (tail would otherwise mask xcodebuild exit codes)

SCHEME="ACIMDailyMinute"
# iPad (10th generation) on iOS 18.1 is the current phased test target
# (per memory project_test_targets.md). Physical iPhone 11 comes in when
# we're close to shipping.
#
# The name "iPad (10th generation)" matches multiple installed simulators
# (one per architecture/runtime slot), so xcodebuild emits "Using the first
# of multiple matching destinations" when given name= form. Resolve to a
# single UUID up front and fail loudly if none is available.
IPHONE_OS="18.1"
WATCH_SIM="Apple Watch Series 10 (46mm)"
BUILD_DIR="$(pwd)/build"
LOG_DIR="$(pwd)/build/logs"
mkdir -p "$LOG_DIR"

resolve_ipad_sim_uuid() {
  xcrun simctl list devices available -j | /usr/bin/python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS-18-1' not in runtime:
        continue
    for d in devices:
        if d.get('name') == 'iPad (10th generation)' and d.get('isAvailable', False):
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
"
}

IPAD_UUID="$(resolve_ipad_sim_uuid || true)"
if [[ -z "$IPAD_UUID" ]]; then
  echo "✗ No available iPad (10th generation) simulator on iOS ${IPHONE_OS}."
  echo "  Install one via Xcode → Settings → Platforms, then retry."
  exit 1
fi

echo "═══════════════════════════════════════════════"
echo "  ACIM Daily Minute — Debug Build Verification"
echo "═══════════════════════════════════════════════"
echo ""

# run_build <label> <log-file> <xcodebuild-args...>
#
# Full xcodebuild output is streamed to the log file; only the tail is
# echoed on success. On failure, we print the last 80 lines of the log
# and exit non-zero so the caller sees the actual error (the old script
# piped straight into `tail -5`, which always exits 0 and masked real
# failures — that is how the phantom-file pbxproj rot went undetected).
run_build() {
  local label="$1"; shift
  local log="$1"; shift
  echo "▸ Building ${label}..."
  if xcodebuild "$@" > "$log" 2>&1; then
    tail -5 "$log"
    echo "✓ ${label} build succeeded"
  else
    local status=$?
    echo ""
    echo "✗ ${label} build FAILED (exit $status). Last 80 lines of log:"
    echo "  ($log)"
    echo "-----------------------------------------------"
    tail -80 "$log"
    echo "-----------------------------------------------"
    exit $status
  fi
  echo ""
}

# ── iOS Simulator (covers main app + widget + Live Activity) ──
run_build "iOS (Debug) iPad (10th generation) iOS ${IPHONE_OS} [${IPAD_UUID}]" \
  "$LOG_DIR/ios.log" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=${IPAD_UUID}" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build

# ── macOS (unified target with #if os(macOS) guards) ──
run_build "macOS (Debug)" \
  "$LOG_DIR/macos.log" \
  -scheme "$SCHEME" \
  -destination "platform=macOS" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build

# ── watchOS Simulator ──
run_build "watchOS (Debug) ${WATCH_SIM}" \
  "$LOG_DIR/watchos.log" \
  -scheme "ACIMDailyMinuteWatch Watch App" \
  -destination "platform=watchOS Simulator,name=${WATCH_SIM}" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build

echo "═══════════════════════════════════════════════"
echo "  ✓ All 3 targets compile cleanly"
echo "═══════════════════════════════════════════════"
