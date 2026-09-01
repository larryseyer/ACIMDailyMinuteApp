#!/bin/bash
# Proves a card's header keeps its words whole and its controls anchored.
#
# What this guards is the STRIP ABOVE THE READING, against a failure that looks
# like nothing at all. When a label and its controls want more width than the
# card has, SwiftUI drops nothing and warns about nothing — it squeezes whatever
# can be squeezed, and the only squeezable things in that block are the words.
# On a real phone `DAILY MINUTE` broke across two lines and `Listen` hyphenated
# into `Lis-` and `ten`.
#
# It shipped because the play control is drawn only when `audio_url` is not
# empty, and it was empty on every episode until archive.org hosting existed.
# The button's arrival was triggered by DATA, not by code, so no build and no
# screenshot had ever drawn that block at its full width. ⛔ Any control that
# appears by itself when a feed fills in owes this kind of check.
#
# It also holds the reason the play control is leftmost: most readings have no
# audio, so that button is usually absent, and anchoring it to the leading edge
# is what stops Share and Save moving between one passage and the next.
#
# ⛔ The compile line names ONE source file and no others. That is half the
# check: the header must stay free of the app's models and services, or the only
# way to exercise it is to launch the whole app on a phone whose text size and
# display zoom happen to match the reader's.
#
#   ./tools/verify_card_header.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import SwiftUI
import AppKit

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

@MainActor
func layout(label: String, listen: CGFloat?, width: CGFloat) -> [String: CGRect] {
    var out: [String: CGRect] = [:]
    let header = CardHeaderRow(label) {
        if let listen { Color.clear.frame(width: listen, height: 44).tracked("listen", "hdr") }
    } trailing: {
        Color.clear.frame(width: 44, height: 44).tracked("share", "hdr")
        Color.clear.frame(width: 66, height: 44).tracked("save", "hdr")
    }
    let probe = header
        .tracked("all", "hdr")
        .coordinateSpace(name: "hdr")
        .frame(width: width)
        .onPreferenceChange(FrameKey.self) { out = $0 }
    let renderer = ImageRenderer(content: probe)
    renderer.scale = 2
    _ = renderer.nsImage
    return out
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
    let labels = ["Daily Minute", "Lesson 1", "Lesson 81", "Lesson 365", "Lesson"]
    // 303pt is his phone inside the card; 342pt a 414pt phone; 672pt the wide
    // readable column. The narrow end is far below anything real, on purpose.
    let widths: [CGFloat] = [90, 120, 160, 200, 240, 280, 303, 342, 500, 672]

    let reference = layout(label: "Daily Minute", listen: 80, width: 303)["all"]!.height
    check(reference > 44 && reference < 90,
          "the header is \(reference)pt tall — that is not a title band above a control band")

    for label in labels {
        for width in widths {
            for listen in [nil, 80] as [CGFloat?] {
                let f = layout(label: label, listen: listen, width: width)
                guard let all = f["all"], let share = f["share"], let save = f["save"] else {
                    check(false, "\(label) at \(Int(width))pt: the header did not lay out")
                    continue
                }

                // ⛔ The words stay whole, at EVERY width. A wrapped title or a
                // hyphenated button makes the block taller; nothing else here can.
                check(abs(all.height - reference) < 2,
                      "\(label)/\(Int(width))pt listen=\(listen.map { String(Int($0)) } ?? "none"): "
                      + "\(all.height)pt, not \(reference)pt — a word wrapped")

                // ⛔ Everything below is asserted only where the control band
                // actually fits. A play control plus Share plus Save wants about
                // 198pt; below that the row is over-constrained and positions
                // necessarily shift, which says nothing about the design. The
                // narrowest real card is 303pt — his phone, in Display Zoom — so
                // 240pt is already narrower than anything that can occur.
                guard width >= 240 else { continue }

                // Share sits before Save, both on the trailing edge.
                check(share.maxX <= save.minX + 0.5,
                      "\(label)/\(Int(width))pt: Save is drawn before Share")
                check(save.maxX >= all.maxX - 1,
                      "\(label)/\(Int(width))pt: Save is not on the trailing edge")

                // ⛔ The point of a leading play control: Share and Save do not
                // move when it appears, and it appears for maybe one reading in
                // a hundred.
                let without = layout(label: label, listen: nil, width: width)
                check(abs((without["save"]?.minX ?? -1) - save.minX) < 0.5,
                      "\(label)/\(Int(width))pt: Save moved when the play control appeared")
                check(abs((without["share"]?.minX ?? -1) - share.minX) < 0.5,
                      "\(label)/\(Int(width))pt: Share moved when the play control appeared")

                if let listenFrame = f["listen"] {
                    check(listenFrame.minX <= all.minX + 1,
                          "\(label)/\(Int(width))pt: the play control is not on the leading edge")
                    check(listenFrame.maxX <= share.minX + 0.5,
                          "\(label)/\(Int(width))pt: the play control overlaps Share")
                }
            }
        }
    }

    if failures == 0 {
        print("\(checks) checks, the header keeps its words and Save stays put")
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
