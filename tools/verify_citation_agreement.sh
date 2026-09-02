#!/bin/bash
# Proves Swift's Citation and Python's tools/citations.py are one format and one
# paragraph rule.
#
# The citation is printed into a plain-text export that outlives this app, and
# it is derived on two sides: Python writes segment citations at export, Swift
# derives section, lesson and highlight citations at render. If they ever drift,
# the same passage cites differently depending on which tier it came from, and
# nothing about that failure looks like a bug.
#
#   ./tools/verify_citation_agreement.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

/usr/bin/python3 - "$REPO" "$WORK/cases.json" <<'PY'
import json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(repo / "tools"))

# ⛔ The cases come from `citations.py`'s OWN renderers, never from strings
# retyped here. Retyped expectations would agree with a Python renderer that had
# drifted, the export would write a format Swift cannot parse, every check would
# still pass, and every Daily Minute would quietly fall back to a book name.
from citations import introduction_citation, lesson_citation, text_citation

# Every shape of the format, including the ones that must be REFUSED. A parser
# that accepts "T-5.3" as a citation would silently drop the paragraph.
render = []
for c in range(0, 32):
    for s in (1, 2, 9):
        raw = text_citation(c, s, 1)
        render.append({"raw": raw, "stem": raw.rsplit(".", 1)[0], "paragraph": 1})
for p in (1, 14, 42):
    render.append({"raw": text_citation(0, 1, p), "stem": "Pref", "paragraph": p})
for n in (1, 45, 180, 365):
    raw = lesson_citation(n, 3)
    render.append({"raw": raw, "stem": raw.rsplit(".", 1)[0], "paragraph": 3})
render.append({"raw": introduction_citation(0, 2), "stem": "W-pI.in", "paragraph": 2})
render.append({"raw": introduction_citation(500, 1), "stem": "W-pII.in", "paragraph": 1})

refuse = ["", " ", "T-5.3", "T-5.3.7.1", "T-.3.7", "T-5.3.", "T-a.b.c", "Pref",
          "Pref.", "Pref.0", "W-", "W-45", "W-45.", "W-0.1", "W-366.1",
          "W-45.0", "W-pI.in", "W-pIII.in.1", "M-1.1", "5.3.7", "t-5.3.7",
          "T-5.0.1", "T--1.1.1", "W-pI.in.0"]

# What actually shipped. The generated cases prove the two renderers agree on
# the shapes we thought of; this proves Swift can read every citation that is
# in the bundle right now, which is the string a reader's export will carry.
stored = sorted({
    row["citation"]
    for row in json.loads(
        (repo / "ACIMDailyMinute" / "Resources" / "ACIMSegments.json").read_text(encoding="utf-8")
    )
    if row.get("citation")
})

out.write_text(
    json.dumps({"render": render, "refuse": refuse, "stored": stored}, ensure_ascii=False),
    encoding="utf-8",
)
print(f"{len(render)} render cases, {len(refuse)} refusal cases, "
      f"{len(stored)} shipped citations from Python")
PY

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

struct RenderCase: Decodable { let raw: String; let stem: String; let paragraph: Int }
struct Cases: Decodable { let render: [RenderCase]; let refuse: [String]; let stored: [String] }

let cases = try JSONDecoder().decode(
    Cases.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
)

var failures = 0
func fail(_ message: String) {
    failures += 1
    if failures <= 10 { print("  \(message)") }
}

for c in cases.render {
    guard let parsed = Citation(rawValue: c.raw) else {
        fail("did not parse: \(c.raw)"); continue
    }
    if parsed.rawValue != c.raw { fail("round trip: \(c.raw) -> \(parsed.rawValue)") }
    if parsed.stem != c.stem { fail("stem: \(c.raw) -> \(parsed.stem), want \(c.stem)") }
    if parsed.paragraph != c.paragraph { fail("paragraph: \(c.raw) -> \(parsed.paragraph)") }
}

for bad in cases.refuse where Citation(rawValue: bad) != nil {
    fail("accepted what it must refuse: \(bad.debugDescription)")
}

for raw in cases.stored {
    guard let parsed = Citation(rawValue: raw) else {
        fail("shipped citation Swift cannot read: \(raw)"); continue
    }
    if parsed.rawValue != raw { fail("shipped round trip: \(raw) -> \(parsed.rawValue)") }
}
print("\(cases.stored.count) shipped citations parse and round trip")

// Paragraph arithmetic over a display string, which joins paragraphs with
// exactly "\n\n". Offsets are Character counts, so the accented and emoji cases
// are the ones that would expose a UTF-16 slip.
let display = "one\n\ntwo\n\ncafé é\n\n🕊 four"
let expectations: [(Int, Int)] = [
    (0, 1), (1, 1), (3, 1), (4, 1), (5, 2), (7, 2), (10, 3), (16, 3), (18, 4), (99, 4),
]
for (offset, want) in expectations {
    let got = Citation.paragraphNumber(atCharacterOffset: offset, in: display)
    if got != want { fail("paragraphNumber(\(offset)) = \(got), want \(want)") }
}
if Citation.paragraphNumber(atCharacterOffset: 0, in: "") != 1 {
    fail("empty string must be paragraph 1")
}

struct ParagraphCase: Decodable { let display: String; let offset: Int; let expected: Int }
struct RangeCase: Decodable { let display: String; let paragraphs: [String] }
struct ParagraphFixture: Decodable { let cases: [ParagraphCase]; let ranges: [RangeCase] }

let fixture = try JSONDecoder().decode(
    ParagraphFixture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
)
for c in fixture.cases {
    let got = Citation.paragraphNumber(atCharacterOffset: c.offset, in: c.display)
    if got != c.expected {
        fail("real body offset \(c.offset): Swift \(got), Python \(c.expected)")
    }
}
print("\(fixture.cases.count) real-bundle paragraph offsets checked")

// The inverse. Paragraph n's range must hold exactly paragraph n, its first
// and last characters must count back to n, consecutive ranges must be two
// characters apart (the "\n\n" join), and 0 and count + 1 must be refused.
var rangesChecked = 0
for c in fixture.ranges {
    let chars = Array(c.display)
    var previousEnd: Int? = nil
    for (index, expected) in c.paragraphs.enumerated() {
        let n = index + 1
        guard let range = Citation.paragraphRange(n, in: c.display) else {
            fail("paragraphRange(\(n)) is nil for a body with \(c.paragraphs.count) paragraphs"); continue
        }
        rangesChecked += 1
        if String(chars[range]) != expected {
            fail("paragraphRange(\(n)) holds \(String(chars[range]).prefix(40).debugDescription), want \(expected.prefix(40).debugDescription)")
        }
        if Citation.paragraphNumber(atCharacterOffset: range.lowerBound, in: c.display) != n {
            fail("paragraphRange(\(n)).lowerBound counts back to a different paragraph")
        }
        if !range.isEmpty,
           Citation.paragraphNumber(atCharacterOffset: range.upperBound - 1, in: c.display) != n {
            fail("paragraphRange(\(n)) last character counts back to a different paragraph")
        }
        if let previousEnd, range.lowerBound != previousEnd + 2 {
            fail("paragraphRange(\(n)) starts \(range.lowerBound - previousEnd) after the previous, want 2")
        }
        previousEnd = range.upperBound
    }
    if Citation.paragraphRange(0, in: c.display) != nil { fail("paragraphRange(0) must be nil") }
    if Citation.paragraphRange(c.paragraphs.count + 1, in: c.display) != nil {
        fail("paragraphRange(count + 1) must be nil")
    }
}
if Citation.paragraphRange(1, in: "") != 0..<0 { fail("paragraph 1 of an empty string is 0..<0") }
if Citation.paragraphRange(2, in: "") != nil { fail("paragraph 2 of an empty string is nil") }
print("\(rangesChecked) real-bundle paragraph ranges round-trip")

if failures == 0 {
    print("\(cases.render.count + cases.refuse.count + cases.stored.count + expectations.count + rangesChecked) cases, Swift and Python agree")
} else {
    print("\(failures) FAILURE(S)")
}
exit(failures == 0 ? 0 : 1)
SWIFT

/usr/bin/python3 - "$REPO" "$WORK/paragraphs.json" <<'PY'
import json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(repo / "tools"))
from citations import display_paragraphs, paragraph_number

resources = repo / "ACIMDailyMinute" / "Resources"

def load(name):
    return json.loads((resources / name).read_text(encoding="utf-8"))

cases = []
ranges = []
bodies = []
for row in load("ACIMTextSections.json"):
    bodies.append(row["body"])
for row in load("Workbook365Bodies.json"):
    bodies.append(row["body"])
for row in load("WorkbookIntroductions.json"):
    bodies.append(row["body"])

# Probe the offsets where the rule can be wrong: the first character of every
# paragraph, the character before it, and the two newlines between them. An
# off-by-one here misfiles a highlight into its neighbour.
for body in bodies:
    paragraphs = display_paragraphs(body)
    display = "\n\n".join(paragraphs)
    offset = 0
    probes = {0, len(display)}
    for index, paragraph in enumerate(paragraphs):
        if index:
            probes.update({offset - 2, offset - 1, offset})
        offset += len(paragraph) + 2
    for probe in sorted(p for p in probes if 0 <= p <= len(display)):
        cases.append({"display": display, "offset": probe,
                      "expected": paragraph_number(probe, display)})
    # The inverse: paragraph n is exactly paragraphs[n-1], in Character offsets.
    ranges.append({"display": display, "paragraphs": paragraphs})

out.write_text(json.dumps({"cases": cases, "ranges": ranges}, ensure_ascii=False),
               encoding="utf-8")
print(f"{len(cases)} paragraph cases and {sum(len(r['paragraphs']) for r in ranges)} "
      f"paragraph ranges from Python over {len(bodies)} real bodies")
PY

swiftc -O "$WORK/main.swift" \
    "$REPO/ACIMDailyMinute/Utilities/Citation.swift" \
    -o "$WORK/verify"
"$WORK/verify" "$WORK/cases.json" "$WORK/paragraphs.json"
