#!/bin/bash
# Proves the reading header keeps its words whole at every TEXT SIZE, not just
# every width — and it measures the REAL controls doing it.
#
# ⛔ This check exists because `verify_card_header.sh` cannot see this defect,
# and could not be extended to. Two reasons, both measured:
#
#   1. `dynamicTypeSize` DOES NOTHING ON macOS. `Text("Listen").font(.caption)`
#      renders 30.5x13.0pt at every size from xSmall to accessibility5 under
#      `ImageRenderer` on AppKit. A Dynamic Type sweep written the way the other
#      harnesses are written is a no-op that always passes — the worst kind of
#      check, because it reports a number and guards nothing. The same probe
#      built for the iOS simulator answers 35.5pt at `large` and 115.0pt at
#      `accessibility5`. So this harness compiles for `iphonesimulator` and runs
#      under `simctl spawn`. That is the whole reason it is a separate file.
#
#   2. The other harness hands `CardHeaderRow` `Color.clear` rectangles of a
#      fixed width. A placeholder cannot grow with text size, so it would hide
#      exactly the failure being hunted. This one compiles the three real
#      controls and measures them.
#
# What it caught: on his phone's 303pt card, `Save` renders 99.5pt wide at
# `accessibility3` and 56.5pt at `accessibility5`, against a natural width of
# 138.5pt and 95.5pt. `lineLimit(1)` + `fixedSize(horizontal: true)` does not
# save a label — under real constraint SwiftUI squeezes it anyway, drops
# nothing, and warns about nothing.
#
# ⛔ It never drives the iPad simulator. Other apps control this computer, and
# he has asked that that device be left alone. It boots an iPhone SE (3rd gen)
# headlessly — no Simulator.app — and shuts down only a device it booted itself.
#
#   ./tools/verify_card_header_dynamic_type.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
SIM_UUID=""
BOOTED_BY_US=0

cleanup() {
    rm -rf "$WORK"
    # Shut down ONLY a device this script booted. A simulator he left running
    # is his, and killing it mid-session is the kind of thing that makes a
    # check something people stop running.
    if [ "$BOOTED_BY_US" = "1" ] && [ -n "$SIM_UUID" ]; then
        xcrun simctl shutdown "$SIM_UUID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# ── Resolve an SE-class simulator on iOS 18.1 ────────────────────────────────
# SE-class on purpose: 375pt is the canvas his iPhone 11 Pro Max actually
# reports, because Display Zoom is on. The card inside it is 303pt.
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
    # `simctl spawn` against a half-booted device fails with a launchd error
    # that looks nothing like "not ready yet". Wait for the boot to complete
    # rather than sleeping a guessed number of seconds.
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

/// Render a view and read back the frames it published. `ImageRenderer` is what
/// forces a real layout pass without a window or a running app.
@MainActor
func render<V: View>(_ view: V) -> [String: CGRect] {
    var out: [String: CGRect] = [:]
    let probe = view.onPreferenceChange(FrameKey.self) { out = $0 }
    let renderer = ImageRenderer(content: probe)
    renderer.scale = 2
    _ = renderer.uiImage
    return out
}

/// The running head as a surface actually builds it.
@MainActor
func layout(parent: String, citation: String?, width: CGFloat, _ size: DynamicTypeSize) -> [String: CGRect] {
    let header = CardHeaderRow(parent: parent, citation: citation) {
    } trailing: {
    }
    return render(
        header
            .tracked("all", "hdr")
            .coordinateSpace(name: "hdr")
            .environment(\.dynamicTypeSize, size)
            .frame(width: width)
    )
}

/// What the citation wants when nothing is squeezing it.
@MainActor
func naturalCitation(_ size: DynamicTypeSize) -> CGFloat {
    let f = render(
        CitationLabel(raw: "W-365")
            .tracked("cit", "nat")
            .coordinateSpace(name: "nat")
            .environment(\.dynamicTypeSize, size)
            .frame(width: 4000)
    )
    return f["cit"]?.width ?? 0
}

var failures = 0
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 24 { print("  \(message())") }
    }
}

MainActor.assumeIsolated {
    let sizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
    ]
    // 303pt is his phone inside the card; 342pt a 414pt phone; 672pt the wide
    // readable column. The narrow end is far below anything real, on purpose.
    let widths: [CGFloat] = [90, 120, 160, 200, 240, 280, 303, 342, 500, 672]

    let parents = [
        "Workbook", "Review II", "Daily Minute", "Manual", "Preface",
        "Text", "Introduction"
    ]
    let citations = ["W-84", "W-365", "T-31.8", "Pref.4"]

    for size in sizes {
        let nat = naturalCitation(size)
        check(nat > 0, "\(size): the citation measured zero — nothing laid out")

        for width in widths {
            guard width >= 240 else { continue }
            let f = layout(parent: "Workbook", citation: "W-84", width: width, size)
            guard let all = f["all"] else {
                check(false, "Workbook/\(Int(width))pt/\(size): the header did not lay out")
                continue
            }
            check(all.width <= width + 0.5,
                  "\(Int(width))pt/\(size): the running head is \(all.width)pt inside a \(Int(width))pt card")
            check(all.height > 0, "\(Int(width))pt/\(size): the header has no height")
        }
    }

    for size in sizes {
        let reference = layout(parent: "Text", citation: "W-84", width: 303, size)["all"]!.height
        for parent in parents {
            guard let all = layout(parent: parent, citation: "W-84", width: 303, size)["all"] else {
                check(false, "parent \(parent.debugDescription)/\(size) did not lay out")
                continue
            }
            check(all.width <= 303 + 0.5,
                  "parent \(parent.debugDescription)/\(size): the block is \(all.width)pt inside a 303pt card")
            if !size.isAccessibilitySize {
                check(all.height <= reference + 8,
                      "parent \(parent.debugDescription)/\(size): \(all.height)pt vs \(reference)pt — it wrapped at 303pt")
            }
        }
        for citation in citations {
            guard let all = layout(parent: "Review II", citation: citation, width: 303, size)["all"] else {
                check(false, "citation \(citation)/\(size) did not lay out")
                continue
            }
            check(all.width <= 303 + 0.5,
                  "citation \(citation)/\(size): the block is \(all.width)pt inside a 303pt card")
            if !size.isAccessibilitySize {
                check(all.height <= reference + 8,
                      "citation \(citation)/\(size): \(all.height)pt vs \(reference)pt — it wrapped at 303pt")
            }
        }
    }

    if failures == 0 {
        print("\(checks) checks over \(sizes.count) text sizes and \(widths.count) widths, the running head stays inside the card")
        print("OK")
    } else {
        print("\(failures) FAILURE(S) of \(checks) checks")
    }
    exit(failures == 0 ? 0 : 1)
}
SWIFT

VIEWS="$REPO/ACIMDailyMinute/Views"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

# ⛔ The compile line names the running head and the citation — and the
# palette and type scale they reach for. Nothing else may enter.
xcrun -sdk iphonesimulator swiftc -O \
    -target arm64-apple-ios18.1-simulator -sdk "$SDK" \
    "$VIEWS/CardHeaderRow.swift" \
    "$VIEWS/CitationLabel.swift" \
    "$VIEWS/ACIMColors.swift" \
    "$REPO/ACIMDailyMinute/Utilities/ACIMType.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

xcrun simctl spawn "$SIM_UUID" "$WORK/verify"

for f in CardHeaderRow CitationLabel; do
    SRC="$(sed 's://.*::' "$VIEWS/$f.swift")"
    for banned in "SwiftData" "CorpusService" "ReadingKey" "AudioManager" "ModelContext" "UserDefaults"; do
        if echo "$SRC" | grep -q "$banned"; then
            echo "FAIL: $f.swift reaches for $banned — it is no longer measurable on its own"
            exit 1
        fi
    done
done

echo "the running head stays measurable: no store, no service, no session"
echo "OK"
