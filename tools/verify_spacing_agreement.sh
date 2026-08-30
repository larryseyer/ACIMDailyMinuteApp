#!/bin/bash
# Proves Swift's PunctuationSpacing.repaired and Python's repair() are one rule.
#
# They are two implementations of a rule that decides what the reader sees: the
# bundle is repaired by the Python one at export, feed text by the Swift one at
# render. If they ever drift, the same passage reads differently depending on
# which tier it came from, and nothing about that failure looks like a bug.
#
# Exhaustive over the rule's decision surface -- every left/right character pair
# it can distinguish, plus the possessive cases that are the only real ambiguity
# -- and then over every body in the shipped bundle, which must be a fixed point.
#
#   ./tools/verify_spacing_agreement.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

/usr/bin/python3 - "$REPO" "$WORK/cases.json" <<'PY'
import itertools, json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(repo / "tools"))
from punctuation_spacing import repair

# Every character class the rule can tell apart, on both sides of the boundary.
LEFT = list(".,;:!?”’“‘") + ["a", "z", "A", "Z", "S", "0", ")", " ", "-"]
RIGHT = list("AZSazs“‘”’") + ["0", " ", ".", ")", "-"]

cases = ["word" + left + right + "tail" for left, right in itertools.product(LEFT, RIGHT)]

# The possessive is the one place the rule has to make a judgement, so spell
# every shape of it out rather than trusting the product above to cover it.
cases += [
    "GOD’S PLAN FOR SALVATION", "the ego’s.And so", "God’S", "God’Sing",
    "the only ‘sacrifice’You ask", "his Father’s.This needs", "nor was I.You are",
    "their Source,Which is", "William Thetford.The edit", "sin.”To study",
    "the ego may ask,“How did", "peace,TEACH peace", "Here you are;This is you",
    "one thing:You THINK", "answer 11 GOD’S PLAN to YOU", "", " ", ".", "’S", "’",
]
# Two boundaries in a row, and a boundary at either end of the string. The
# accented and combining cases matter because offsets are Character-based: a
# rule that disagreed about a grapheme boundary would shift every stored offset
# after it.
cases += ["a.Bc,De", ".A", "A.", "a.B", "”A", "’A", "..A", "a..B", "a. B",
          "café.École", "naïve,Élan", "é.Á", "🕊.The dove", "a.Ω"]

# Real data: the shipped bundle must already be a fixed point of the rule.
for name in ("ACIMTextSections.json", "Workbook365Bodies.json", "ACIMSegments.json",
             "ACIMManual.json", "WorkbookIntroductions.json"):
    rows = json.loads((repo / "ACIMDailyMinute" / "Resources" / name).read_text(encoding="utf-8"))
    cases += [row["body"] for row in rows]

out.write_text(json.dumps(
    [{"input": c, "expected": repair(c)} for c in cases], ensure_ascii=False
), encoding="utf-8")
print(f"{len(cases)} cases from Python")
PY

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

struct Case: Decodable { let input: String; let expected: String }

let cases = try JSONDecoder().decode(
    [Case].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
)

var disagreements = 0
for c in cases {
    let got = PunctuationSpacing.repaired(c.input)
    if got != c.expected {
        disagreements += 1
        if disagreements <= 5 {
            print("  Python: \(c.expected.debugDescription)")
            print("  Swift:  \(got.debugDescription)")
        }
    }
    // The rule has to be idempotent or export and render cannot both apply it.
    if PunctuationSpacing.repaired(got) != got {
        disagreements += 1
        print("  not idempotent: \(c.input.debugDescription)")
    }
}

if disagreements == 0 {
    print("\(cases.count) cases, Swift and Python agree, rule idempotent")
} else {
    print("\(disagreements) DISAGREEMENT(S)")
}
exit(disagreements == 0 ? 0 : 1)
SWIFT

swiftc -O "$WORK/main.swift" \
    "$REPO/ACIMDailyMinute/Utilities/PunctuationSpacing.swift" \
    -o "$WORK/verify"
"$WORK/verify" "$WORK/cases.json"
