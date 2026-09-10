#!/bin/bash
# Proves an iPad-regular page uses the parent width, not a phone-sized column.
#
# What this guards is the empty wings on iPad. `readableContentWidth()` used
# to clamp to 672pt whenever `horizontalSizeClass == .regular`, then centre
# that strip. On an iPad (10th generation) in landscape that is 254pt of
# blank on each side — the same thin-page failure the television already
# rejected. The iPad uses the screen; the surfaces' own 20pt padding is the
# inset. macOS still clamps, because a window can be as wide as a display.
#
# ⛔ It never drives the iPad simulator. Other apps control this computer, and
# he has asked that that device be left alone. It boots an iPhone SE (3rd gen)
# headlessly — no Simulator.app — and injects `.regular` at the widths an
# iPad actually proposes. Shut down only a device it booted itself.
#
#   ./tools/verify_ipad_reading_width.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
SIM_UUID=""
BOOTED_BY_US=0

cleanup() {
    rm -rf "$WORK"
    if [ "$BOOTED_BY_US" = "1" ] && [ -n "$SIM_UUID" ]; then
        xcrun simctl shutdown "$SIM_UUID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

SIM_NAME="iPhone SE (3rd generation)"
SIM_OS="18.1"

SIM_UUID="$(xcrun simctl list devices available -j | /usr/bin/python3 -c "
import json, sys
want = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS-18-1' not in runtime:
        continue
    for d in devices:
        if d.get('name') == want and d.get('isAvailable', False):
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" "$SIM_NAME" || true)"

if [ -z "$SIM_UUID" ]; then
    echo "✗ No available ${SIM_NAME} simulator on iOS ${SIM_OS}."
    echo "  Install one via Xcode → Settings → Platforms, then retry."
    exit 1
fi

STATE="$(xcrun simctl list devices -j | /usr/bin/python3 -c "
import json, sys
uuid = sys.argv[1]
data = json.load(sys.stdin)
for _, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('udid') == uuid:
            print(d.get('state', ''))
            sys.exit(0)
" "$SIM_UUID")"

if [ "$STATE" != "Booted" ]; then
    echo "▸ Booting ${SIM_NAME} [${SIM_UUID}] headlessly..."
    xcrun simctl boot "$SIM_UUID"
    BOOTED_BY_US=1
    xcrun simctl bootstatus "$SIM_UUID" >/dev/null 2>&1 || true
fi

cat > "$WORK/main.swift" <<'SWIFT'
import SwiftUI
import UIKit

setvbuf(stdout, nil, _IONBF, 0)

struct FrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, b in b }
    }
}

extension View {
    func tracked(_ name: String, _ space: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: FrameKey.self, value: [name: g.frame(in: .named(space))])
        })
    }
}

/// What `readableContentWidth()` actually gives a child at this parent width
/// and size class. `ImageRenderer` forces a real layout pass without a window.
@MainActor
func column(parent: CGFloat, sizeClass: UserInterfaceSizeClass) -> CGRect {
    var out: [String: CGRect] = [:]
    let probe = Color.clear
        .frame(height: 8)
        .tracked("column", "page")
        .readableContentWidth()
        .environment(\.horizontalSizeClass, sizeClass)
        .frame(width: parent, height: 8)
        .coordinateSpace(name: "page")
        .onPreferenceChange(FrameKey.self) { out = $0 }
    let renderer = ImageRenderer(content: probe)
    renderer.scale = 1
    _ = renderer.uiImage
    return out["column"] ?? .null
}

var failures = 0
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        print("  \(message())")
    }
}

MainActor.assumeIsolated {
    // iPad (10th generation) portrait and landscape, plus the 12.9-inch
    // canvases. All of these report `.regular` when the app is full screen.
    let regularParents: [CGFloat] = [820, 1024, 1180, 1366]
    for parent in regularParents {
        let frame = column(parent: parent, sizeClass: .regular)
        check(abs(frame.width - parent) < 0.5,
              "regular \(Int(parent))pt parent: column is \(frame.width)pt, not the parent")
        check(abs(frame.minX) < 0.5,
              "regular \(Int(parent))pt parent: column origin \(frame.minX)pt — it is centred in empty wings")
    }

    // Compact is a phone, or an iPad Slide Over / Split View slice. It already
    // filled the parent; keep it that way at a phone width and at a wide one.
    for parent: CGFloat in [320, 375, 428, 1180] {
        let frame = column(parent: parent, sizeClass: .compact)
        check(abs(frame.width - parent) < 0.5,
              "compact \(Int(parent))pt parent: column is \(frame.width)pt, not the parent")
        check(abs(frame.minX) < 0.5,
              "compact \(Int(parent))pt parent: column origin \(frame.minX)pt")
    }

    if failures == 0 {
        print("\(checks) checks, the iPad-regular column uses the parent")
        print("OK")
    } else {
        print("\(failures) FAILURE(S) of \(checks) checks")
    }
    exit(failures == 0 ? 0 : 1)
}
SWIFT

UTIL="$REPO/ACIMDailyMinute/Utilities"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

# ⛔ The compile line names ONE source file and no others. The column policy
# must stay free of the app's models and services, or the only way to see it
# is to launch the whole app on an iPad this harness is forbidden to drive.
xcrun -sdk iphonesimulator swiftc -O \
    -target arm64-apple-ios18.1-simulator -sdk "$SDK" \
    "$UTIL/ReadableContentWidth.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

xcrun simctl spawn "$SIM_UUID" "$WORK/verify"
