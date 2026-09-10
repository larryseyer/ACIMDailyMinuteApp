#!/bin/bash
# Capture App Store screenshots. One simulator at a time — booting iPhone,
# iPad, and TV together freezes the iPad framebuffer and leaves the TV
# screenshot on the app switcher.
#
# Scene selection is a UserDefaults key (`ACIM_SCREENSHOT_TAB`) so it does
# not leak across devices the way SIMCTL_CHILD_ env vars did.
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

only_boot() {
    local keep="$1"
    for id in "$IPHONE" "$IPAD" "$TV"; do
        if [ "$id" != "$keep" ]; then
            xcrun simctl shutdown "$id" 2>/dev/null || true
        fi
    done
    xcrun simctl boot "$keep" 2>/dev/null || true
    xcrun simctl bootstatus "$keep" -b >/dev/null
    open -a Simulator --args -CurrentDeviceUDID "$keep"
    sleep 3
    osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
}

launch_scene() {
    local udid="$1" tab="$2"
    unset SIMCTL_CHILD_ACIM_SCREENSHOT_TAB
    xcrun simctl spawn "$udid" defaults write "$BUNDLE" hasSeenOnboarding -bool true
    xcrun simctl spawn "$udid" defaults write "$BUNDLE" ACIM_SCREENSHOT_TAB -string "$tab"
    xcrun simctl privacy "$udid" deny notifications "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE" >/dev/null
    # tvOS terminate lands on the switcher; a second launch brings the app forward.
    sleep 2
    xcrun simctl launch "$udid" "$BUNDLE" >/dev/null
}

shot() {
    local udid="$1" dest="$2" wait_s="${3:-7}"
    mkdir -p "$(dirname "$dest")"
    sleep "$wait_s"
    xcrun simctl io "$udid" screenshot "$dest"
    echo "  wrote $dest"
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
    only_boot "$udid"
    xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active 2>/dev/null || true
    xcrun simctl privacy "$udid" deny notifications "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$udid" "$IOS_APP"
    for pair in "today:01-today" "read:02-read" "lesson:03-lesson" "archive:04-archive" "saved:05-saved" "settings:06-settings"; do
        tab="${pair%%:*}"
        file="${pair##*:}"
        launch_scene "$udid" "$tab"
        shot "$udid" "$OUT/$folder/$file.png" 7
    done
}

if [ "${SKIP_IPHONE:-}" != "1" ]; then
    echo "▸ iPhone 16 Pro Max"
    capture_ios "$IPHONE" "iphone-6.7"
else
    echo "▸ Skipping iPhone"
fi

echo "▸ iPad Pro 13-inch"
capture_ios "$IPAD" "ipad-13"

echo "▸ Building tvOS"
xcodebuild -scheme ACIMDailyMinuteTV \
    -destination "platform=tvOS Simulator,id=$TV" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build >/tmp/acim-shot-tv.log 2>&1
TV_APP="$BUILD_DIR/Debug-appletvsimulator/ACIMDailyMinuteTV.app"
only_boot "$TV"
xcrun simctl install "$TV" "$TV_APP"
for pair in "today:01-today" "read:02-read" "listen:03-listen" "archive:04-archive"; do
    tab="${pair%%:*}"
    file="${pair##*:}"
    launch_scene "$TV" "$tab"
    shot "$TV" "$OUT/appletv-1080/$file.png" 10
done

echo "▸ Mac"
xcodebuild -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build >/tmp/acim-shot-mac.log 2>&1
MAC_APP="$BUILD_DIR/Debug/ACIMDailyMinute.app"
if [ ! -d "$MAC_APP" ] && [ -d /Applications/ACIMDailyMinute.app ]; then
    MAC_APP=/Applications/ACIMDailyMinute.app
fi
defaults write "$BUNDLE" hasSeenOnboarding -bool true
killall ACIMDailyMinute 2>/dev/null || true
mkdir -p "$OUT/mac"
mac_window_id() {
    swift "$REPO/tools/mac_window_id.swift" 2>/dev/null || true
}
mac_shot() {
    local tab="$1" dest="$2"
    killall ACIMDailyMinute 2>/dev/null || true
    sleep 1
    defaults write "$BUNDLE" ACIM_SCREENSHOT_TAB -string "$tab"
    open -na "$MAC_APP"
    sleep 8
    osascript -e 'tell application "ACIMDailyMinute" to activate' >/dev/null 2>&1 || true
    sleep 1
    local wid
    wid="$(mac_window_id)"
    if [ -n "$wid" ]; then
        screencapture -l "$wid" -o "$dest"
        echo "  wrote $dest"
    else
        echo "  WARN: no Mac window for $tab" >&2
    fi
}
mac_shot today "$OUT/mac/01-today.png"
mac_shot read "$OUT/mac/02-read.png"
mac_shot archive "$OUT/mac/03-archive.png"
mac_shot saved "$OUT/mac/04-saved.png"
mac_shot settings "$OUT/mac/05-settings.png"
killall ACIMDailyMinute 2>/dev/null || true

echo "done"
find "$OUT" -name '*.png' | sort
