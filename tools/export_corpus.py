#!/usr/bin/env python3
"""Export the ACIM corpus from the pipeline database into app bundle resources.

Re-runnable. Reads only; never writes to the source database.
"""
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from text_paragraphs import display_body, running_head_keys

DB = Path("/Volumes/MacLive/Users/larryseyer/acim-daily-minute/data/acim.db")
OUT = Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"

EXPECTED = {
    "Workbook365Bodies.json": 365,
    "ACIMTextSections.json": 268,
    "ACIMManual.json": 105,
    "ACIMSegments.json": 1983,
    "WorkbookIntroductions.json": 2,
}


def write(name, rows):
    path = OUT / name
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    expected = EXPECTED[name]
    if len(rows) != expected:
        sys.exit(f"FAIL {name}: exported {len(rows)}, expected {expected}")
    print(f"  {name}: {len(rows)} records, {path.stat().st_size / 1048576:.2f} MB")


def main():
    if not DB.exists():
        sys.exit(f"FAIL: {DB} not reachable. Is the MacLive share mounted?")
    conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)

    # Workbook bodies 1-365. Ids 0 and 500 are the two Part Introductions and
    # belong to Spec 2, which handles Workbook content outside the 1-365 spine.
    write("Workbook365Bodies.json", [
        {"lessonNumber": r[0], "body": r[1]}
        for r in conn.execute(
            "SELECT id, text FROM lessons "
            "WHERE id BETWEEN 1 AND 365 AND text IS NOT NULL AND length(trim(text)) > 0 "
            "ORDER BY id"
        )
    ])

    # The Text is the only corpus without a curated `text_paragraphs` column,
    # so its paragraph structure is recovered here rather than in the app.
    # Emitting display form keeps ReadingText.displayString a no-op over it,
    # which is what stops a highlight offset and the screen from drifting.
    raw_sections = [
        {"chapterNumber": r[0], "chapterTitle": r[1],
         "sectionNumber": r[2], "sectionTitle": r[3], "body": r[4]}
        for r in conn.execute(
            "SELECT chapter_num, chapter_title, section_num, section_title, text "
            "FROM text_sections ORDER BY chapter_num, section_num"
        )
    ]
    heads = running_head_keys(raw_sections)
    for row in raw_sections:
        row["body"] = display_body(row["body"], heads)
    write("ACIMTextSections.json", raw_sections)

    # Lesson ids 0 and 500 are the two Part Introductions. They sit outside the
    # 1-365 spine, which is why Workbook365Bodies.json cannot hold them and why
    # they had nowhere to appear until the Read tab gave them one.
    write("WorkbookIntroductions.json", [
        {"lessonNumber": r[0], "title": r[1], "body": r[2]}
        for r in conn.execute(
            "SELECT id, title, text FROM lessons WHERE id IN (0, 500) ORDER BY id"
        )
    ])

    write("ACIMManual.json", [
        {"segmentId": r[0], "body": r[1]}
        for r in conn.execute(
            "SELECT id, COALESCE(NULLIF(text_paragraphs, ''), text) FROM segments "
            "WHERE source_pdf = 'Manual' ORDER BY id"
        )
    ])

    # text_paragraphs is the published reading; text feeds narration. Never cross them.
    write("ACIMSegments.json", [
        {"segmentId": r[0], "sourcePDF": r[1],
         "body": r[2]}
        for r in conn.execute(
            "SELECT id, source_pdf, COALESCE(NULLIF(text_paragraphs, ''), text) "
            "FROM segments ORDER BY id"
        )
    ])

    conn.close()
    print("Export complete.")


if __name__ == "__main__":
    main()
