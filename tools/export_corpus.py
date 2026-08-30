#!/usr/bin/env python3
"""Export the ACIM corpus from the pipeline database into app bundle resources.

Re-runnable. Reads only; never writes to the source database.
"""
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from chapter_openings import recovered_sections, splice
from citations import addressable_paragraphs, locate
from punctuation_spacing import repair
from text_paragraphs import display_body, running_head_keys

DB = Path("/Volumes/MacLive/Users/larryseyer/acim-daily-minute/data/acim.db")
OUT = Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"

EXPECTED = {
    "Workbook365Bodies.json": 365,
    # 268 extracted, plus the four chapter openings that were dropped whole and
    # have to come back as sections of their own. See `chapter_openings.py`.
    "ACIMTextSections.json": 272,
    "ACIMManual.json": 105,
    "ACIMSegments.json": 1983,
    "WorkbookIntroductions.json": 2,
}


def write(name, rows):
    # The one place the spacing repair is applied, so no corpus can be exported
    # with the defect still in it. The bundled JSON is the permanent artifact
    # that outlives the app, so it has to be correct as a document and not only
    # when this app happens to render it.
    for row in rows:
        row["body"] = repair(row["body"])

    path = OUT / name
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    expected = EXPECTED[name]
    if len(rows) != expected:
        sys.exit(f"FAIL {name}: exported {len(rows)}, expected {expected}")
    print(f"  {name}: {len(rows)} records, {path.stat().st_size / 1048576:.2f} MB")


def apply_recovered_openings(sections, segments):
    """Put back the chapter openings the extractor dropped.

    Two shapes. Where a chapter's Introduction survived and lost only its first
    paragraphs, the recovered text is spliced onto the front of it. Where the
    whole opening went -- chapters 13, 16 and 20 have no Introduction at all,
    and the Preface lost the publisher's front matter -- it comes back as a
    section of its own, and every later section in that chapter moves up one.

    ⛔ Renumbering moves addresses: today's `T-16.1 True Empathy` becomes
    `T-16.2`. That is deliberate, and it is why `ACIMSegments.json` is exported
    in the same run -- the citations baked into it have to move with it.
    """
    by_address = {(r["chapterNumber"], r["sectionNumber"]): r for r in sections}
    additions = []

    for item in recovered_sections(sections, segments):
        target = by_address[(item["chapter"], item["section"])]
        if item["mode"] == "prepend":
            target["body"] = splice(item["text"], target["body"])
        else:
            additions.append((item, target["chapterTitle"]))

    for item, chapter_title in additions:
        for row in sections:
            if (row["chapterNumber"] == item["chapter"]
                    and row["sectionNumber"] >= item["section"]):
                row["sectionNumber"] += 1
        sections.append({
            "chapterNumber": item["chapter"],
            "chapterTitle": chapter_title,
            "sectionNumber": item["section"],
            "sectionTitle": item["title"],
            "body": item["text"],
        })

    # CorpusService reads this file in order and does not sort it.
    sections.sort(key=lambda r: (r["chapterNumber"], r["sectionNumber"]))
    return len(additions)


def main():
    if not DB.exists():
        sys.exit(f"FAIL: {DB} not reachable. Is the MacLive share mounted?")
    conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)

    # Workbook bodies 1-365. Ids 0 and 500 are the two Part Introductions and
    # belong to Spec 2, which handles Workbook content outside the 1-365 spine.
    lesson_rows = [
        {"lessonNumber": r[0], "body": r[1]}
        for r in conn.execute(
            "SELECT id, text FROM lessons "
            "WHERE id BETWEEN 1 AND 365 AND text IS NOT NULL AND length(trim(text)) > 0 "
            "ORDER BY id"
        )
    ]
    write("Workbook365Bodies.json", lesson_rows)

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

    # `text_paragraphs` is the published reading; `text` feeds narration. Never
    # cross them. Read before the sections are written, because the openings the
    # extractor dropped are recovered out of these rows.
    segment_rows = [
        {"segmentId": r[0], "sourcePDF": r[1], "body": r[2]}
        for r in conn.execute(
            "SELECT id, source_pdf, COALESCE(NULLIF(text_paragraphs, ''), text) "
            "FROM segments ORDER BY id"
        )
    ]
    added = apply_recovered_openings(raw_sections, segment_rows)
    print(f"  chapter openings recovered: {added} new sections, "
          f"{len(raw_sections)} sections total")
    write("ACIMTextSections.json", raw_sections)

    # Lesson ids 0 and 500 are the two Part Introductions. They sit outside the
    # 1-365 spine, which is why Workbook365Bodies.json cannot hold them and why
    # they had nowhere to appear until the Read tab gave them one.
    introduction_rows = [
        {"lessonNumber": r[0], "title": r[1], "body": r[2]}
        for r in conn.execute(
            "SELECT id, title, text FROM lessons WHERE id IN (0, 500) ORDER BY id"
        )
    ]
    write("WorkbookIntroductions.json", introduction_rows)

    write("ACIMManual.json", [
        {"segmentId": r[0], "body": r[1]}
        for r in conn.execute(
            "SELECT id, COALESCE(NULLIF(text_paragraphs, ''), text) FROM segments "
            "WHERE source_pdf = 'Manual' ORDER BY id"
        )
    ])

    # A segment is a word-count cut: `segments` carries no section and no
    # paragraph column, so its address has to be FOUND rather than read. That
    # locator has no business inside the app, so it runs once, here, and its
    # answer travels in the bundle. The Manual is bundled as 105 cuts of a
    # continuous stream with nothing to address, so it is not searched at all.
    index = addressable_paragraphs(raw_sections, lesson_rows, introduction_rows)
    located = 0
    for row in segment_rows:
        family = "Text" if row["sourcePDF"].startswith("Text") else row["sourcePDF"]
        row["citation"] = locate(row["body"], index[family]) if family in index else None
        if row["citation"]:
            located += 1
    print(f"  citations located: {located} of {len(segment_rows)} segments")

    write("ACIMSegments.json", segment_rows)

    conn.close()
    print("Export complete.")


if __name__ == "__main__":
    main()
