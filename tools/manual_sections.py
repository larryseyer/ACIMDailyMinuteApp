#!/usr/bin/env python3
"""Recover the Manual for Teachers as the book's question-and-answer sections.

The bundled Manual was 105 word-count cuts of a continuous stream, with no
question, no title and nothing to cite. The PDF's own contents page names
31 readings: an Introduction, 28 questions, "As for the Rest…" and
"Forget not…". This module splits the extracted Manual on those headings,
strips page furniture, and emits display-form bodies so
`ReadingText.displayString` is a no-op over them.

Source is the pipeline's corrected extraction, read-only. The bundled JSON
is the permanent artifact.

Citation stems, pinned to this edition's own numbering:

    M-in.<p>   Introduction
    M-<n>.<p>  question n, 1 through 28, then 29 As for the Rest, 30 Forget not
"""
import json
import re
import sys
from pathlib import Path

from punctuation_spacing import repair
from workbook_paragraphs import SENTENCE_END

REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "ACIMDailyMinute" / "Resources"
SOURCE = Path(
    "/Volumes/MacLive/Users/larryseyer/acim-daily-minute/"
    "corrected_text/ACIM_Manual.txt"
)

# The book's contents page, in reading order. Number 0 is the Introduction.
TITLES = [
    "Introduction",
    "Who Are God’s Teachers?",
    "Who Are Their Pupils?",
    "What Are the Levels of Teaching?",
    "What Are the Characteristics of God’s Teachers?",
    "How Is Healing Accomplished?",
    "Is Healing Certain?",
    "Should Healing Be Repeated?",
    "How Can the Perception of Order of Difficulties Be Avoided?",
    "Are Changes Required in the Life Situation of God’s Teachers?",
    "How Is Judgement Relinquished?",
    "How Is Peace Possible in This World?",
    "How Many Teachers of God Are Needed to Save the World?",
    "What Is the Real Meaning of Sacrifice?",
    "How Will the World End?",
    "Is Each One to Be Judged in the End?",
    "How Should the Teacher of God Spend His Day?",
    "How Do God’s Teachers Deal with Their Pupils’ Thoughts of Magic?",
    "How Is Correction Made?",
    "What Is Justice?",
    "What Is the Peace of God?",
    "What Is the Role of Words in Healing?",
    "How Are Healing and Atonement Related?",
    "Does Jesus Have a Special Place in Healing?",
    "Is Reincarnation True?",
    "Are “Psychic” Powers Desirable?",
    "Can God Be Reached Directly?",
    "What Is Death?",
    "What Is the Resurrection?",
    "As for the Rest…",
    "Forget not…",
]

EXPECTED_SECTIONS = 31
# Measured after recovery; pinned so a heading miss cannot silently glue two
# questions together.
EXPECTED_PARAGRAPHS = 211

_COLLAPSE = re.compile(r"[^a-z0-9?]+")
_FURNITURE = re.compile(r"^(?:\d{1,3}|[ivxlcdm]{1,7}|MANUAL|FINIS)$", re.I)
_NUMBERED_HEADING = re.compile(r"^\d+\.\s+[A-Z][A-Z \-']+$")
_TOC_DOTS = re.compile(r"\.\s+\.\s+\.")


def collapse(text):
    return _COLLAPSE.sub("", text.lower())


def citation_stem(number):
    if number == 0:
        return "M-in"
    return f"M-{number}"


_TITLE_KEYS = [(collapse(title), index, title) for index, title in enumerate(TITLES)]
# Longest first so a short title cannot win inside a long one.
_TITLE_KEYS.sort(key=lambda item: len(item[0]), reverse=True)


def match_heading(span):
    """The (index, title) this collapsed span is, or None."""
    key = collapse(span)
    if not key:
        return None
    for collapsed, index, title in _TITLE_KEYS:
        if key == collapsed:
            return index, title
    return None


def is_furniture(stripped):
    if not stripped:
        return True
    if _FURNITURE.fullmatch(stripped):
        return True
    if _TOC_DOTS.search(stripped):
        return True
    return False


def paragraphs(body):
    """Display paragraphs, with numbered all-caps headings as their own block.

    The Workbook rule is the indent rule. The Manual also sets `1. TRUST` as a
    centred heading; that line has no sentence-end punctuation, so the Workbook
    rule would glue the following prose onto it.
    """
    lines = body.splitlines()
    rewritten = []
    for line in lines:
        stripped = line.strip()
        if _NUMBERED_HEADING.match(stripped):
            rewritten.append("")
            rewritten.append(stripped)
            rewritten.append("")
        else:
            rewritten.append(line)
    blocks = []
    current = []

    def text():
        return " ".join(current)

    def can_break():
        if not current:
            return True
        t = text()
        if _NUMBERED_HEADING.match(t):
            return True
        if t.count("\u201c") > t.count("\u201d"):
            return False
        last = t.rstrip()[-1]
        return last in SENTENCE_END or last in ":;"

    def flush():
        if current:
            blocks.append(re.sub(r" +", " ", text()).strip())
            current.clear()

    for line in rewritten:
        stripped = line.strip()
        if not stripped:
            continue
        if _NUMBERED_HEADING.match(stripped):
            flush()
            blocks.append(stripped)
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
    return blocks


def display_body(body):
    return "\n\n".join(paragraphs(body))


def recover(source_text):
    """Split the extracted Manual into the 31 titled readings."""
    lines = source_text.splitlines()

    # Body starts at the Introduction heading that is not a contents-page row.
    start = None
    for index, line in enumerate(lines):
        if collapse(line) == "introduction" and not _TOC_DOTS.search(line):
            start = index
            break
    if start is None:
        raise SystemExit("FAIL: no body Introduction heading")

    sections = []
    current_index = None
    current_title = None
    current_lines = []

    def flush():
        if current_index is None:
            return
        raw = "\n".join(current_lines)
        body = repair(display_body(raw))
        sections.append({
            "number": current_index,
            "title": current_title,
            "body": body,
        })

    def begin(index, title):
        nonlocal current_index, current_title, current_lines
        flush()
        current_index = index
        current_title = title
        current_lines = []

    i = start
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if is_furniture(stripped) and collapse(stripped) not in {
            collapse(t) for t in TITLES
        }:
            i += 1
            continue

        # Two-line heading, then one-line. Longest key already wins inside
        # match_heading.
        paired = None
        if i + 1 < len(lines) and not is_furniture(lines[i + 1].strip()):
            paired = match_heading(stripped + " " + lines[i + 1].strip())
        heading = paired or match_heading(stripped)

        # "Forget not…" has no heading in the body; the prose itself begins
        # the last reading, after FINIS.
        if heading is None and stripped.lower().startswith("forget not once"):
            heading = (len(TITLES) - 1, TITLES[-1])
            current_lines_would_include = True
        else:
            current_lines_would_include = False

        if heading is not None:
            index, title = heading
            begin(index, title)
            if current_lines_would_include:
                current_lines.append(line)
            i += 1 if paired is None or current_lines_would_include else 2
            continue

        if current_index is not None:
            current_lines.append(line)
        i += 1

    flush()
    return sections


def verify(rows):
    from text_paragraphs import display_string

    mid = []
    reshaped = []
    titles = []
    total = 0
    for row in rows:
        titles.append(row["title"])
        body = row["body"]
        blocks = [p for p in body.split("\n\n") if p.strip()]
        total += len(blocks)
        if display_string(body) != body:
            reshaped.append(row["number"])
        for block in blocks[:-1]:
            if _NUMBERED_HEADING.match(block):
                continue
            if block[-1] in SENTENCE_END or block[-1] in ":;":
                continue
            mid.append((row["number"], block[-50:]))
    return {
        "sections": len(rows),
        "paragraphs": total,
        "titles": titles,
        "not_display_form": reshaped,
        "mid_sentence_breaks": mid,
        "first": rows[0]["body"][:80] if rows else "",
        "last_title": rows[-1]["title"] if rows else "",
        "last_start": rows[-1]["body"][:40] if rows else "",
    }


def main(argv):
    write = "--write" in argv
    if SOURCE.exists():
        sections = recover(SOURCE.read_text(encoding="utf-8"))
    else:
        sections = json.loads(
            (RESOURCES / "ACIMManual.json").read_text(encoding="utf-8")
        )
        print(f"source not mounted, verifying bundled {len(sections)} sections")

    report = verify(sections)
    print(f"sections: {report['sections']}  paragraphs: {report['paragraphs']}")
    for row in sections:
        n = len([p for p in row["body"].split("\n\n") if p.strip()])
        print(f"  {row['number']:2d}  {citation_stem(row['number']):6s}  "
              f"{n:3d}p  {row['title']}")

    failed = False
    if report["sections"] != EXPECTED_SECTIONS:
        print(f"  FAIL: expected {EXPECTED_SECTIONS} sections")
        failed = True
    if report["titles"] != TITLES:
        print("  FAIL: title list moved")
        for got, want in zip(report["titles"], TITLES):
            if got != want:
                print(f"    {got!r} != {want!r}")
        failed = True
    if not report["first"].startswith("The role of teaching and learning"):
        print(f"  FAIL: Introduction starts {report['first']!r}")
        failed = True
    if not report["last_start"].startswith("Forget not once this journey"):
        print(f"  FAIL: Forget not starts {report['last_start']!r}")
        failed = True
    if report["not_display_form"]:
        print(f"  FAIL: not display form: {report['not_display_form']}")
        failed = True
    if report["mid_sentence_breaks"]:
        print(f"  FAIL: mid-sentence: {report['mid_sentence_breaks'][:8]}")
        failed = True
    if EXPECTED_PARAGRAPHS is not None and report["paragraphs"] != EXPECTED_PARAGRAPHS:
        print(f"  FAIL: expected {EXPECTED_PARAGRAPHS} paragraphs")
        failed = True

    if write and not failed and SOURCE.exists():
        path = RESOURCES / "ACIMManual.json"
        path.write_text(
            json.dumps(sections, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8",
        )
        print(f"wrote {path}")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
