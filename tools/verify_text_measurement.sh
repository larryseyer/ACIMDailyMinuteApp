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
// and a wide one.
let widths: [CGFloat] = [420, 560, 672, 830]

var failures: [String] = []
var checked = 0

func attributed(_ s: String) -> NSAttributedString {
    NSAttributedString(string: s, attributes: [.font: serif])
}

for c in bodies {
    var previous: CGFloat = .greatestFiniteMagnitude
    for w in widths {
        let h = ReadingTextMeasurement.height(of: attributed(c.body), width: w)
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
    }
}

// 4. A body twice as long is meaningfully taller at the same width — a constant
//    height would satisfy everything above.
let short = attributed(String(repeating: "The light of the world brings peace. ", count: 1))
let long = attributed(String(repeating: "The light of the world brings peace. ", count: 20))
let hs = ReadingTextMeasurement.height(of: short, width: 672)
let hl = ReadingTextMeasurement.height(of: long, width: 672)
checked += 2
if !(hl > hs * 2) {
    failures.append("length insensitive: 1x measured \(hs), 20x measured \(hl)")
}

if failures.isEmpty {
    print("PASS — \(checked) measurements over \(bodies.count) real bodies at \(widths.count) widths")
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
