#!/bin/bash
# build.sh — Fast Debug build verification for all 3 ACIM Daily Minute targets
# Builds to simulators only (no physical device, no install/launch).
# Use this for quick "does it compile?" checks during development.
set -e

SCHEME="ACIMDailyMinute"
# iPad (10th generation) on iOS 18.1 is the current phased test target
# (per memory project_test_targets.md). Physical iPhone 11 comes in when
# we're close to shipping.
IPHONE_SIM="iPad (10th generation)"
IPHONE_OS="18.1"
WATCH_SIM="Apple Watch Series 10 (46mm)"
BUILD_DIR="$(pwd)/build"

echo "═══════════════════════════════════════════════"
echo "  ACIM Daily Minute — Debug Build Verification"
echo "═══════════════════════════════════════════════"
echo ""

# ── iOS Simulator (covers main app + widget + Live Activity) ──
echo "▸ Building iOS (Debug) for ${IPHONE_SIM} (iOS ${IPHONE_OS})..."
xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=${IPHONE_SIM},OS=${IPHONE_OS}" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build \
  2>&1 | tail -5

echo "✓ iOS build succeeded"
echo ""

# ── macOS (unified target with #if os(macOS) guards) ──
echo "▸ Building macOS (Debug)..."
xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=macOS" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build \
  2>&1 | tail -5

echo "✓ macOS build succeeded"
echo ""

# ── watchOS Simulator ──
echo "▸ Building watchOS (Debug) for ${WATCH_SIM}..."
xcodebuild \
  -scheme "ACIMDailyMinuteWatch Watch App" \
  -destination "platform=watchOS Simulator,name=${WATCH_SIM}" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build \
  2>&1 | tail -5

echo "✓ watchOS build succeeded"
echo ""

echo "═══════════════════════════════════════════════"
echo "  ✓ All 3 targets compile cleanly"
echo "═══════════════════════════════════════════════"
