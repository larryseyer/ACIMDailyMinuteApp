#!/usr/bin/env python3
"""Pull Workbook introductions out of the lesson they were glued to.

The PDF extractor associated each Review, Part II, and What Is heading with
the lesson that ended on the same page. Those readings belong in front of the
next lesson, as their own rows, the way the two Part Introductions already
sit. This module is the one place that split is defined, so a re-export from
the pipeline database cannot glue them back on.
"""
import json
import re
from pathlib import Path

RESOURCES = Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"

# Roman numerals as the book prints them on the Review headings.
_REVIEW_ROMAN = {
    "i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6,
}
_REVIEW_RE = re.compile(r"^\s*review\s+(i{1,3}|iv|v|vi)\s*$", re.I)
_PART_II_RE = re.compile(r"^\s*INTRODUCTION\s*$")

# Collapsed letter-spaced headings → (id, title, insertBefore, what-is index).
# The heading itself becomes the title of the new reading and is stripped from
# the body, the same way Part 1 Introduction does not repeat its own name.
_WHAT_IS = {
    "whatisforgiveness?": (601, "What Is Forgiveness?", 221, 1),
    "whatissalvation?": (602, "What Is Salvation?", 231, 2),
    "whatistheworld?": (603, "What Is the World?", 241, 3),
    "whatissin?": (604, "What Is Sin?", 251, 4),
    "whatisthebody?": (605, "What Is the Body?", 261, 5),
    "whatisthechrist?": (606, "What Is the Christ?", 271, 6),
    "whatistheholyspirit?": (607, "What Is the Holy Spirit?", 281, 7),
    "whatistherealworld?": (608, "What Is the Real World?", 291, 8),
    "whatisthesecondcoming?": (609, "What Is the Second Coming?", 301, 9),
    "whatisthelastjudgement?": (610, "What Is the Last Judgment?", 311, 10),
    "whatiscreation?": (611, "What Is Creation?", 321, 11),
    "whatistheego?": (612, "What Is the Ego?", 331, 12),
    "whatisamiracle?": (613, "What Is a Miracle?", 341, 13),
    "whatami?": (614, "What Am I?", 351, 14),
}

# Review N introduces the first lesson of that review period.
_REVIEW_INSERT_BEFORE = {1: 51, 2: 81, 3: 111, 4: 141, 5: 171, 6: 201}

_NON_LETTER = re.compile(r"[^a-z?]")


def _collapsed(line):
    return _NON_LETTER.sub("", line.lower())


def _heading(line):
    """Kind and payload for a line that opens a glued introduction, or None."""
    match = _REVIEW_RE.match(line)
    if match:
        number = _REVIEW_ROMAN[match.group(1).lower()]
        return (
            "review",
            400 + number,
            f"Review {match.group(1).upper()}",
            _REVIEW_INSERT_BEFORE[number],
            f"W-r{number}.in",
        )
    if _PART_II_RE.match(line):
        # Placement at 181 is already shipping; this only unglues the words
        # from lesson 220. Moving the row is a different call.
        return ("part2", 500, "Part 2 Introduction", 181, "W-pII.in")
    what = _WHAT_IS.get(_collapsed(line))
    if what:
        ident, title, insert_before, index = what
        return ("whatis", ident, title, insert_before, f"W-w{index}.in")
    return None


def _chunk_body(lines):
    return "\n".join(lines).strip("\n")


def split_lesson(body):
    """Lesson text and the introductions that had been glued to its foot.

    Headings stay out of the bodies: the reading names itself in `title`.
    """
    lines = body.split("\n")
    marks = [(index, _heading(line)) for index, line in enumerate(lines)]
    marks = [(index, heading) for index, heading in marks if heading is not None]
    if not marks:
        return body, []

    lesson = _chunk_body(lines[: marks[0][0]])
    extracted = []
    for position, (start, heading) in enumerate(marks):
        end = marks[position + 1][0] if position + 1 < len(marks) else len(lines)
        kind, ident, title, insert_before, stem = heading
        extracted.append({
            "lessonNumber": ident,
            "title": title,
            "insertBefore": insert_before,
            "citationStem": stem,
            "body": _chunk_body(lines[start + 1: end]),
            "kind": kind,
        })
    return lesson, extracted


def split_lessons(lesson_rows):
    """Return (updated lesson rows, extracted introductions)."""
    updated = []
    extracted = []
    for row in lesson_rows:
        body, intros = split_lesson(row["body"])
        updated.append({"lessonNumber": row["lessonNumber"], "body": body})
        extracted.extend(intros)
    extracted.sort(key=lambda row: (row["insertBefore"], row["lessonNumber"]))
    return updated, extracted


def merge_introductions(existing, extracted):
    """Part 1 stays as shipped; Part 2 takes the complete extracted body.

    Extracted reviews and What Is readings are new. `kind` is a splitter
    bookkeeping field and does not travel in the bundle.
    """
    by_id = {}
    for row in existing:
        record = {
            "lessonNumber": row["lessonNumber"],
            "title": row["title"],
            "insertBefore": row.get("insertBefore", 1 if row["lessonNumber"] == 0 else 181),
            "citationStem": row.get(
                "citationStem",
                "W-pI.in" if row["lessonNumber"] == 0 else "W-pII.in",
            ),
            "body": row["body"],
        }
        by_id[record["lessonNumber"]] = record

    if 0 in by_id:
        by_id[0]["insertBefore"] = 1
        by_id[0]["citationStem"] = "W-pI.in"

    for row in extracted:
        record = {
            "lessonNumber": row["lessonNumber"],
            "title": row["title"],
            "insertBefore": row["insertBefore"],
            "citationStem": row["citationStem"],
            "body": row["body"],
        }
        by_id[record["lessonNumber"]] = record

    return sorted(by_id.values(), key=lambda row: (row["insertBefore"], row["lessonNumber"]))


def remaining_headings(lesson_rows):
    """Lesson numbers that still carry a glued-introduction heading."""
    leftover = []
    for row in lesson_rows:
        for line in row["body"].split("\n"):
            if _heading(line):
                leftover.append(row["lessonNumber"])
                break
    return leftover


def apply_to_bundle(resources=RESOURCES):
    """Split the shipping JSON and return the new rows (does not write)."""
    lessons = json.loads((resources / "Workbook365Bodies.json").read_text(encoding="utf-8"))
    existing = json.loads((resources / "WorkbookIntroductions.json").read_text(encoding="utf-8"))
    lessons, extracted = split_lessons(lessons)
    introductions = merge_introductions(existing, extracted)
    return lessons, introductions, extracted


def write_bundle(lessons, introductions, resources=RESOURCES):
    (resources / "Workbook365Bodies.json").write_text(
        json.dumps(lessons, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    (resources / "WorkbookIntroductions.json").write_text(
        json.dumps(introductions, ensure_ascii=False, indent=1), encoding="utf-8"
    )


if __name__ == "__main__":
    lessons, introductions, extracted = apply_to_bundle()
    leftover = remaining_headings(lessons)
    print(f"extracted {len(extracted)} introductions from lesson bodies")
    for row in extracted:
        print(f"  {row['lessonNumber']:>4} {row['citationStem']:<12} "
              f"before {row['insertBefore']:<3} {row['title']} "
              f"({len(row['body'])} chars)")
    print(f"introductions in bundle: {len(introductions)}")
    if leftover:
        raise SystemExit(f"FAIL: headings remain in lessons {leftover}")
    part2 = next(row for row in introductions if row["lessonNumber"] == 500)
    if "Now is the need for practice almost done" not in part2["body"]:
        raise SystemExit("FAIL: Part 2 Introduction is still missing its last paragraphs")
    write_bundle(lessons, introductions)
    print("wrote Workbook365Bodies.json and WorkbookIntroductions.json")
