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

/// The header as a surface actually builds it, with the real controls.
@MainActor
func layout(label: String, listen: Bool, width: CGFloat, _ size: DynamicTypeSize) -> [String: CGRect] {
    let header = CardHeaderRow(label) {
        if listen { ListenButton(title: label, action: {}).tracked("listen", "hdr") }
    } trailing: {
        ShareButton(text: "A passage.").tracked("share", "hdr")
        SaveButton(isSaved: true, action: {}).tracked("save", "hdr")
    }
    return render(
        header
            .tracked("all", "hdr")
            .coordinateSpace(name: "hdr")
            .environment(\.dynamicTypeSize, size)
            .frame(width: width)
    )
}

/// What a control wants when nothing is squeezing it. Measured at a width no
/// card will ever have, so the number is the control's own idea of its size.
@MainActor
func natural(_ size: DynamicTypeSize) -> (listen: CGFloat, share: CGFloat, save: CGFloat) {
    let f = render(
        HStack(spacing: 0) {
            ListenButton(title: "Daily Minute", action: {}).tracked("listen", "nat")
            ShareButton(text: "A passage.").tracked("share", "nat")
            SaveButton(isSaved: true, action: {}).tracked("save", "nat")
        }
        .coordinateSpace(name: "nat")
        .environment(\.dynamicTypeSize, size)
        .frame(width: 4000)
    )
    return (f["listen"]?.width ?? 0, f["share"]?.width ?? 0, f["save"]?.width ?? 0)
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

    // ⛔ Every eyebrow the app draws. A string added to a surface without being
    // added here is the failure this catches — at text size now, not just width.
    let eyebrows = [
        "Daily Minute", "Lesson 365", "Introduction", "Manual", "Preface",
        "Chapter 31", "Text", "Workbook for Students", "Manual for Teachers",
        "A Course in Miracles"
    ]

    for size in sizes {
        let nat = natural(size)
        check(nat.listen > 0 && nat.share > 0 && nat.save > 0,
              "\(size): a control measured zero — nothing laid out")

        // ⛔ The line above which the header owes every control its full width.
        // The header buys width by adding BANDS, so the narrowest card that can
        // hold these controls uncrushed is the wider of: the play control alone
        // on one band, and Share + Save together on the next. Below that line no
        // arrangement of bands can help and a squeeze is geometry, not a defect.
        //
        // The 8 is the trailing band's own spacing, counted rather than guessed:
        // its `HStack(spacing: 4)` puts 4pt between Share and Save, and another
        // 4pt between the leading `Spacer` and the pair.
        let trailingBand = nat.share + nat.save + 8
        let twoBandMinimum = max(nat.listen, trailingBand)

        for width in widths {
            for listen in [false, true] {
                let f = layout(label: "Daily Minute", listen: listen, width: width, size)
                guard let all = f["all"], let share = f["share"], let save = f["save"] else {
                    check(false, "Daily Minute/\(Int(width))pt/\(size): the header did not lay out")
                    continue
                }

                // ⛔ THE NEW ASSERTION, and the one the width-only sweep cannot
                // make: no control is drawn narrower than it asked to be. This
                // is what "the words got squeezed" looks like as a number.
                if twoBandMinimum <= width {
                    check(share.width >= nat.share - 0.5,
                          "Share/\(Int(width))pt/\(size): drawn \(share.width)pt, wants \(nat.share)pt — squeezed")
                    check(save.width >= nat.save - 0.5,
                          "Save/\(Int(width))pt/\(size): drawn \(save.width)pt, wants \(nat.save)pt — squeezed")
                    if listen, let l = f["listen"] {
                        check(l.width >= nat.listen - 0.5,
                              "Listen/\(Int(width))pt/\(size): drawn \(l.width)pt, wants \(nat.listen)pt — squeezed")
                    }
                }

                // ⛔ Below 240pt the controls are known to move and to spill,
                // and `verify_card_header.sh` already draws that same line: the
                // narrow end of the ladder is swept so the WORDS can be checked
                // there, not so the positions can. A card is never this narrow —
                // his phone gives the block 303pt.
                guard width >= 240 else { continue }

                // Nothing may spill outside the card it was given.
                check(share.maxX <= width + 0.5 && save.maxX <= width + 0.5,
                      "\(Int(width))pt/\(size): a control is drawn outside the card")

                // Share precedes Save, at every size. Their order is the thing a
                // reader's hand learns.
                check(share.minX < save.minX,
                      "\(Int(width))pt/\(size): Save is drawn before Share")

                // ⛔ Neither moves when the play control appears. Most readings
                // have no audio, so that button is usually absent; this is what
                // anchoring it to the leading edge is FOR.
                if listen {
                    let without = layout(label: "Daily Minute", listen: false, width: width, size)
                    if let s0 = without["share"], let v0 = without["save"] {
                        check(abs(s0.minX - share.minX) < 0.5,
                              "\(Int(width))pt/\(size): Share moved when the play control appeared")
                        check(abs(v0.minX - save.minX) < 0.5,
                              "\(Int(width))pt/\(size): Save moved when the play control appeared")
                    }
                    if let l = f["listen"] {
                        check(l.minX < share.minX,
                              "\(Int(width))pt/\(size): the play control is not on the leading edge")
                    }
                }

                check(all.height > 0, "\(Int(width))pt/\(size): the header has no height")
            }
        }
    }

    // ⛔ The eyebrow band, at the narrowest card the app really draws and at
    // every text size. It is lineLimit(1) + fixedSize: given too little width it
    // breaks its words rather than wrapping or shrinking, and nothing warns.
    // A wrap shows up as a band taller than the one-line reference.
    for size in sizes {
        // ⛔ The reference is the SHORTEST eyebrow at the SAME width, not the
        // same eyebrow at a wider one. The control band below legitimately
        // becomes two bands on a narrow card at a large text size, so a
        // reference taken at 672pt measures that extra band and calls it a wrap.
        // Same width, same band count: what is left over is the eyebrow.
        let reference = layout(label: "Text", listen: true, width: 303, size)["all"]!.height
        for eyebrow in eyebrows {
            guard let all = layout(label: eyebrow, listen: true, width: 303, size)["all"] else {
                check(false, "eyebrow \(eyebrow.debugDescription)/\(size) did not lay out")
                continue
            }

            // ⛔ THE ASSERTION THAT MATTERS, and the one a height check misses
            // entirely: the block is never wider than the card it was given.
            // `fixedSize(horizontal: true)` does not wrap and does not shrink —
            // it OVERFLOWS, silently, and drags the whole block's width with it,
            // which is what pushed Save outside the card. A height check cannot
            // see that, because overflowing is precisely how the text avoids
            // getting taller.
            check(all.width <= 303 + 0.5,
                  "eyebrow \(eyebrow.debugDescription)/\(size): the block is \(all.width)pt inside a 303pt card")

            // Below the accessibility sizes the eyebrow still owes one line —
            // wrapping there would mean a card rearranging itself for a text
            // size an ordinary reader uses.
            if !size.isAccessibilitySize {
                check(all.height <= reference + 2,
                      "eyebrow \(eyebrow.debugDescription)/\(size): \(all.height)pt vs \(reference)pt — it wrapped at 303pt")
            }
        }
    }

    if failures == 0 {
        print("\(checks) checks over \(sizes.count) text sizes and \(widths.count) widths, nothing is squeezed")
        print("OK")
    } else {
        print("\(failures) FAILURE(S) of \(checks) checks")
    }
    exit(failures == 0 ? 0 : 1)
}
SWIFT

VIEWS="$REPO/ACIMDailyMinute/Views"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

# ⛔ The compile line names the header and the three real controls — and their
# palette, which is the only thing they reach for. Nothing else may enter. A
# control that starts needing a model or a service is a control this harness can
# no longer measure, and the only way left to see it would be a phone whose text
# size happens to match the reader's.
xcrun -sdk iphonesimulator swiftc -O \
    -target arm64-apple-ios18.1-simulator -sdk "$SDK" \
    "$VIEWS/CardHeaderRow.swift" \
    "$VIEWS/ListenButton.swift" \
    "$VIEWS/SaveButton.swift" \
    "$VIEWS/ShareButton.swift" \
    "$VIEWS/ACIMColors.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

xcrun simctl spawn "$SIM_UUID" "$WORK/verify"

# ⛔ A lone-file `swiftc` links these without complaint, so the compile above
# cannot prove their absence — a grep has to. Comments are stripped first: what
# must stay out of these files is a DEPENDENCY, and the doc comments legitimately
# name things they do not use.
for f in CardHeaderRow ListenButton SaveButton ShareButton; do
    SRC="$(sed 's://.*::' "$VIEWS/$f.swift")"
    for banned in "SwiftData" "CorpusService" "ReadingKey" "AudioManager" "ModelContext" "UserDefaults"; do
        if echo "$SRC" | grep -q "$banned"; then
            echo "FAIL: $f.swift reaches for $banned — it is no longer measurable on its own"
            exit 1
        fi
    done
done

echo "the header and its three controls stay measurable: no store, no service, no session"
echo "OK"
