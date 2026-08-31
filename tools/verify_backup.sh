#!/bin/bash
# Proves the backup file round trips and that merging one into a device never
# takes a reader's words away.
#
# A reader's highlights and notes have no upstream: there is no server and no
# account, so nothing anywhere can re-send them what they wrote. A merge bug
# here does not crash and does not warn — it is discovered years later by
# someone looking for something they know they wrote down.
#
# ⛔ The compile line names TWO source files and no others. That is half the
# check: the format and the merge must stay free of SwiftData, SwiftUI, Bundle
# and CorpusService, or the file a reader keeps starts depending on the app it
# is meant to outlive.
#
#   ./tools/verify_backup.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The cases below are cut from the SHIPPED corpus, not typed here. A quote a
# reader marks is real ACIM prose - em dashes, curly apostrophes, the 6,221
# spaces the punctuation repair restored - and a format that mangles one
# character of it has silently altered what someone marked. Invented test
# strings would never have contained any of that.
/usr/bin/python3 - "$REPO" "$WORK/real.json" <<'CASES'
import json, sys
from pathlib import Path

repo, out = Path(sys.argv[1]), Path(sys.argv[2])
resources = repo / "ACIMDailyMinute" / "Resources"

def load(name):
    return json.loads((resources / name).read_text(encoding="utf-8"))

cases = []

def take(body, reading_key, wanted):
    """A run of real words from a real body, at a real offset."""
    if len(body) < 80:
        return
    # Offsets are Character counts into the display string, and these bundled
    # bodies ARE display form - the property text_paragraphs.py holds.
    start = min(wanted, len(body) - 60)
    length = min(60, len(body) - start)
    if start < 0 or length <= 0:
        return
    cases.append({
        "readingKey": reading_key,
        "quote": body[start:start + length],
        "startOffset": start,
        "length": length,
    })

for row in load("ACIMTextSections.json")[::7]:
    key = "text:%d.%d" % (row["chapterNumber"], row["sectionNumber"])
    for offset in (0, 137, 1021):
        take(row["body"], key, offset)

for row in load("Workbook365Bodies.json")[::11]:
    take(row["body"], "lesson:%d" % row["lessonNumber"], 61)

for row in load("ACIMSegments.json")[::29]:
    take(row["body"], "segment:%d" % row["segmentId"], 12)

for row in load("ACIMManual.json")[::9]:
    take(row["body"], "manual:%d" % row["segmentId"], 40)

out.write_text(json.dumps(cases, ensure_ascii=False), encoding="utf-8")
print("%d highlights cut from the shipped corpus" % len(cases))
CASES

swiftc -O \
    "$REPO/tools/verify_backup/main.swift" \
    "$REPO/ACIMDailyMinute/Services/BackupDocument.swift" \
    "$REPO/ACIMDailyMinute/Services/BackupMerge.swift" \
    -o "$WORK/verify"

"$WORK/verify" "$WORK/real.json"
