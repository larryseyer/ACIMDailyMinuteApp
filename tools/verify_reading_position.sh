#!/bin/bash
# Proves a reader's PLACE in a book survives everything that can happen to the
# text under it.
#
# What this guards is a ribbon that lies. A stored offset alone cannot survive a
# corpus repair — the punctuation-spacing repair moved 6,221 of them — so the
# place is kept as words and found again the way a highlight is. Get that wrong
# and nothing looks like a bug: the reading opens, the reader is simply
# somewhere else in it, and they have no way to tell whether they misremembered.
#
# It also guards the two silent ways a ribbon can be worse than none. A Daily
# Minute or a Manual cut must never set one — a minute is a day the server
# chose, and the Manual has no structure to resume into — and two devices
# merging must never move a book's ribbon backwards in time.
#
# ⛔ The compile line names FOUR source files and no others. That is half the
# check: the rule must stay free of SwiftUI, SwiftData, Bundle, UserDefaults and
# CorpusService, or a reader's place could only be exercised by launching the
# app.
#
#   ./tools/verify_reading_position.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SRC="$REPO/ACIMDailyMinute"
FILES=(
  "$SRC/Utilities/ReadingPosition.swift"
  "$SRC/Utilities/ReadingKey.swift"
  "$SRC/Services/AnchorResolver.swift"
  "$SRC/Utilities/PunctuationSpacing.swift"
)

# A lone-file `swiftc` links SwiftUI and SwiftData without complaint if the file
# imports them, so the compile alone cannot prove the boundary. Comments are
# stripped first: what must stay out of these files is a DEPENDENCY, and the doc
# comments name several of these very types precisely to say they are not used.
for file in "${FILES[@]}"; do
  stripped="$(sed -e 's://.*::' "$file")"
  for banned in SwiftUI SwiftData CorpusService UserDefaults Bundle; do
    if grep -q "$banned" <<<"$stripped"; then
      echo "FAIL: $(basename "$file") reaches $banned — a reader's place must not depend on it" >&2
      exit 1
    fi
  done
done

# Every readable record of the SHIPPED bundle, as the display string the app
# draws, with every paragraph start in it as a place a reader could stop.
/usr/bin/python3 - "$REPO" "$WORK/fixture.json" <<'CASES'
import json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(repo / "tools"))
from citations import display_paragraphs

resources = repo / "ACIMDailyMinute" / "Resources"
load = lambda n: json.loads((resources / n).read_text(encoding="utf-8"))

def display(body):
    return "\n\n".join(display_paragraphs(body))

def starts(text):
    """Every paragraph start — where a reader who stopped between paragraphs is."""
    found, i = [0], text.find("\n\n")
    while i != -1:
        j = i + 2
        while j < len(text) and text[j] == "\n":
            j += 1
        found.append(j)
        i = text.find("\n\n", j)
    return [s for s in found if s < len(text)]

records = []
for s in load("ACIMTextSections.json"):
    d = display(s["body"])
    records.append({"key": f"text:{s['chapterNumber']}.{s['sectionNumber']}",
                    "display": d, "starts": starts(d)})
for i in load("WorkbookIntroductions.json"):
    d = display(i["body"])
    records.append({"key": f"lesson:{i['lessonNumber']}", "display": d, "starts": starts(d)})
for b in load("Workbook365Bodies.json"):
    d = display(b["body"])
    records.append({"key": f"lesson:{b['lessonNumber']}", "display": d, "starts": starts(d)})

out.write_text(json.dumps({"records": records}, ensure_ascii=False), encoding="utf-8")
print(f"{len(records)} readable records, {sum(len(r['starts']) for r in records)} places to stop in them")
CASES

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

var checks = 0
var failures: [String] = []

func check(_ condition: Bool, _ what: @autoclosure () -> String) {
    checks += 1
    if !condition, failures.count < 20 { failures.append(what()) }
}

let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

// MARK: - Which readings can hold a ribbon at all

// ⛔ A Daily Minute is a day the server chose, not a thread through a book, and
// the Manual has no structure to resume into. Neither may ever set one.
for key: ReadingKey in [.segment(1), .segment(1983), .manual(1), .manual(105), .minuteDate("2026-05-31")] {
    check(ReadingPosition.book(for: key) == nil, "\(key.rawValue) must hold no ribbon")
    check(
        ReadingPosition.make(key: key, startOffset: 0, in: "a passage", at: epoch) == nil,
        "\(key.rawValue) must refuse to make one"
    )
}
for chapter in 0...31 {
    check(ReadingPosition.book(for: .textSection(chapter: chapter, section: 1)) == .text,
          "text \(chapter).1 belongs to the Text")
}
for lesson in [0, 1, 84, 181, 365, 500] {
    check(ReadingPosition.book(for: .lesson(lesson)) == .workbook, "lesson \(lesson) belongs to the Workbook")
}

// MARK: - At rest

let sample = ReadingPosition(
    readingKey: "text:5.3", startOffset: 12, quote: "a quote", updatedAt: epoch
)
let both: [String: ReadingPosition] = [
    ReadingPosition.Book.text.rawValue: sample,
    ReadingPosition.Book.workbook.rawValue: ReadingPosition(
        readingKey: "lesson:84", startOffset: 0, quote: "another", updatedAt: epoch
    )
]
check(ReadingPosition.decode(ReadingPosition.encode(both)) == both, "a ribbon must round trip")
check(ReadingPosition.decode(Data()) == [:], "nothing stored is no ribbon")
check(ReadingPosition.decode(Data("not json at all".utf8)) == [:], "garbage is no ribbon")
check(
    ReadingPosition.decode(ReadingPosition.encode(both).prefix(20)) == [:],
    "a truncated file is no ribbon"
)
// A key no version of this app has written cannot put a ribbon somewhere
// nothing can open.
let foreign = Data(#"{"manual":{"readingKey":"manual:3","startOffset":0,"quote":"x","updatedAt":0}}"#.utf8)
check(ReadingPosition.decode(foreign) == [:], "an unknown book is no ribbon")

// One book's ribbon never displaces another's.
var shelf = both
shelf[ReadingPosition.Book.text.rawValue] = ReadingPosition(
    readingKey: "text:9.4", startOffset: 3, quote: "moved on", updatedAt: epoch
)
check(shelf[ReadingPosition.Book.workbook.rawValue] == both[ReadingPosition.Book.workbook.rawValue],
      "the Workbook's ribbon must not move when the Text's does")
check(shelf.count == 2, "a book holds one ribbon, replaced and never accumulated")

// MARK: - Two devices

let older = ReadingPosition(readingKey: "text:5.3", startOffset: 10, quote: "q", updatedAt: epoch)
let newer = ReadingPosition(
    readingKey: "text:5.4", startOffset: 20, quote: "r", updatedAt: epoch.addingTimeInterval(60)
)
let mine = [ReadingPosition.Book.text.rawValue: older]
let theirs = [ReadingPosition.Book.text.rawValue: newer]

check(ReadingPosition.merged(mine, theirs) == theirs, "the later ribbon wins")
check(ReadingPosition.merged(theirs, mine) == theirs, "and wins from either side")
check(ReadingPosition.merged(mine, mine) == mine, "the merge is idempotent")
check(ReadingPosition.merged(mine, [:]) == mine, "an empty import takes nothing away")
check(ReadingPosition.merged([:], theirs) == theirs, "a first import brings everything")

// A device re-importing its own backup finds the same ribbon, not a newer one:
// the file records milliseconds and the store keeps full precision.
let full = ReadingPosition(
    readingKey: "text:5.3", startOffset: 10, quote: "q",
    updatedAt: epoch.addingTimeInterval(0.0004)
)
check(!full.isLater(than: older) && !older.isLater(than: full),
      "a ribbon compared with its own millisecond-rounded copy is the same ribbon")

// Commutative and associative over every arrangement of three, including ties.
let tie = ReadingPosition(readingKey: "lesson:84", startOffset: 5, quote: "s", updatedAt: epoch)
let shelves: [[String: ReadingPosition]] = [
    mine, theirs, [ReadingPosition.Book.workbook.rawValue: tie],
    [ReadingPosition.Book.text.rawValue: tie], [:]
]
for a in shelves {
    for b in shelves {
        check(ReadingPosition.merged(a, b) == ReadingPosition.merged(b, a), "the merge is commutative")
        for c in shelves {
            check(
                ReadingPosition.merged(ReadingPosition.merged(a, b), c)
                    == ReadingPosition.merged(a, ReadingPosition.merged(b, c)),
                "the merge is associative"
            )
            // ⛔ An import may add to what this device knows and may never take
            // from it: no book loses a ribbon it had.
            let after = ReadingPosition.merged(a, b)
            for (book, _) in a { check(after[book] != nil, "\(book) must not lose its ribbon") }
        }
    }
}

// MARK: - Finding the place again, in the shipped bundle

struct Record: Decodable {
    let key: String
    let display: String
    let starts: [Int]
}
struct Fixture: Decodable { let records: [Record] }

let path = CommandLine.arguments[1]
let fixture = try JSONDecoder().decode(
    Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path))
)

var places = 0
var repaired = 0
for record in fixture.records {
    guard let key = ReadingKey(rawValue: record.key) else {
        failures.append("\(record.key) does not parse as a key")
        continue
    }
    let characters = Array(record.display)

    for start in record.starts {
        guard let position = ReadingPosition.make(
            key: key, startOffset: start, in: record.display, at: epoch
        ) else {
            failures.append("\(record.key) refused a position it should hold")
            continue
        }
        places += 1
        check(position.startOffset == start, "\(record.key)@\(start) keeps its offset")
        check(position.quote.count <= ReadingPosition.quoteLength, "\(record.key)@\(start) quote is bounded")
        check(
            position.quote == String(characters[start..<min(start + ReadingPosition.quoteLength, characters.count)]),
            "\(record.key)@\(start) quote is cut at the offset"
        )
        // The place is found again in the string the screen actually draws.
        check(position.offset(in: record.display) == start, "\(record.key)@\(start) resolves to itself")
    }

    // The whole point of keeping words: a position made before a repair still
    // finds its place after one. The bundle is already repaired and the rule is
    // idempotent, so the drift is staged the other way — a position whose quote
    // carries the *unrepaired* spelling must still land where it was made.
    if let start = record.starts.first(where: { $0 > 0 }),
       let position = ReadingPosition.make(
           key: key, startOffset: start, in: record.display, at: epoch
       ) {
        let damaged = ReadingPosition(
            readingKey: position.readingKey,
            startOffset: position.startOffset,
            quote: position.quote.replacingOccurrences(of: ". ", with: "."),
            updatedAt: position.updatedAt
        )
        if damaged.quote != position.quote {
            repaired += 1
            check(
                damaged.offset(in: record.display) == start,
                "\(record.key)@\(start) must survive the spacing repair"
            )
        }
    }

    // An offset past the end of a reading, and one before its start, leave the
    // reader at its top rather than throwing or landing at random.
    for wild in [-1, -1000, characters.count + 1, characters.count + 10_000] {
        guard let position = ReadingPosition.make(
            key: key, startOffset: wild, in: record.display, at: epoch
        ) else { continue }
        check(
            position.startOffset >= 0 && position.startOffset <= characters.count,
            "\(record.key) clamps a wild offset instead of storing it"
        )
        check(
            position.offset(in: record.display) >= 0,
            "\(record.key) resolves a wild offset to a real place"
        )
    }

    // Words that are simply gone open the reading at its top.
    let orphan = ReadingPosition(
        readingKey: record.key, startOffset: 5,
        quote: "a sentence that is in no edition of this book",
        updatedAt: epoch
    )
    check(orphan.offset(in: record.display) == 0, "\(record.key) opens at the top when the words are gone")
}

check(places > 3_000, "the bundle offered \(places) places to stop, which is too few to be the whole book")

if failures.isEmpty {
    print("\(fixture.records.count) readable records, \(places) places to stop, \(repaired) repaired quotes")
    print("\(checks) checks, a reader's place survives the text moving under it")
    print("OK")
} else {
    print("FAIL — \(failures.count) of \(checks) checks")
    for failure in failures { print("  \(failure)") }
    exit(1)
}
SWIFT

swiftc -O -swift-version 5 -o "$WORK/harness" "${FILES[@]}" "$WORK/main.swift"
"$WORK/harness" "$WORK/fixture.json"
