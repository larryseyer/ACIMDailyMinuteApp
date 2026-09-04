#!/bin/bash
# Proves every reading in this app has one shape: the header keeps its words
# whole, its controls stay anchored, and no surface assembles its own bands.
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

                // ⛔ Everything below is asserted only where the control band
                // actually fits. A play control plus Share plus Save wants about
                // 198pt; below that the row is over-constrained and positions
                // necessarily shift, which says nothing about the design. The
                // narrowest real card is 303pt — his phone, in Display Zoom — so
                // 240pt is already narrower than anything that can occur.
                guard width >= 240 else { continue }

                // ⛔ The words stay whole. A wrapped title or a hyphenated button
                // makes the block taller — but so, deliberately, does the control
                // band splitting in two, which is how the header buys width when
                // three controls cannot share a line. Height alone can no longer
                // tell those apart, so this is asserted only above the width
                // where one band is still expected. Below it, and at every text
                // size, `verify_card_header_dynamic_type.sh` carries the check
                // that can tell them apart: it measures the block's WIDTH against
                // the card, which is what a squeezed or overflowing word actually
                // shows up as.
                check(abs(all.height - reference) < 2,
                      "\(label)/\(Int(width))pt listen=\(listen.map { String(Int($0)) } ?? "none"): "
                      + "\(all.height)pt, not \(reference)pt — a word wrapped")

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

    // ⛔ Every eyebrow the app draws, at the narrowest card it can be drawn in.
    // The band is lineLimit(1) with fixedSize: given too little width it breaks
    // the words rather than wrapping or shrinking, and nothing warns. A string
    // added to a surface without being added here is the failure this catches.
    let eyebrows = [
        "Daily Minute", "Lesson 365", "Introduction", "Manual", "Preface",
        "Chapter 31", "Text", "Workbook for Students", "Manual for Teachers",
        "A Course in Miracles"
    ]
    for eyebrow in eyebrows {
        let f = layout(label: eyebrow, listen: 80, width: 303)
        guard let all = f["all"] else {
            check(false, "eyebrow \(eyebrow.debugDescription) did not lay out")
            continue
        }
        check(abs(all.height - reference) < 2,
              "eyebrow \(eyebrow.debugDescription) is \(all.height)pt, not \(reference)pt — it wrapped at 303pt")
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

# ⛔ The band order lives in ONE file. These greps are the half of the check a
# layout harness cannot do: they prove no surface went back to assembling its
# own bands, which is how ten render sites drifted apart in the first place.
VIEWS="$REPO/ACIMDailyMinute/Views"

# 1. Every reading surface draws through the scaffold.
SURFACES="
Today/DailyMinuteCard.swift
Today/DailyLessonCard.swift
Today/CorpusReadingCard.swift
Archive/ArchivedReadingCard.swift
Lessons/LessonDetailView.swift
Lessons/WorkbookIntroductionView.swift
Text/TextSectionView.swift
Manual/ManualSegmentView.swift
Segment/SegmentReadingView.swift
"
for surface in $SURFACES; do
    if ! grep -q 'ReadingScaffold(' "$VIEWS/$surface"; then
        echo "FAIL: $surface draws a reading without ReadingScaffold"
        exit 1
    fi
done

# 2. Only the scaffold names CardHeaderRow. A surface reaching past it to the
#    header is a surface that can put the other bands anywhere.
HEADER_USERS="$(grep -rln 'CardHeaderRow(' "$VIEWS" | grep -v 'ReadingScaffold.swift' | grep -v 'CardHeaderRow.swift' || true)"
if [ -n "$HEADER_USERS" ]; then
    echo "FAIL: these reach past the scaffold to the header directly:"
    echo "$HEADER_USERS"
    exit 1
fi

# 3. Save belongs in the header, never in a nav toolbar. Four screens used to
#    put it there, which is why a reader found it in a different place
#    depending on how they arrived at the same lesson.
TOOLBAR_SAVE="$(grep -rl 'SaveButton' "$VIEWS" --include='*.swift' \
    | xargs grep -ln 'ToolbarItem' 2>/dev/null || true)"
if [ -n "$TOOLBAR_SAVE" ]; then
    echo "FAIL: Save is back in a nav toolbar in:"
    echo "$TOOLBAR_SAVE"
    exit 1
fi

# 4. Nobody hand-rolls a Listen control. Three surfaces did, at a different
#    font and padding than the shared one.
INLINE_LISTEN="$(grep -rln 'Label("Listen", systemImage:' "$VIEWS" \
    | grep -v 'ListenButton.swift' || true)"
if [ -n "$INLINE_LISTEN" ]; then
    echo "FAIL: a Listen control is hand-rolled in:"
    echo "$INLINE_LISTEN"
    exit 1
fi

echo "the scaffold owns the bands: 9 surfaces, one header, no toolbar Save, no hand-rolled Listen"
echo "OK"
