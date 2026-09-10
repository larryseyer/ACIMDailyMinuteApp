#!/bin/bash
# Capture App Store screenshots. Opens each scene from inside the app
# (ACIM_SCREENSHOT_TAB) so the system "Open in app?" alert never appears.
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/store-screenshots"
BUNDLE="com.larryseyer.acimdailyminute"
SCHEME="ACIMDailyMinute"
BUILD_DIR="$REPO/build"
mkdir -p "$OUT"

IPHONE="247D499D-4F1D-43F7-956B-1CB5C38813D7"
IPAD="5E10717F-1793-48C7-B890-2B816ECF74CC"
TV="A1BB3E0F-BED7-4AA8-A6F7-9907AC033345"

shot() {
    local udid="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    sleep 3
    xcrun simctl io "$udid" screenshot "$dest"
    echo "  wrote $dest"
}

launch_scene() {
    local udid="$1" tab="$2"
    export SIMCTL_CHILD_ACIM_SCREENSHOT_TAB="$tab"
    xcrun simctl spawn "$udid" defaults write "$BUNDLE" hasSeenOnboarding -bool true
    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE" >/dev/null
}

echo "▸ Building iOS"
xcodebuild -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$IPHONE" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build >/tmp/acim-shot-ios.log 2>&1
IOS_APP="$BUILD_DIR/Debug-iphonesimulator/ACIMDailyMinute.app"

capture_ios() {
    local udid="$1" folder="$2"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null
    xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active 2>/dev/null || true
    xcrun simctl install "$udid" "$IOS_APP"
    for pair in "today:01-today" "read:02-read" "lesson:03-lesson" "archive:04-archive" "saved:05-saved" "settings:06-settings"; do
        tab="${pair%%:*}"
        file="${pair##*:}"
        launch_scene "$udid" "$tab"
        shot "$udid" "$OUT/$folder/$file.png"
    done
}

echo "▸ iPhone 16 Pro Max"
open -a Simulator --args -CurrentDeviceUDID "$IPHONE"
capture_ios "$IPHONE" "iphone-6.7"

echo "▸ iPad Pro 13-inch"
open -a Simulator --args -CurrentDeviceUDID "$IPAD"
capture_ios "$IPAD" "ipad-13"

echo "▸ Building tvOS"
xcodebuild -scheme ACIMDailyMinuteTV \
    -destination "platform=tvOS Simulator,id=$TV" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build >/tmp/acim-shot-tv.log 2>&1
TV_APP="$BUILD_DIR/Debug-appletvsimulator/ACIMDailyMinuteTV.app"
xcrun simctl boot "$TV" 2>/dev/null || true
xcrun simctl bootstatus "$TV" -b >/dev/null
xcrun simctl install "$TV" "$TV_APP"
for pair in "today:01-today" "read:02-read" "listen:03-listen" "archive:04-archive"; do
    tab="${pair%%:*}"
    file="${pair##*:}"
    launch_scene "$TV" "$tab"
    shot "$TV" "$OUT/appletv-1080/$file.png"
done

echo "▸ Mac"
xcodebuild -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build >/tmp/acim-shot-mac.log 2>&1
MAC_BIN="$BUILD_DIR/Debug/ACIMDailyMinute.app/Contents/MacOS/ACIMDailyMinute"
defaults write "$BUNDLE" hasSeenOnboarding -bool true
killall ACIMDailyMinute 2>/dev/null || true
mkdir -p "$OUT/mac"
ACIM_SCREENSHOT_TAB=today "$MAC_BIN" >/tmp/acim-mac-app.log 2>&1 &
sleep 6
screencapture -l "$(osascript -e 'tell application "System Events" to id of window 1 of process "ACIMDailyMinute"' 2>/dev/null || true)" \
    "$OUT/mac/01-today.png" 2>/dev/null || screencapture "$OUT/mac/01-today.png"
echo "  wrote $OUT/mac/01-today.png"

echo "done"
find "$OUT" -name '*.png' | sort
