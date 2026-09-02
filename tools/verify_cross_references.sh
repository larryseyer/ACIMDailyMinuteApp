#!/bin/bash
# Proves the one numbered self-reference the Course makes — a bracketed lesson
# number in a review lesson, "[181]" — is found everywhere it is and nowhere it
# is not, and that the link it becomes decodes back to the same lesson.
#
# What this guards is a TAP that goes to the wrong place. A rule that also
# matched "[name of person]" or a page number would draw a link the reader
# follows to a lesson the book never pointed at, and nothing about that looks
# like a bug: the lesson opens, the reader is simply somewhere else.
#
# ⛔ The compile line names ONE source file and no others. That is half the
# check: the rule must stay free of SwiftUI, SwiftData, Bundle, CorpusService
# and ReadingKey, or it can only be exercised by launching the app.
#
#   ./tools/verify_cross_references.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Every readable record and every segment of the SHIPPED bundle, as the display
# string the app draws, with Python's own reading of the bracket rule beside it.
/usr/bin/python3 - "$REPO" "$WORK/fixture.json" <<'CASES'
import json, re, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(repo / "tools"))
from citations import display_paragraphs

resources = repo / "ACIMDailyMinute" / "Resources"
load = lambda n: json.loads((resources / n).read_text(encoding="utf-8"))
BRACKET = re.compile(r"\[(\d+)\]")

def display(body):
    return "\n\n".join(display_paragraphs(body))

def refs(text):
    # Character offsets. Python str indexes code points, and the bundle holds
    # no combining sequences, so these equal Swift's Character offsets.
    return [{"start": m.start(), "end": m.end(), "lesson": int(m.group(1))}
            for m in BRACKET.finditer(text)]

records = []
for s in load("ACIMTextSections.json"):
    d = display(s["body"]); records.append({"kind": "text", "id": f"{s['chapterNumber']}.{s['sectionNumber']}", "display": d, "refs": refs(d)})
for i in load("WorkbookIntroductions.json"):
    d = display(i["body"]); records.append({"kind": "introduction", "id": str(i["lessonNumber"]), "display": d, "refs": refs(d)})
for b in load("Workbook365Bodies.json"):
    d = display(b["body"]); records.append({"kind": "lesson", "id": str(b["lessonNumber"]), "display": d, "refs": refs(d)})
for m in load("ACIMManual.json"):
    d = display(m["body"]); records.append({"kind": "manual", "id": str(m["segmentId"]), "display": d, "refs": refs(d)})
for g in load("ACIMSegments.json"):
    d = display(g["body"]); records.append({"kind": "segment", "id": str(g["segmentId"]), "source": g["sourcePDF"], "display": d, "refs": refs(d)})

out.write_text(json.dumps({"records": records}, ensure_ascii=False), encoding="utf-8")
lessons = [r for r in records if r["kind"] == "lesson" and r["refs"]]
print(f"{len(records)} records; Python sees {sum(len(r['refs']) for r in records if r['kind'] != 'segment')} "
      f"references in {len(lessons)} lessons")
CASES

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

struct Ref: Decodable { let start: Int; let end: Int; let lesson: Int }
struct Record: Decodable { let kind: String; let id: String; let source: String?; let display: String; let refs: [Ref] }
struct Fixture: Decodable { let records: [Record] }

let fixture = try JSONDecoder().decode(
    Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
)

var failures: [String] = []
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

// The review lessons, and nothing else, revisit earlier lessons by number.
let reviewRanges: [ClosedRange<Int>] = [51...60, 81...90, 111...120, 141...150, 171...180, 201...220]
let reviewLessons: Set<Int> = reviewRanges.reduce(into: Set<Int>()) { $0.formUnion($1) }

var total = 0
var hosts = Set<Int>()
for record in fixture.records {
    let found = CrossReference.lessonReferences(in: record.display)
    let chars = Array(record.display)

    // 1. Swift finds exactly what Python finds, range for range.
    check(found.count == record.refs.count,
          "\(record.kind) \(record.id): Swift found \(found.count), Python \(record.refs.count)")
    for (got, want) in zip(found, record.refs) {
        check(got.range == want.start..<want.end && got.lesson == want.lesson,
              "\(record.kind) \(record.id): \(got) vs Python \(want.start)..<\(want.end) lesson \(want.lesson)")
        // 2. The substring at the range is the bracketed number itself.
        check(String(chars[got.range]) == "[\(got.lesson)]",
              "\(record.kind) \(record.id): range holds \(String(chars[got.range]).debugDescription)")
        check(CrossReference.lessonRange.contains(got.lesson), "\(record.kind) \(record.id): lesson \(got.lesson) out of range")
    }
    // 3. Ascending, non-overlapping.
    for pair in zip(found, found.dropFirst()) {
        check(pair.0.range.upperBound <= pair.1.range.lowerBound, "\(record.kind) \(record.id): references overlap or are out of order")
    }

    switch record.kind {
    case "lesson":
        let host = Int(record.id)!
        if !found.isEmpty {
            total += found.count
            hosts.insert(host)
            check(reviewLessons.contains(host), "Lesson \(host) is not a review lesson but carries a reference")
            for ref in found {
                check(ref.lesson < host, "Lesson \(host) refers forward to \(ref.lesson)")
            }
        }
    case "text", "introduction", "manual":
        // 4. Nothing outside the Workbook carries one.
        check(found.isEmpty, "\(record.kind) \(record.id) carries a bracketed number")
    case "segment":
        // 5. A segment carries one only when it was cut from the Workbook.
        if !found.isEmpty {
            check(record.source?.lowercased().contains("workbook") == true,
                  "segment \(record.id) from \(record.source ?? "?") carries a bracketed number")
        }
    default:
        check(false, "unknown record kind \(record.kind)")
    }
}
check(total == 150, "readable corpus carries \(total) references, want 150")
check(hosts.count == 70, "\(hosts.count) host lessons, want 70")
check(hosts == reviewLessons, "the host lessons are not exactly the 70 review lessons")

// 6. What is refused: zero, past the Workbook, letters, the reader's blanks,
//    a bare number, and a bracket that never closes.
for bad in ["[0]", "[366]", "[1000]", "[name of person]", "[specify]", "[]", "[ 5 ]", "5", "[5", "5]", "[-5]", "[5.1]"] {
    check(CrossReference.lessonReferences(in: "before \(bad) after").isEmpty, "matched what it must refuse: \(bad)")
}
// 7. What is accepted, including at the very edges and back to back.
check(CrossReference.lessonReferences(in: "[1]").first?.range == 0..<3, "[1] alone is 0..<3")
check(CrossReference.lessonReferences(in: "[365]").first?.lesson == 365, "[365] is the last lesson")
check(CrossReference.lessonReferences(in: "[1][2]").map(\.lesson) == [1, 2], "back-to-back references")
check(CrossReference.lessonReferences(in: "é[7]").first?.range == 1..<4, "offsets are Character offsets, not UTF-8 or UTF-16")
check(CrossReference.lessonReferences(in: "🕊 [7]").first?.range == 2..<5, "an emoji is one Character")
// A complete reference followed by a stray opening bracket is still that
// reference: "[5][" is "[5]" plus an unclosed "[", not an unclosed bracket.
// Python's own \[(\d+)\] reads it the same way, and the two must not differ.
check(CrossReference.lessonReferences(in: "before [5][ after").map(\.lesson) == [5],
      "[5][ holds the reference [5]")

// 8. The link round-trips every lesson and refuses everything else.
for n in CrossReference.lessonRange {
    let url = CrossReference.url(forLesson: n)
    check(url.absoluteString == "reading:lesson/\(n)", "url for \(n) is \(url.absoluteString)")
    check(CrossReference.lesson(from: url) == n, "url for \(n) decodes to \(String(describing: CrossReference.lesson(from: url)))")
}
for bad in ["reading:lesson/0", "reading:lesson/366", "reading:text/1", "reading:lesson/", "reading:lesson/abc",
            "https://www.acimdailyminute.org/lesson/5", "acimdailyminute://lesson/5", "lesson/5"] {
    if let url = URL(string: bad) {
        check(CrossReference.lesson(from: url) == nil, "decoded what it must refuse: \(bad)")
    }
}

if failures.isEmpty {
    print("\(checks) checks over \(fixture.records.count) records: \(total) references in \(hosts.count) review lessons, none anywhere else")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

# A lone-file swiftc happily links SwiftUI, SwiftData and Foundation's Bundle,
# so the compile alone cannot see this drift; the grep can.
#
# Comments are stripped first. What must stay out of this file is a DEPENDENCY,
# and prose creates none — the doc comment names CorpusService and ReadingKey
# precisely to say it does not use them, and that sentence is worth keeping.
if sed 's://.*::' "$REPO/ACIMDailyMinute/Utilities/CrossReference.swift" \
    | grep -qE '^[[:space:]]*import[[:space:]]+(SwiftUI|SwiftData)|Bundle\.|CorpusService|ReadingKey'; then
    echo "FAIL: CrossReference.swift imports a UI or storage framework, or names Bundle, CorpusService or ReadingKey"
    exit 1
fi

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/CrossReference.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify" "$WORK/fixture.json"
