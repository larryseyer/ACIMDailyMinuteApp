#!/bin/bash
# Proves the citation display rule over the whole shipped bundle: replace every
# `-` and every `.` with `·`, lose no field, gain no field, never invent W·r2·84.
#
#   ./tools/verify_citation_render.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

/usr/bin/python3 - "$REPO" "$WORK/fixture.json" <<'PY'
import json, sys
from pathlib import Path
from collections import Counter

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
resources = repo / "ACIMDailyMinute" / "Resources"
segments = json.loads((resources / "ACIMSegments.json").read_text(encoding="utf-8"))
intros = json.loads((resources / "WorkbookIntroductions.json").read_text(encoding="utf-8"))

def shape(raw):
    if raw is None:
        return "null"
    if raw.startswith("T-"):
        return "T-N.N.N"
    if raw.startswith("Pref."):
        return "Pref.N"
    if raw.startswith("W-pII.in."):
        return "W-pII.in.N"
    if raw.startswith("W-pI.in."):
        return "W-pI.in.N"
    if raw.startswith("W-r") and ".in." in raw:
        return "W-rN.in.N"
    if raw.startswith("W-w") and ".in." in raw:
        return "W-wN.in.N"
    if raw.startswith("W-"):
        return "W-N.N"
    if raw.startswith("M-in."):
        return "M-in.N"
    if raw.startswith("M-"):
        return "M-N.N"
    return "other"

rows = []
nulls = 0
for s in segments:
    c = s.get("citation")
    if c is None:
        nulls += 1
        rows.append({"kind": "segment", "id": str(s["segmentId"]), "raw": None, "shape": "null"})
    else:
        rows.append({"kind": "segment", "id": str(s["segmentId"]), "raw": c, "shape": shape(c)})
stems = []
for i in intros:
    stems.append(i["citationStem"])

out.write_text(json.dumps({"rows": rows, "stems": stems, "nulls": nulls}, ensure_ascii=False), encoding="utf-8")
print(f"{len(rows)} segments ({nulls} null); {len(stems)} introduction stems")
PY

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

struct Row: Decodable { let kind: String; let id: String; let raw: String?; let shape: String }
struct Fixture: Decodable { let rows: [Row]; let stems: [String]; let nulls: Int }

let fixture = try JSONDecoder().decode(
    Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
)

var failures: [String] = []
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

func fields(_ s: String, separators: Character...) -> [String] {
    let set = Set(separators)
    return s.split(whereSeparator: { set.contains($0) }).map(String.init)
}

var shapes = Set<String>()
var nonNull = 0
for row in fixture.rows {
    if let raw = row.raw {
        nonNull += 1
        shapes.insert(row.shape)
        let displayed = CitationRender.displayString(raw)
        check(fields(raw, separators: "-", ".") == fields(displayed, separators: "·"),
              "\(row.id) \(raw) -> \(displayed) lost or gained a field")
        check(!displayed.contains("-") && !displayed.contains("."),
              "\(row.id) still has a hyphen or dot: \(displayed)")
        check(Citation(rawValue: raw) != nil, "\(row.id) \(raw) no longer parses")
    } else {
        check(row.shape == "null", "\(row.id) expected null citation")
    }
}

check(fixture.nulls == 3, "expected 3 null citations, got \(fixture.nulls)")
check(nonNull == 1980, "expected 1980 non-null citations, got \(nonNull)")
check(shapes.count == 9, "expected 9 shapes, got \(shapes.count): \(shapes.sorted())")

let lesson84 = CitationRender.displayString("W-84")
check(lesson84 == "W·84", "Lesson 84 stem renders \(lesson84.debugDescription), not W·84")
check(!lesson84.contains("r2"), "Lesson 84 must never contain r2")
check(CitationRender.displayString("W-84.1") == "W·84·1", "W-84.1")

check(fixture.stems.count == 22, "expected 22 introduction stems, got \(fixture.stems.count)")
for stem in fixture.stems {
    let displayed = CitationRender.displayString(stem)
    check(fields(stem, separators: "-", ".") == fields(displayed, separators: "·"),
          "stem \(stem) -> \(displayed)")
}
check(CitationRender.displayString("W-r2.in") == "W·r2·in", "Review II introduction stem")
check(CitationRender.displayString("W-pI.in") == "W·pI·in", "Part I introduction stem")
check(CitationRender.displayString("W-w1.in") == "W·w1·in", "What Is 1 stem")

if failures.isEmpty {
    print("\(checks) checks over \(fixture.rows.count) segments and \(fixture.stems.count) stems")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

MAC_SDK="$(xcrun --sdk macosx --show-sdk-path)"
swiftc -O -sdk "$MAC_SDK" -target arm64-apple-macos14.0 \
    "$REPO/ACIMDailyMinute/Utilities/Citation.swift" \
    "$REPO/ACIMDailyMinute/Views/CitationLabel.swift" \
    "$REPO/ACIMDailyMinute/Views/ACIMColors.swift" \
    "$REPO/ACIMDailyMinute/Utilities/ACIMType.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify" "$WORK/fixture.json"
