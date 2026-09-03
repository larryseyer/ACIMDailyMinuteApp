#!/bin/bash
# Proves a word count becomes a phrase a reader can act on, over the whole
# shipped bundle.
#
# What this guards is a number that is confidently wrong. "about 0 min" under a
# 22-word lesson, or "about 2 min" under a card that calls itself the DAILY
# MINUTE, is not a crash and not a blank — it is a sentence the app states and
# the reader believes. Half the Workbook is under one minute, so the floor is
# not an edge case; it is the common case.
#
# It also pins the COUNT, not just the phrase. Every bundled body is paragraphs
# joined by "\n\n", so a rule that split on spaces alone would read
# "end.\n\nBegin" as one word and undercount a long section by its paragraph
# count — a length that is simply wrong, with nothing on screen to reveal it.
#
# ⛔ The compile line names ONE source file and no others. The rule must stay
# free of SwiftUI, SwiftData, Bundle, CorpusService and ReadingKey, or it can
# only be exercised by launching the app.
#
#   ./tools/verify_reading_time.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Every readable record of the SHIPPED bundle, with Python's own word count.
/usr/bin/python3 - "$REPO" "$WORK/fixture.json" <<'CASES'
import json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
resources = repo / "ACIMDailyMinute" / "Resources"
load = lambda n: json.loads((resources / n).read_text(encoding="utf-8"))

records = []
def add(kind, ident, body):
    # Python's str.split() splits on ALL whitespace. Swift's wordCount(of:) must
    # agree with it, or the app states a length the fixture never checked.
    records.append({"kind": kind, "id": str(ident), "words": len(body.split()),
                    "body": body})

for s in load("ACIMTextSections.json"):
    add("text", f"{s['chapterNumber']}.{s['sectionNumber']}", s["body"])
for b in load("Workbook365Bodies.json"):
    add("lesson", b["lessonNumber"], b["body"])
for i in load("WorkbookIntroductions.json"):
    add("introduction", i["lessonNumber"], i["body"])
for m in load("ACIMManual.json"):
    add("manual", m["segmentId"], m["body"])
for g in load("ACIMSegments.json"):
    add("segment", g["segmentId"], g["body"])

out.write_text(json.dumps({"records": records}, ensure_ascii=False), encoding="utf-8")
segs = [r["words"] for r in records if r["kind"] == "segment"]
print(f"{len(records)} records; the Daily Minute's pool is {min(segs)}-{max(segs)} words")
CASES

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

struct Record: Decodable { let kind: String; let id: String; let words: Int; let body: String }
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

// 1. Nothing to measure yields nothing at all, never a zero.
check(ReadingTime.describe(wordCount: 0) == nil, "0 words must be nil")
check(ReadingTime.describe(wordCount: -5) == nil, "a negative count must be nil")

// 2. The boundary is exactly one minute's worth of words.
check(ReadingTime.describe(wordCount: 199) == "less than a minute", "199 words")
check(ReadingTime.describe(wordCount: 200) == "about 1 min", "200 words")
check(ReadingTime.describe(wordCount: 1) == "less than a minute", "1 word")

// 3. Rounds to nearest, and says "min" whatever the number.
check(ReadingTime.describe(wordCount: 300) == "about 2 min", "300 words rounds up")
check(ReadingTime.describe(wordCount: 299) == "about 1 min", "299 words rounds down")
check(ReadingTime.describe(wordCount: 5839) == "about 29 min", "the longest Text section")

// 4. The count itself, over paragraphs joined by "\n\n" — the shape every
//    bundled body actually has.
check(ReadingTime.wordCount(of: "one two") == 2, "a plain pair of words")
check(ReadingTime.wordCount(of: "end.\n\nBegin again") == 3, "a paragraph break is not part of a word")
check(ReadingTime.wordCount(of: "") == 0, "an empty body is no words")

// 5. Over the whole bundle: the count agrees with Python's, and the phrase is
//    never a zero, never blank, and always one of the two shapes.
var longestMinute = 0
for record in fixture.records {
    check(ReadingTime.wordCount(of: record.body) == record.words,
          "\(record.kind) \(record.id): Swift counts \(ReadingTime.wordCount(of: record.body)) words, Python \(record.words)")
    guard let phrase = ReadingTime.describe(wordCount: record.words) else {
        check(record.words <= 0, "\(record.kind) \(record.id): \(record.words) words yielded nil")
        continue
    }
    check(phrase != "about 0 min", "\(record.kind) \(record.id): \(record.words) words reads 'about 0 min'")
    check(phrase == "less than a minute" || phrase.hasPrefix("about "),
          "\(record.kind) \(record.id): unexpected phrase \(phrase.debugDescription)")
    if record.kind == "segment" { longestMinute = max(longestMinute, record.words) }
}

// 6. ⛔ A Daily Minute is cut to a word budget, so its phrase must never
//    contradict the name on the card above it.
if let phrase = ReadingTime.describe(wordCount: longestMinute) {
    check(phrase == "about 1 min" || phrase == "about 2 min",
          "the longest Daily Minute (\(longestMinute) words) reads \(phrase.debugDescription)")
}

if failures.isEmpty {
    print("\(checks) checks over \(fixture.records.count) records, no reading reads 'about 0 min'")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

# Comments are stripped first: what must stay out of this file is a DEPENDENCY,
# and prose creates none.
if sed 's://.*::' "$REPO/ACIMDailyMinute/Utilities/ReadingTime.swift" \
    | grep -qE '^[[:space:]]*import[[:space:]]+(SwiftUI|SwiftData)|Bundle\.|CorpusService|ReadingKey'; then
    echo "FAIL: ReadingTime.swift imports a UI or storage framework, or names Bundle, CorpusService or ReadingKey"
    exit 1
fi

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/ReadingTime.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify" "$WORK/fixture.json"
