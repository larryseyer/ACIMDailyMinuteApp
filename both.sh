#!/bin/bash
# both.sh — Build + run ACIM Daily Minute on BOTH current phased test targets:
#   1. iPad (10th generation) Simulator, iOS 18.1          (boot, install, launch)
#   2. Connected "iPhone 11 Pro Max" physical device, iOS 18.1 (install, launch)
#
# Unlike build.sh (which only compile-verifies iOS + macOS + watchOS), this
# script actually installs and launches the app on both targets for
# end-to-end testing.
#
# Debug configuration for fast iteration. Logs stream to build/logs/*.log so
# failures are never masked.
set -e
set -o pipefail

SCHEME="ACIMDailyMinute"
CONFIG="Debug"
IPHONE_OS="18.1"
IPAD_NAME="iPad (10th generation)"
IPHONE_NAME_MATCH="iPhone 11 Pro Max"   # substring match against devicectl device/marketing name

BUILD_DIR="$(pwd)/build"
LOG_DIR="$BUILD_DIR/logs"
mkdir -p "$LOG_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

banner() {
  echo ""
  echo "═══════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════"
}

fail_with_log() {
  local label="$1" log="$2" status="$3"
  echo ""
  echo "✗ ${label} FAILED (exit ${status}). Last 80 lines of log:"
  echo "  (${log})"
  echo "-----------------------------------------------"
  tail -80 "$log"
  echo "-----------------------------------------------"
  exit "$status"
}

# Resolve the iPad (10th gen) iOS 18.1 simulator UUID. Multiple runtime slots
# can share the same name, so we pick the first available on iOS-18-1.
resolve_ipad_sim_uuid() {
  xcrun simctl list devices available -j | /usr/bin/python3 -c "
import json, sys
target_runtime = 'iOS-18-1'
target_name = '${IPAD_NAME}'
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if target_runtime not in runtime:
        continue
    for d in devices:
        if d.get('name') == target_name and d.get('isAvailable', False):
            print(d['udid']); sys.exit(0)
sys.exit(1)
"
}

# Pull PRODUCT_BUNDLE_IDENTIFIER from the project so we don't hardcode it.
resolve_bundle_id() {
  xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER /{print $2; exit}'
}

# Find connected iPhone 11 Pro Max via devicectl (Apple's modern replacement
# for ios-deploy; required for iOS 17+).
resolve_iphone_device_id() {
  local tmp; tmp="$(mktemp)"
  if ! xcrun devicectl list devices --json-output "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 1
  fi
  /usr/bin/python3 -c "
import json, sys
match = '${IPHONE_NAME_MATCH}'
with open('$tmp') as f:
    data = json.load(f)
for d in data.get('result', {}).get('devices', []):
    props = d.get('deviceProperties', {}) or {}
    hw = d.get('hardwareProperties', {}) or {}
    name = props.get('name', '') or ''
    marketing = hw.get('marketingName', '') or ''
    if match in name or match in marketing:
        ident = d.get('identifier') or hw.get('udid', '') or ''
        if ident:
            print(ident); sys.exit(0)
sys.exit(1)
"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# ─────────────────────────────────────────────────────────────────────────────
# Pre-flight — gather everything we need before doing any work
# ─────────────────────────────────────────────────────────────────────────────

banner "ACIM Daily Minute — Build & Run Both Targets"

BUNDLE_ID="$(resolve_bundle_id || true)"
if [[ -z "$BUNDLE_ID" ]]; then
  echo "✗ Could not resolve PRODUCT_BUNDLE_IDENTIFIER from project settings."
  exit 1
fi
echo "• Bundle ID:         $BUNDLE_ID"

IPAD_UUID="$(resolve_ipad_sim_uuid || true)"
if [[ -z "$IPAD_UUID" ]]; then
  echo "✗ No available '${IPAD_NAME}' simulator on iOS ${IPHONE_OS}."
  echo "  Install one via Xcode → Settings → Platforms, then retry."
  exit 1
fi
echo "• iPad Sim UUID:     $IPAD_UUID"

# iPhone is optional: if it's not connected we warn but still run the iPad step.
IPHONE_DEVICE_ID="$(resolve_iphone_device_id || true)"
if [[ -z "$IPHONE_DEVICE_ID" ]]; then
  echo "⚠ No connected '${IPHONE_NAME_MATCH}' detected via devicectl."
  echo "  Ensure device is: (1) connected / paired, (2) unlocked,"
  echo "  (3) has Developer Mode enabled, (4) trusts this Mac."
  echo "  Will still build + run the iPad Sim target."
else
  echo "• iPhone Device ID:  $IPHONE_DEVICE_ID"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Part 1 — iPad (10th generation) Simulator, iOS 18.1
# ─────────────────────────────────────────────────────────────────────────────

banner "1/2  iPad Sim — build + install + launch"

IPAD_LOG="$LOG_DIR/ipad-sim.log"
echo "▸ Building (log: $IPAD_LOG)..."
if ! xcodebuild \
      -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,id=$IPAD_UUID" \
      -configuration "$CONFIG" \
      -derivedDataPath "$BUILD_DIR" \
      build > "$IPAD_LOG" 2>&1; then
  fail_with_log "iPad Sim build" "$IPAD_LOG" $?
fi
echo "✓ iPad Sim build succeeded"

APP_SIM="$BUILD_DIR/Build/Products/${CONFIG}-iphonesimulator/${SCHEME}.app"
if [[ ! -d "$APP_SIM" ]]; then
  echo "✗ Expected app bundle missing: $APP_SIM"
  exit 1
fi

echo "▸ Booting simulator (if needed)..."
xcrun simctl boot "$IPAD_UUID" 2>/dev/null || true   # harmless if already booted
open -a Simulator --args -CurrentDeviceUDID "$IPAD_UUID"

echo "▸ Installing $APP_SIM ..."
xcrun simctl install "$IPAD_UUID" "$APP_SIM"

echo "▸ Launching $BUNDLE_ID ..."
xcrun simctl launch "$IPAD_UUID" "$BUNDLE_ID"

echo "✓ iPad Sim running"

# ─────────────────────────────────────────────────────────────────────────────
# Part 2 — iPhone 11 Pro Max physical device, iOS 18.1
# ─────────────────────────────────────────────────────────────────────────────

if [[ -z "$IPHONE_DEVICE_ID" ]]; then
  banner "2/2  iPhone physical device — SKIPPED (not connected)"
  echo "Done. (iPad Sim ran; physical iPhone was not available.)"
  exit 0
fi

banner "2/2  iPhone 11 Pro Max (device) — build + install + launch"

IPHONE_LOG="$LOG_DIR/iphone-device.log"
echo "▸ Building for device (log: $IPHONE_LOG)..."
# Physical device needs real code signing; we rely on the project's automatic
# signing. If this fails for signing reasons, the log will say so clearly —
# don't paper over it with CODE_SIGNING_ALLOWED=NO (that would ship an
# unlaunchable bundle).
if ! xcodebuild \
      -scheme "$SCHEME" \
      -destination "platform=iOS,id=$IPHONE_DEVICE_ID" \
      -configuration "$CONFIG" \
      -derivedDataPath "$BUILD_DIR" \
      build > "$IPHONE_LOG" 2>&1; then
  fail_with_log "iPhone device build" "$IPHONE_LOG" $?
fi
echo "✓ iPhone device build succeeded"

APP_DEVICE="$BUILD_DIR/Build/Products/${CONFIG}-iphoneos/${SCHEME}.app"
if [[ ! -d "$APP_DEVICE" ]]; then
  echo "✗ Expected device app bundle missing: $APP_DEVICE"
  exit 1
fi

echo "▸ Installing on device ($IPHONE_DEVICE_ID)..."
xcrun devicectl device install app --device "$IPHONE_DEVICE_ID" "$APP_DEVICE"

echo "▸ Launching $BUNDLE_ID on device..."
xcrun devicectl device process launch --device "$IPHONE_DEVICE_ID" "$BUNDLE_ID"

echo "✓ iPhone 11 Pro Max running"

banner "✓ Both targets deployed and launched"
