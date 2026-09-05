#!/bin/bash
# Proves a reading reports a real height, so its card grows to fit the words.
#
# What this guards is not the text but the BOX AROUND IT. A measurement that
# collapses to zero does not crash and does not warn: SwiftUI simply allocates
# no room, the note button and the citation are laid out under the header, and
# the text draws straight over them until the card's clipShape cuts it off
# mid-sentence. Every other check in this repo asks whether the words are right.
# None of them can see that the words are unreadable.
#
# ⛔ A box can also be too SMALL by a little, and that is the other half. The
# measurement must equal what a real text view lays out, not merely be positive
# and monotonic — a height uniformly 7% short satisfies every rule about size
# and clips the end of every passage. So the last rule here builds an
# `NSTextView` configured exactly as `SelectableReadingText.makeNSView`
# configures it and compares point for point, at the line spacing the reading
# SCREENS actually pass.
#
# What that caught: `ReadingTextMeasurement` measured with TextKit 1 while both
# text views draw with TextKit 2. The two agree exactly at `lineSpacing: 0` —
# which is what the Today cards pass, and what every case in this harness used
# to be built with — and part company the moment it is non-zero. At the
# `lineSpacing: 3` the five reading screens pass, T-1.3 measured 2491pt against
# a drawn 2672pt on iOS, so 290 characters — four sentences — were clipped off
# the end of the passage with `Add note` and the citation drawn tidily beneath
# them and nothing to scroll to.
#
# ⛔ NEVER read `view.layoutManager` in this harness. That property downgrades
# an `NSTextView` to TextKit 1, and the check would then cheerfully agree with
# the very defect it exists to catch.
#
# ⛔ The compile line names ONE source file and no others. That is half the
# check: the measurement must stay free of SwiftUI, SwiftData, Bundle and
# CorpusService, or it can only be exercised by launching the whole app on one
# platform — which is exactly how this shipped.
#
#   ./tools/verify_text_measurement.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Real bodies from the SHIPPED bundle, not invented strings. Line breaking is
# decided by the actual words, their em dashes and their restored spaces; a
# lorem-ipsum body would wrap differently and prove less.
/usr/bin/python3 - "$REPO" "$WORK/bodies.json" <<'CASES'
import json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
resources = repo / "ACIMDailyMinute" / "Resources"
load = lambda n: json.loads((resources / n).read_text(encoding="utf-8"))

cases = []
def take(rows, label, n):
    """A spread through the file, not the first n, so one odd row cannot hide."""
    rows = [r for r in rows if r.get("body", "").strip()]
    if not rows:
        return
    step = max(1, len(rows) // n)
    for r in rows[::step][:n]:
        cases.append({"label": f"{label} {r.get('sectionTitle') or r.get('lessonNumber') or r.get('segmentId')}",
                      "body": r["body"]})

take(load("ACIMTextSections.json"), "text", 12)
take(load("Workbook365Bodies.json"), "lesson", 12)
take(load("ACIMSegments.json"), "segment", 12)
take(load("ACIMManual.json"), "manual", 6)
take(load("WorkbookIntroductions.json"), "introduction", 2)

# The shortest real body in the bundle, which is where a collapse hides best.
shortest = min(
    (r["body"] for r in load("ACIMSegments.json") if r.get("body", "").strip()),
    key=len,
)
cases.append({"label": "shortest segment", "body": shortest})

out.write_text(json.dumps(cases), encoding="utf-8")
print(f"{len(cases)} real bodies, shortest {len(shortest)} chars, longest {max(len(c['body']) for c in cases)} chars")
CASES

cat > "$WORK/main.swift" <<'SWIFT'
import AppKit
import Foundation

struct Case: Decodable { let label: String; let body: String }

let bodies = try! JSONDecoder().decode(
    [Case].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
)

// The serif body the reading surfaces actually draw in.
let base = NSFont.preferredFont(forTextStyle: .body)
let serif = base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: base.pointSize) } ?? base

// Widths a real window produces: the 672pt readable column, a narrow window,
// a wide one, and the 335pt an iPad gives a reading in a compact slice.
let widths: [CGFloat] = [335, 420, 560, 672, 830]

// ⛔ Both values matter and only one of them used to be here. The Today cards
// draw at 0; the five reading SCREENS — Text section, lesson detail, Workbook
// introduction, Manual segment, Segment reading — all pass 3. A sweep at 0
// alone is the blind spot that let a TextKit 1 measurement ship, because that
// is the one value at which the two engines agree.
let lineSpacings: [CGFloat] = [0, 3]

var failures: [String] = []
var checked = 0

func attributed(_ s: String, lineSpacing: CGFloat) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    return NSAttributedString(
        string: s, attributes: [.font: serif, .paragraphStyle: paragraph]
    )
}

/// The height a REAL text view lays this string out in, set up exactly as
/// `SelectableReadingText.makeNSView` sets one up.
///
/// ⛔ `textLayoutManager` and never `layoutManager`: reading the latter drops
/// the view onto TextKit 1, which is the engine this rule exists to rule out.
@MainActor
func drawnHeight(_ a: NSAttributedString, width: CGFloat) -> CGFloat? {
    let view = NSTextView()
    view.isEditable = false
    view.isSelectable = true
    view.drawsBackground = false
    view.textContainerInset = .zero
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = true
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.setFrameSize(NSSize(width: width, height: 10))
    view.textContainer?.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
    view.textStorage?.setAttributedString(a)

    guard let layout = view.textLayoutManager else { return nil }
    layout.ensureLayout(for: layout.documentRange)
    return ceil(layout.usageBoundsForTextContainer.maxY)
}

for c in bodies {
  for lineSpacing in lineSpacings {
    var previous: CGFloat = .greatestFiniteMagnitude
    for w in widths {
        let a = attributed(c.body, lineSpacing: lineSpacing)
        let h = ReadingTextMeasurement.height(of: a, width: w)
        checked += 1

        // 1. A reading always occupies room.
        if h <= 0 {
            failures.append("\(c.label): height \(h) at width \(w) — the card will collapse")
            previous = 0
            continue
        }
        // 2. At least one line's worth. Catches a measurement that returns
        //    something small but non-zero instead of a true collapse.
        let oneLine = ceil(serif.ascender - serif.descender + serif.leading)
        if h < oneLine {
            failures.append("\(c.label): height \(h) at width \(w) is under one line (\(oneLine))")
        }
        // 3. Narrower is never shorter. A measurement that ignores the width it
        //    was handed passes 1 and 2 but fails this.
        if h > previous {
            failures.append("\(c.label): width \(w) measured \(h), taller than at a narrower width (\(previous))")
        }
        previous = h

        // 4. ⛔ The measurement is the height the view actually lays out, to the
        //    point. Rules 1-3 are all satisfied by a height uniformly short by a
        //    percentage, and a short box clips the end of the passage in
        //    silence. This is the only rule that can see that.
        checked += 1
        guard let drawn = MainActor.assumeIsolated({ drawnHeight(a, width: w) }) else {
            failures.append("\(c.label): the probe text view came up on TextKit 1 — the check cannot answer")
            continue
        }
        if abs(h - drawn) > 0.5 {
            failures.append(
                "\(c.label): lineSpacing \(lineSpacing) at width \(w) measured \(h), "
                + "the text view lays out \(drawn) — \(drawn - h)pt of the reading is clipped"
            )
        }
    }
  }
}

// 5. A body twice as long is meaningfully taller at the same width — a constant
//    height would satisfy everything above.
let short = attributed(String(repeating: "The light of the world brings peace. ", count: 1), lineSpacing: 3)
let long = attributed(String(repeating: "The light of the world brings peace. ", count: 20), lineSpacing: 3)
let hs = ReadingTextMeasurement.height(of: short, width: 672)
let hl = ReadingTextMeasurement.height(of: long, width: 672)
checked += 2
if !(hl > hs * 2) {
    failures.append("length insensitive: 1x measured \(hs), 20x measured \(hl)")
}

if failures.isEmpty {
    print("PASS — \(checked) measurements over \(bodies.count) real bodies "
          + "at \(widths.count) widths and \(lineSpacings.count) line spacings")
} else {
    print("FAIL — \(failures.count) of \(checked) measurements wrong")
    for f in failures.prefix(15) { print("  \(f)") }
    if failures.count > 15 { print("  ... and \(failures.count - 15) more") }
    exit(1)
}
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Views/ReadingTextMeasurement.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify" "$WORK/bodies.json"
