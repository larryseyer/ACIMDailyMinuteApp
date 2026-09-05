#!/bin/bash
# build.sh — Fast Debug build verification for all 4 ACIM Daily Minute targets
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

# Same problem, worse: "Apple Watch Series 10 (46mm)" is installed on some
# watchOS runtimes but not the newest one, and a bare name= destination
# resolves against the newest runtime -- so the leg failed with "no such
# simulator" even though a perfectly good one was sitting on an older runtime.
# Search every available watchOS runtime and take the newest that actually
# has the device.
resolve_watch_sim_uuid() {
  xcrun simctl list devices available -j | /usr/bin/python3 -c "
import json, re, sys
want = sys.argv[1]
data = json.load(sys.stdin)
matches = []
for runtime, devices in data.get('devices', {}).items():
    if 'watchOS' not in runtime:
        continue
    version = tuple(int(n) for n in re.findall(r'\\d+', runtime.rsplit('.', 1)[-1]))
    for d in devices:
        if d.get('name') == want and d.get('isAvailable', False):
            matches.append((version, d['udid']))
if not matches:
    sys.exit(1)
print(max(matches)[1])
" "$WATCH_SIM"
}

# Same shape as the two above. An Apple TV 4K is picked by name across every
# installed tvOS runtime, newest first, because the runtimes that carry it move
# with Xcode the way the watch runtimes do.
resolve_tv_sim_uuid() {
  xcrun simctl list devices available -j | /usr/bin/python3 -c "
import json, re, sys
data = json.load(sys.stdin)
matches = []
for runtime, devices in data.get('devices', {}).items():
    if 'tvOS' not in runtime:
        continue
    version = tuple(int(n) for n in re.findall(r'\\d+', runtime.rsplit('.', 1)[-1]))
    for d in devices:
        if d.get('name') == 'Apple TV 4K (3rd generation)' and d.get('isAvailable', False):
            matches.append((version, d['udid']))
if not matches:
    sys.exit(1)
print(max(matches)[1])
"
}

IPAD_UUID="$(resolve_ipad_sim_uuid || true)"
if [[ -z "$IPAD_UUID" ]]; then
  echo "✗ No available iPad (10th generation) simulator on iOS ${IPHONE_OS}."
  echo "  Install one via Xcode → Settings → Platforms, then retry."
  exit 1
fi

WATCH_UUID="$(resolve_watch_sim_uuid || true)"
if [[ -z "$WATCH_UUID" ]]; then
  echo "✗ No available ${WATCH_SIM} simulator on any installed watchOS runtime."
  echo "  Install one via Xcode → Settings → Platforms, then retry."
  exit 1
fi

TV_UUID="$(resolve_tv_sim_uuid || true)"
if [[ -z "$TV_UUID" ]]; then
  echo "✗ No available Apple TV 4K (3rd generation) simulator on any installed tvOS runtime."
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
# Skip code signing for Debug verification — no provisioning profiles
# are needed when we only care about "does it compile?"
run_build "macOS (Debug)" \
  "$LOG_DIR/macos.log" \
  -scheme "$SCHEME" \
  -destination "platform=macOS" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build

# ── watchOS Simulator ──
run_build "watchOS (Debug) ${WATCH_SIM} [${WATCH_UUID}]" \
  "$LOG_DIR/watchos.log" \
  -scheme "ACIMDailyMinuteWatch Watch App" \
  -destination "platform=watchOS Simulator,id=${WATCH_UUID}" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build

# ── tvOS Simulator ──
# ⛔ A SEPARATE TARGET, not a destination of the app scheme: tvOS gets its own
# product, its own entitlements (App Group, no iCloud) and device family 3. It
# compiles the same source list as the app — every platform difference is a
# fence inside a file, so there is no second membership list to drift.
run_build "tvOS (Debug) Apple TV 4K (3rd generation) [${TV_UUID}]" \
  "$LOG_DIR/tvos.log" \
  -scheme "ACIMDailyMinuteTV" \
  -destination "platform=tvOS Simulator,id=${TV_UUID}" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build

echo "═══════════════════════════════════════════════"
echo "  ✓ All 4 targets compile cleanly"
echo "═══════════════════════════════════════════════"
