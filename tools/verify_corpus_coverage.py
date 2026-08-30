#!/usr/bin/env python3
"""The sixth committed check: nothing is MISSING from the readable corpus.

Run after any change to a bundled file, beside text_paragraphs.py,
punctuation_spacing.py, verify_spacing_agreement.sh, verify_citations.py and
verify_citation_agreement.sh.

    python3 tools/verify_corpus_coverage.py

⛔ Why this exists. The other five checks all ask whether what IS in the bundle
is well formed -- display form, no furniture, no run-together sentences, real
citations. None of them can see an absence. About 12,000 characters of the Text
were missing for months: the extractor cut each chapter at its first section
heading and dropped the opening prose glued to the wrapped chapter title, and
every check passed the whole time. A reader searching for `How simple is
salvation!` -- the line that opens Chapter 31 -- would have found nothing and
concluded the phrase was not in the book.

The segments are a continuous cut of the same PDFs, so they are the witness:
anything present there and absent from the readable corpus is missing text.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from chapter_openings import MIN_GAP, WINDOW, display_form, gaps

RESOURCES = Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"

# Measured against the shipping bundle.
EXPECTED_SECTIONS = 272
EXPECTED_SEGMENTS = 1983

# ⛔ Every entry here is a deliberate exclusion with a reason, not a tolerance.
# An empty list is the goal; a gap that appears without a reason is a defect.
ALLOWED_GAPS = []


def load(name):
    return json.loads((RESOURCES / name).read_text(encoding="utf-8"))


def main():
    sections = load("ACIMTextSections.json")
    segments = load("ACIMSegments.json")
    failed = False

    if len(sections) != EXPECTED_SECTIONS:
        print(f"  FAIL: {len(sections)} sections, expected {EXPECTED_SECTIONS}")
        failed = True
    if len(segments) != EXPECTED_SEGMENTS:
        print(f"  FAIL: {len(segments)} segments, expected {EXPECTED_SEGMENTS}")
        failed = True

    # 1. The Text: every run of the segment stream must be somewhere in the
    #    268-plus-recovered sections a reader can actually open.
    text_gaps = gaps(sections, segments, family="Text")
    print(f"Text: {len(text_gaps)} gaps of {MIN_GAP}+ characters "
          f"({WINDOW}-character windows)")
    for gap in text_gaps:
        flat = " ".join(gap["text"].split())
        if flat[:60] in ALLOWED_GAPS:
            continue
        print(f"  FAIL: {gap['normalized_length']} characters missing "
              f"before section {gap['follows']}: {flat[:90]!r}")
        failed = True

    # 2. The Workbook, read through the same lens. Its bodies are curated
    #    separately, so a gap here would mean a different fault with the same
    #    consequence: words a reader cannot reach.
    lessons = [
        {"chapterNumber": row["lessonNumber"], "chapterTitle": "",
         "sectionNumber": 1, "sectionTitle": "",
         "body": row["body"]}
        for row in load("Workbook365Bodies.json") + load("WorkbookIntroductions.json")
    ]
    workbook_gaps = gaps(lessons, segments, family="Workbook")
    print(f"Workbook: {len(workbook_gaps)} gaps of {MIN_GAP}+ characters")
    for gap in workbook_gaps:
        flat = " ".join(gap["text"].split())
        if flat[:60] in ALLOWED_GAPS:
            continue
        print(f"  FAIL: {gap['normalized_length']} characters missing: {flat[:90]!r}")
        failed = True

    # 3. The Manual is bundled as the same 105 rows the segments carry, so it is
    #    covered by construction. Assert that rather than assume it.
    manual_bodies = {display_form(row["body"]) for row in load("ACIMManual.json")}
    manual_segments = [row for row in segments if row["sourcePDF"] == "Manual"]
    orphaned = [
        row["segmentId"] for row in manual_segments
        if display_form(row["body"]) not in manual_bodies
    ]
    print(f"Manual: {len(manual_segments)} segments, {len(orphaned)} not in the bundle")
    if orphaned:
        print(f"  FAIL: Manual segments missing from ACIMManual.json: {orphaned[:10]}")
        failed = True

    print("FAIL" if failed else "OK")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
