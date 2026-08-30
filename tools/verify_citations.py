#!/usr/bin/env python3
"""The fourth committed check: every citation in the bundle is real.

Run after any change to a bundled file, beside text_paragraphs.py,
punctuation_spacing.py and verify_spacing_agreement.sh.

    python3 tools/verify_citations.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from citations import (addressable_paragraphs, display_paragraphs, locate,
                       lesson_citation, text_citation)

RESOURCES = Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"

# Measured against the shipping bundle. These are assertions, not estimates: a
# change in any of them means the corpus moved under the citations.
EXPECTED_CITED = {"Text": 1256, "Workbook": 609}
EXPECTED_UNRESOLVED = 13
EXPECTED_MANUAL = 105
# Two minutes may begin in the same paragraph when one long paragraph is cut
# into several. Pinned rather than tolerated: a change here means the locator
# moved, and nothing else in the suite would say so.
EXPECTED_SHARED_CITATIONS = 166
EXPECTED_TEXT_PARAGRAPHS = 2911
EXPECTED_LESSON_PARAGRAPHS = 653


def load(name):
    return json.loads((RESOURCES / name).read_text(encoding="utf-8"))


def main():
    sections = load("ACIMTextSections.json")
    lessons = load("Workbook365Bodies.json")
    introductions = load("WorkbookIntroductions.json")
    segments = load("ACIMSegments.json")
    failed = False

    # 1. Every addressable paragraph produces a citation that parses back.
    index = addressable_paragraphs(sections, lessons, introductions)
    text_paragraphs = sum(len(display_paragraphs(s["body"])) for s in sections)
    lesson_paragraphs = sum(len(display_paragraphs(r["body"])) for r in lessons)
    print(f"Text paragraphs: {text_paragraphs}, lesson paragraphs: {lesson_paragraphs}")
    if text_paragraphs != EXPECTED_TEXT_PARAGRAPHS:
        print(f"  FAIL: expected {EXPECTED_TEXT_PARAGRAPHS} Text paragraphs")
        failed = True
    if lesson_paragraphs != EXPECTED_LESSON_PARAGRAPHS:
        print(f"  FAIL: expected {EXPECTED_LESSON_PARAGRAPHS} lesson paragraphs")
        failed = True

    # 2. Every stored segment citation points at a paragraph that exists, and is
    #    the citation the locator produces today. A stored citation that has
    #    drifted from the corpus is exactly the failure this check exists for.
    valid = set()
    for family in index.values():
        valid.update(family[1])

    cited = {"Text": 0, "Workbook": 0}
    unresolved = 0
    manual = 0
    mismatched = 0
    for segment in segments:
        family = "Text" if segment["sourcePDF"].startswith("Text") else segment["sourcePDF"]
        stored = segment.get("citation")
        if family == "Manual":
            manual += 1
            if stored is not None:
                print(f"  FAIL: Manual segment {segment['segmentId']} carries a citation")
                failed = True
            continue
        derived = locate(segment["body"], index[family])
        if stored != derived:
            mismatched += 1
            if mismatched <= 5:
                print(f"  FAIL: segment {segment['segmentId']} stored {stored!r}, derives {derived!r}")
        if stored is None:
            unresolved += 1
        elif stored not in valid:
            print(f"  FAIL: segment {segment['segmentId']} cites {stored!r}, which is not a paragraph")
            failed = True
        else:
            cited[family] += 1

    print(f"segments: {len(segments)} total, {cited['Text']} Text cited, "
          f"{cited['Workbook']} Workbook cited, {unresolved} unresolved, "
          f"{manual} Manual by design")
    if mismatched:
        failed = True
    if cited != EXPECTED_CITED:
        print(f"  FAIL: expected {EXPECTED_CITED}")
        failed = True
    if unresolved != EXPECTED_UNRESOLVED:
        print(f"  FAIL: expected {EXPECTED_UNRESOLVED} unresolved")
        failed = True
    if manual != EXPECTED_MANUAL:
        print(f"  FAIL: expected {EXPECTED_MANUAL} Manual segments")
        failed = True

    # 3. No passage may resolve two ways. The locator refuses an ambiguous probe
    #    outright, so a non-None citation IS the uniqueness proof -- this asserts
    #    the two families never collide on a stored citation.
    by_citation = {}
    for segment in segments:
        stored = segment.get("citation")
        if stored:
            by_citation.setdefault(stored, []).append(segment["segmentId"])
    shared = {c: ids for c, ids in by_citation.items() if len(ids) > 1}
    # Two segments legitimately share a START paragraph -- a long paragraph is
    # cut into several minutes -- so the assertion is not "zero". It is that the
    # collisions stay where they are: a jump means the locator started matching
    # different passages to the same place, which no other check would show.
    if len(shared) != EXPECTED_SHARED_CITATIONS:
        print(f"  FAIL: {len(shared)} citations shared by more than one segment, "
              f"expected {EXPECTED_SHARED_CITATIONS}")
        failed = True
    else:
        print(f"citations shared by more than one segment: {len(shared)} (expected)")

    print("FAIL" if failed else "OK")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
