#!/bin/bash
# Proves the book's index finds the words the reader typed, at offsets that
# point at those words, in the order the book has them.
#
# What this guards is the ADDRESS of a match. A search that returns the right
# passage at the wrong offset does not crash and does not warn: the reading
# opens, the spotlight paints a different sentence, and the reader concludes
# the app cannot count. Every other check asks whether the words are right;
# this one asks whether "here" is here.
#
# ⛔ The compile line names ONE source file and no others. That is half the
# check: the search must stay free of SwiftUI, SwiftData, Bundle, CorpusService,
# ReadingKey and Citation, or it can only be exercised by launching the app.
#
#   ./tools/verify_corpus_search.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Every readable record from the SHIPPED bundle, in book order, plus probes cut
# from real passages at known offsets.
/usr/bin/python3 - "$REPO" "$WORK/fixture.json" <<'CASES'
import json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
resources = repo / "ACIMDailyMinute" / "Resources"
load = lambda n: json.loads((resources / n).read_text(encoding="utf-8"))

records = []
for s in load("ACIMTextSections.json"):
    records.append({"title": f"T-{s['chapterNumber']}.{s['sectionNumber']} {s['sectionTitle']}", "body": s["body"]})
intros = {i["lessonNumber"]: i for i in load("WorkbookIntroductions.json")}
bodies = {b["lessonNumber"]: b["body"] for b in load("Workbook365Bodies.json")}
records.append({"title": intros[0]["title"], "body": intros[0]["body"]})
for n in range(1, 181):
    records.append({"title": f"Lesson {n}", "body": bodies[n]})
records.append({"title": intros[500]["title"], "body": intros[500]["body"]})
for n in range(181, 366):
    records.append({"title": f"Lesson {n}", "body": bodies[n]})
for m in load("ACIMManual.json"):
    records.append({"title": f"Manual {m['segmentId']}", "body": m["body"]})

# Probes: a real run of words at a known character offset, from a spread of
# records, so check 7 can prove the index finds a passage where it actually is.
probes = []
for i in range(0, len(records), 37):
    body = records[i]["body"]
    if len(body) < 400:
        continue
    start = body.find(" ", 150) + 1
    end = body.find(" ", start + 40)
    if start <= 0 or end <= start:
        continue
    text = body[start:end]
    # Lesson bodies are hard-wrapped; a probe across a line break would be
    # collapsed by the query rule and never match the raw record fed here.
    if "\n" in text:
        continue
    # A paragraph-indent run of spaces can leave `start` inside the run, so
    # the probe text opens with whitespace the query rule trims away — the
    # match would then land past the recorded offset. Skip those.
    if text[0].isspace():
        continue
    probes.append({"record": i, "offset": start, "text": text})

out.write_text(json.dumps({"records": records, "probes": probes}), encoding="utf-8")
print(f"{len(records)} real records, {sum(len(r['body']) for r in records)} characters, {len(probes)} probes")
CASES

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

struct Fixture: Decodable {
    struct Record: Decodable { let title: String; let body: String }
    struct Probe: Decodable { let record: Int; let offset: Int; let text: String }
    let records: [Record]
    let probes: [Probe]
}

let data = try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let fixture = try! JSONDecoder().decode(Fixture.self, from: data)

var checks = 0
var failures: [String] = []
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

// --- 1. The fold is one Character in, one out, and idempotent ---
for (i, r) in fixture.records.enumerated() {
    let folded = SearchFold.fold(r.body)
    check(folded.count == r.body.count, "record \(i) fold changed length \(r.body.count) -> \(folded.count)")
    check(SearchFold.fold(folded) == folded, "record \(i) fold not idempotent")
}
check(SearchFold.fold("God’s “Word” — now") == "god's \"word\" - now", "fold maps typographic forms")
check(SearchFold.normalizedQuery("  God's   Word ") == "god's word", "query trims, collapses, folds")
check(SearchFold.normalizedQuery("a") == nil, "one-character query is nothing")
check(SearchFold.normalizedQuery("   ") == nil, "blank query is nothing")
check(SearchFold.normalizedQuery("") == nil, "empty query is nothing")

let started = Date()
let index = SearchIndex(records: fixture.records.enumerated().map {
    SearchRecord(id: $0.offset, title: $0.element.title, display: $0.element.body)
})
print(String(format: "index built over %d records in %.0f ms", fixture.records.count, Date().timeIntervalSince(started) * 1000))

// --- 2. Every hit's range holds the folded query, for real queries ---
let queries = ["forgiveness", "God's", "God’s", "the holy instant", "HOLY INSTANT", "special relationship", "xyzzy", "I am"]
var hitCounts: [String: Int] = [:]
for q in queries {
    let folded = SearchFold.normalizedQuery(q)!
    let results = index.search(q)
    hitCounts[q] = results.hits.count
    for hit in results.hits {
        let display = index.records[hit.record].display
        let chars = Array(display)
        check(hit.range.lowerBound >= 0 && hit.range.upperBound <= chars.count,
              "\(q): hit \(hit) out of bounds in record \(hit.record)")
        guard hit.range.upperBound <= chars.count else { continue }
        let found = SearchFold.fold(String(chars[hit.range]))
        check(found == folded, "\(q): record \(hit.record) offset \(hit.range.lowerBound) holds '\(found)'")
    }
}
check(hitCounts["forgiveness"]! > 100, "forgiveness occurs often")
check(hitCounts["God's"]! > 100, "a straight apostrophe finds the curly one")
check(hitCounts["God's"]! == hitCounts["God’s"]!, "straight and curly apostrophe agree")
check(hitCounts["HOLY INSTANT"]! == index.search("holy instant").hits.count, "case does not matter")
check(hitCounts["HOLY INSTANT"]! > 0, "the holy instant is in the book")
check(hitCounts["xyzzy"]! == 0, "a word not in the book finds nothing")

// --- 3. Hits come back in record order, then offset order, never overlapping ---
for q in ["forgiveness", "the holy instant"] {
    let hits = index.search(q).hits
    for pair in zip(hits, hits.dropFirst()) {
        let ordered = pair.0.record < pair.1.record
            || (pair.0.record == pair.1.record && pair.0.range.upperBound <= pair.1.range.lowerBound)
        check(ordered, "\(q): \(pair.0) precedes \(pair.1) out of order or overlapping")
    }
}

// --- 4. The cap holds and is reported ---
let capped = index.search("the")
check(capped.hits.count == SearchIndex.hitCap, "'the' returns exactly the cap, got \(capped.hits.count)")
check(capped.truncated, "'the' reports truncation")
check(!index.search("forgiveness").truncated, "forgiveness is under the cap and says so")
let small = index.search("the", cap: 7)
check(small.hits.count == 7 && small.truncated, "a smaller cap holds too")

// --- 5. A short or blank query returns nothing ---
for q in ["", " ", "a", "  \n "] {
    let r = index.search(q)
    check(r.hits.isEmpty && !r.truncated, "'\(q)' returned \(r.hits.count) hits")
}

// --- 6. Snippets begin and end on a word boundary or an edge, and carry the hit ---
var snippetsChecked = 0
for q in ["forgiveness", "the holy instant", "I am"] {
    for hit in index.search(q).hits.prefix(150) {
        let s = index.snippet(for: hit)
        let display = index.records[hit.record].display
        let joined = s.before.replacingOccurrences(of: "…", with: "") + s.match + s.after.replacingOccurrences(of: "…", with: "")
        check(display.contains(joined), "snippet is not a substring: '\(joined)'")
        check(SearchFold.fold(s.match) == SearchFold.normalizedQuery(q)!, "snippet match is the query")
        let chars = Array(display)
        let beforeBody = s.before.hasPrefix("…") ? String(s.before.dropFirst()) : s.before
        let afterBody = s.after.hasSuffix("…") ? String(s.after.dropLast()) : s.after
        let start = hit.range.lowerBound - beforeBody.count
        let end = hit.range.upperBound + afterBody.count
        if s.before.hasPrefix("…") {
            // Cut: the character before the snippet is whitespace and the snippet opens on a word.
            check(start > 0 && chars[start - 1].isWhitespace && !chars[start].isWhitespace,
                  "snippet before starts mid-word at \(start) in record \(hit.record)")
        } else {
            check(start == 0, "no leading ellipsis but the snippet starts at \(start)")
        }
        if s.after.hasSuffix("…") {
            check(end < chars.count && chars[end].isWhitespace && !chars[end - 1].isWhitespace,
                  "snippet after ends mid-word at \(end) in record \(hit.record)")
        } else {
            check(end == chars.count, "no trailing ellipsis but the snippet ends at \(end) of \(chars.count)")
        }
        snippetsChecked += 1
    }
}

// --- 7. A passage cut from a record at a known offset is found there ---
for p in fixture.probes {
    let hits = index.search(p.text).hits
    check(hits.contains { $0.record == p.record && $0.range.lowerBound == p.offset },
          "probe in record \(p.record) at \(p.offset) not found: '\(p.text.prefix(30))'")
}

// --- 8. shouldStop abandons the scan ---
var calls = 0
let stopped = index.search("the", shouldStop: { calls += 1; return calls > 3 })
check(stopped.hits.count < SearchIndex.hitCap, "a stopped scan returns fewer than the cap")

if failures.isEmpty {
    print("\(checks) checks over \(fixture.records.count) records and \(snippetsChecked) snippets, every match is where it says it is")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

# A lone-file swiftc happily links SwiftUI, SwiftData and Foundation's Bundle,
# so the compile alone cannot see this drift; the grep can.
if grep -qE '^[[:space:]]*import[[:space:]]+(SwiftUI|SwiftData)|Bundle\.' "$REPO/ACIMDailyMinute/Services/CorpusSearch.swift"; then
    echo "FAIL: CorpusSearch.swift imports a UI or storage framework, or touches Bundle"
    exit 1
fi

swiftc -O \
    "$REPO/ACIMDailyMinute/Services/CorpusSearch.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify" "$WORK/fixture.json"
