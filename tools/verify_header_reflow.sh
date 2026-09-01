#!/bin/bash
# Proves a card's header takes a second line rather than breaking its own words.
#
# What this guards is the STRIP ABOVE THE READING, and it guards it against a
# failure that looks like nothing at all. When the label and the controls need
# more width than the card has, SwiftUI does not drop a control and does not
# warn — it squeezes whatever can be squeezed, and the only squeezable things in
# that row are the two pieces of text. So they wrap: `DAILY MINUTE` broke onto
# two lines and `Listen` hyphenated into `Lis-` and `ten` on a real phone.
#
# It shipped because the Listen button is drawn only when `audio_url` is not
# empty, and it was empty on every episode until archive.org hosting existed.
# The button's arrival was triggered by DATA, not by code, so no build and no
# screenshot had ever drawn that row at its full width. ⛔ Any control that
# appears by itself when a feed fills in owes this kind of check.
#
# ⛔ The compile line names ONE source file and no others. That is half the
# check: the row must stay free of the app's models and services, or the only
# way to exercise it is to launch the whole app on a phone whose text size and
# display zoom happen to match the reader's.
#
#   ./tools/verify_header_reflow.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import SwiftUI
import AppKit

setvbuf(stdout, nil, _IONBF, 0)

struct SizeKey: PreferenceKey {
    static var defaultValue: [String: CGSize] = [:]
    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue()) { _, b in b }
    }
}

extension View {
    func measured(_ name: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: SizeKey.self, value: [name: g.size])
        })
    }
}

@MainActor
func height(label: String, controls: CGFloat, width: CGFloat) -> CGFloat {
    var out: [String: CGSize] = [:]
    let probe = CardHeaderRow(label) { Color.clear.frame(width: controls, height: 44) }
        .measured("row")
        .frame(width: width)
        .onPreferenceChange(SizeKey.self) { out = $0 }
    let renderer = ImageRenderer(content: probe)
    renderer.scale = 2
    _ = renderer.nsImage
    return out["row"]?.height ?? 0
}

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 20 { print("  \(message())") }
    }
}

MainActor.assumeIsolated {
    // Real labels: the two Today cards, the archive card, and the widest lesson.
    let labels = ["Daily Minute", "Lesson 1", "Lesson 81", "Lesson 365", "Lesson"]
    // Real control widths: Save alone, Save+Share, and Save+Share+Listen, which
    // is the combination that overflowed.
    let controlWidths: [CGFloat] = [66, 110, 190, 240]

    let oneRow = height(label: "Daily Minute", controls: 1, width: 2000)
    check(oneRow > 40 && oneRow < 60, "a header with room to spare is \(oneRow)pt tall, not one row")

    // The height of a correctly reflowed row: label on its own line, controls
    // beneath. Every narrow case below is compared against THIS, not against a
    // loose multiple of one row — a two-line label would slip under a bound of
    // `oneRow * 2`, and this check exists precisely to catch a wrapped label.
    let twoRow = height(label: "Daily Minute", controls: 240, width: 260)
    check(twoRow > oneRow + 2 && twoRow < oneRow * 2,
          "the reference reflowed row is \(twoRow)pt, which is not one label above one control row")

    for label in labels {
        for controls in controlWidths {
            // Bisect for the width at which the row gives up on one line.
            var lo: CGFloat = 40, hi: CGFloat = 1200
            for _ in 0..<40 {
                let mid = (lo + hi) / 2
                if height(label: label, controls: controls, width: mid) > oneRow + 2 { lo = mid }
                else { hi = mid }
            }

            // Comfortably wider than the flip: still one line.
            let wide = height(label: label, controls: controls, width: hi + 25)
            check(abs(wide - oneRow) < 2,
                  "\(label)/\(Int(controls)): \(Int(hi + 25))pt is enough room, but it took two lines")

            // Just under the flip: two lines, and exactly two.
            let narrow = height(label: label, controls: controls, width: hi - 25)
            check(narrow > oneRow + 2,
                  "\(label)/\(Int(controls)): \(Int(hi - 25))pt is too narrow, but it stayed on one line")
            check(abs(narrow - twoRow) < 2,
                  "\(label)/\(Int(controls)): the reflowed row is \(narrow)pt, not \(twoRow)pt — a word wrapped")

            // ⛔ The whole point. However hard the row is squeezed, it never
            // grows past two lines, because nothing in it is allowed to wrap.
            for width in stride(from: hi - 25, through: 60, by: -20) {
                let h = height(label: label, controls: controls, width: width)
                check(abs(h - twoRow) < 2,
                      "\(label)/\(Int(controls)) at \(Int(width))pt: \(h)pt, not \(twoRow)pt — a word wrapped")
            }
        }
    }

    // His phone, measured: a 375pt canvas leaves 303pt inside the card, and the
    // row needs about 310pt at xxLarge. It must reflow there and hold one line
    // on the 342pt a 414pt phone gives.
    let his = height(label: "Daily Minute", controls: 240, width: 303)
    let wide = height(label: "Daily Minute", controls: 190, width: 342)
    check(his > oneRow + 2, "at 303pt with three controls the row did not reflow")
    check(abs(his - twoRow) < 2, "at 303pt the row wrapped a word instead of reflowing")
    check(abs(wide - oneRow) < 2, "at 342pt with three controls the row reflowed unnecessarily")

    if failures == 0 {
        print("\(checks) checks, the header takes a second line instead of breaking a word")
        print("OK")
    } else {
        print("\(failures) FAILURE(S) of \(checks) checks")
    }
    exit(failures == 0 ? 0 : 1)
}
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Views/CardHeaderRow.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"
