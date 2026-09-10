#!/usr/bin/env python3
"""Recover paragraph structure from a hard-wrapped Workbook lesson body.

The Text has a curated recovery in `text_paragraphs.py`. Lesson bodies were
left as the PDF text layer extracted them: line wraps at ~60 characters,
first-line indents of 4-7 spaces, and blank lines that are page breaks
rather than paragraph breaks. `ReadingText.displayString` treats a lone
newline as a wrap and a blank line as a paragraph, so a lesson with no
blank line draws as one paragraph even when the book has fifteen.

Measured against the bundled `Workbook365Bodies.json` before this recovery:

- indent 4-7 is the book's first-line indent (2,065 lines)
- indent 0 is a wrap of the current paragraph, except the unindented first
  body paragraph after a closed opening quotation
- indent >= 8 is a centred wrap of a title or a verse line
- a blank line is a page break; joining across it is what keeps
  `Do not,\\n\\nhowever` as one sentence
- a new paragraph is refused unless the current one has ended a sentence
  and is not sitting inside an unclosed quotation, so the recovery cannot
  fire mid-sentence

The output is display form -- paragraphs joined by a blank line, every
paragraph a single line -- so Swift's `ReadingText.displayString` leaves
it byte-for-byte unchanged.

Kept independent of `text_paragraphs.py` because the two corpora indent
differently: the Text's wrap sits at the margin, the Workbook's title wrap
sits at indent 8-22.
"""
import json
import re
import sys
from pathlib import Path

RESOURCES = Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"

SENTENCE_END = set('.!?"”’)')

# Review-format lessons whose PDF really is a stacked quotation, not a wall
# of unrecovered prose. Pinned so a long lesson cannot silently collapse.
ONE_PARAGRAPH_LESSONS = (
    set(range(141, 151)) | set(range(171, 180)) | set(range(201, 221))
)

EXPECTED_LESSONS = 365
EXPECTED_PARAGRAPHS = 2657
EXPECTED_ONE_PARAGRAPH = 39


def paragraphs(body):
    """The lesson as a list of display paragraphs."""
    paras = []
    current = []

    def text():
        return " ".join(current)

    def can_break():
        if not current:
            return True
        t = text()
        if t.count("\u201c") > t.count("\u201d"):
            return False
        last = t.rstrip()[-1]
        return last in SENTENCE_END or last in ":;"

    def flush():
        if current:
            paras.append(re.sub(r" +", " ", text()).strip())
            current.clear()

    for line in body.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        indent = len(line) - len(line.lstrip(" "))
        starts = False
        if 4 <= indent <= 7:
            starts = can_break()
        elif indent == 0 and current and can_break():
            prev = text().rstrip()
            if prev.endswith("\u201d") or prev.endswith('"'):
                if stripped[0].isupper() or stripped[0] in "\u201c\"":
                    starts = True
        if starts:
            flush()
        current.append(stripped)
    flush()
    return paras


def display_body(body):
    """The lesson in display form: what the reader sees, verbatim.

    Must not be run over a body that is already display form: the first-line
    indent is the signal, and display form has none.
    """
    return "\n\n".join(paragraphs(body))


def looks_raw(body):
    """True when the body still carries PDF line wraps or first-line indents."""
    from text_paragraphs import display_string

    for line in body.splitlines():
        if line and len(line) - len(line.lstrip(" ")) >= 4:
            return True
    return display_string(body) != body


def stored_paragraphs(body):
    """The paragraphs a stored body already is, or the ones recovery would make.

    Recovery reads indent. Display form has none, so it is split on blank
    lines the same way `ReadingText.paragraphs` would.
    """
    if looks_raw(body):
        return paragraphs(body)
    return [p for p in body.split("\n\n") if p.strip()]


def verify(rows):
    """Assert the properties the app depends on. Returns a report."""
    from text_paragraphs import display_string

    mid = []
    reshaped = []
    one = []
    total = 0
    by_number = {}

    for row in rows:
        number = row["lessonNumber"]
        body = row["body"]
        by_number[number] = body
        blocks = stored_paragraphs(body)
        total += len(blocks)
        if len(blocks) == 1:
            one.append(number)
        joined = "\n\n".join(blocks)
        if display_string(joined) != joined:
            reshaped.append(number)
        for block in blocks[:-1]:
            if not block:
                continue
            if block[-1] in SENTENCE_END or block[-1] in ":;":
                continue
            mid.append((number, block[-60:]))

    return {
        "lessons": len(rows),
        "paragraphs": total,
        "one_paragraph": sorted(one),
        "not_display_form": reshaped,
        "mid_sentence_breaks": mid,
        "by_number": by_number,
    }


def main(argv):
    path = RESOURCES / "Workbook365Bodies.json"
    rows = json.loads(path.read_text(encoding="utf-8"))
    report = verify(rows)
    failed = False

    print(f"lessons: {report['lessons']}  paragraphs: {report['paragraphs']}")
    print(f"one-paragraph: {len(report['one_paragraph'])}")
    print(f"not_display_form: {len(report['not_display_form'])}")
    print(f"mid_sentence_breaks: {len(report['mid_sentence_breaks'])}")

    if report["lessons"] != EXPECTED_LESSONS:
        print(f"  FAIL: expected {EXPECTED_LESSONS} lessons")
        failed = True
    if report["paragraphs"] != EXPECTED_PARAGRAPHS:
        print(f"  FAIL: expected {EXPECTED_PARAGRAPHS} paragraphs")
        failed = True
    if set(report["one_paragraph"]) != ONE_PARAGRAPH_LESSONS:
        extra = set(report["one_paragraph"]) - ONE_PARAGRAPH_LESSONS
        missing = ONE_PARAGRAPH_LESSONS - set(report["one_paragraph"])
        print(f"  FAIL: one-paragraph set moved extra={sorted(extra)} missing={sorted(missing)}")
        failed = True
    if report["not_display_form"]:
        print(f"  FAIL: not display form: {report['not_display_form'][:10]}")
        failed = True
    if report["mid_sentence_breaks"]:
        print(f"  FAIL: mid-sentence: {report['mid_sentence_breaks'][:5]}")
        failed = True

    lesson1 = stored_paragraphs(report["by_number"][1])
    if len(lesson1) != 15:
        print(f"  FAIL: lesson 1 has {len(lesson1)} paragraphs, want 15")
        failed = True
    elif not lesson1[0].startswith("“Nothing I see in this room"):
        print(f"  FAIL: lesson 1 paragraph 1 is {lesson1[0][:60]!r}")
        failed = True
    elif lesson1[2] != "“This table does not mean anything.”":
        print(f"  FAIL: lesson 1 paragraph 3 is {lesson1[2]!r}")
        failed = True
    elif not lesson1[-1].startswith("Each of the first three lessons"):
        print(f"  FAIL: lesson 1 last paragraph is {lesson1[-1][:60]!r}")
        failed = True

    lesson4 = stored_paragraphs(report["by_number"][4])
    combined = (
        "“This thought about _____ does not mean anything. "
        "It is like the things I see in this room [or wherever you are].”"
    )
    if combined not in lesson4:
        print("  FAIL: lesson 4 split the two-line practice quotation")
        failed = True

    if "--apply" in argv:
        raw_count = sum(1 for row in rows if looks_raw(row["body"]))
        if raw_count == 0:
            print("already display form, nothing to write")
        else:
            for row in rows:
                if looks_raw(row["body"]):
                    row["body"] = display_body(row["body"])
            path.write_text(
                json.dumps(rows, ensure_ascii=False, indent=1) + "\n",
                encoding="utf-8",
            )
            print(f"wrote {path} ({raw_count} recovered)")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
