#!/usr/bin/env python3
"""Put back the space the page had and the PDF text layer lost.

`their Source,Which is`, `William Thetford.The edit`, `original sin.”To study`.
The defect is in the PDFs' own text layer -- `pdftotext` reproduces it in every
extraction mode -- so a fresh extraction returns the identical defect while
renumbering `segments.id`, the identity behind every published episode, every
MP3 and every reader annotation. The corpus is never re-extracted. This is the
repair, applied over the rows that already exist.

Two halves, measured separately. The insert half never removes a character, so
a word the publisher narrated stays the word the publisher narrated. The
remove half deletes only U+0020 immediately before a closing double quote
(`the “self ”`, `with you. ”The Holy Spirit`) -- 22 occurrences in the
bundle, all defects, zero legitimate, zero that would glue two letters. It
runs first so that `.”T` can still receive the insert. A space before an
opening quote is English and is not touched.

Idempotent. Preserves paragraph structure. The insert creates no double space
because both halves of every match are non-whitespace.

Kept character-for-character equivalent to `PunctuationSpacing.repaired` in
Swift. The bundle is repaired here at export; feed text is repaired there at
render; and the two only agree if the rule is one rule.
"""
import re

# The mirror of the insert: a U+0020 the page did not have, sitting in front
# of a closing double quote. Opening quotes (`“`) are not this character.
_STRAY_BEFORE_CLOSING = " ”"

# Terminal or internal punctuation, or a closing double quote, run straight into
# the next sentence or quotation.
_RUN_TOGETHER = re.compile(r"([.,;:!?”])([A-Z“‘])")

# A closing single quote run into the next word. The negative lookahead is the
# whole difficulty: `GOD’S PLAN` is a possessive and must be left alone, while
# `the only ‘sacrifice’You ask` is the defect. They are separable because no
# `’S` in the corpus is followed by a lowercase letter.
_CLOSING_SINGLE_QUOTE = re.compile(r"(’)(?!S(?![A-Za-z]))([A-Z])")


def repair(text):
    """The text with its missing spaces restored and stray ones removed."""
    cleaned = text.replace(_STRAY_BEFORE_CLOSING, "”")
    return _CLOSING_SINGLE_QUOTE.sub(r"\1 \2", _RUN_TOGETHER.sub(r"\1 \2", cleaned))


def occurrences(text):
    """How many spaces the repair would insert or remove. Zero means clean."""
    stray = text.count(_STRAY_BEFORE_CLOSING)
    cleaned = text.replace(_STRAY_BEFORE_CLOSING, "”")
    once = _RUN_TOGETHER.sub(r"\1 \2", cleaned)
    return stray + len(_RUN_TOGETHER.findall(cleaned)) + len(
        _CLOSING_SINGLE_QUOTE.findall(once)
    )


if __name__ == "__main__":
    import json
    import sys
    from pathlib import Path

    # Hardcoded expected strings, not repair(input). Agreement with itself
    # would pass whether or not the new half of the rule exists.
    cases = [
        ('the “self ” the ego sees', 'the “self” the ego sees'),
        ('with you. ”The Holy Spirit', 'with you.” The Holy Spirit'),
        ('Listen, learn, and DO; ” – Listen', 'Listen, learn, and DO;” – Listen'),
        ('said “hello', 'said “hello'),
        ("GOD’S PLAN", "GOD’S PLAN"),
        ('already.” Next', 'already.” Next'),
    ]

    failed = False
    for source, want in cases:
        got = repair(source)
        if got != want:
            print(f"  case {source!r}\n    want {want!r}\n    got  {got!r}")
            failed = True
        if repair(got) != got:
            print(f"  not idempotent: {source!r}")
            failed = True

    resources = (
        Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"
    )
    expected = {
        "ACIMTextSections.json": 272,
        "Workbook365Bodies.json": 365,
        "ACIMSegments.json": 1983,
        "ACIMManual.json": 31,
        "WorkbookIntroductions.json": 22,
    }

    for name, count in expected.items():
        rows = json.loads((resources / name).read_text(encoding="utf-8"))
        survivors = sum(occurrences(row["body"]) for row in rows)
        status = "clean" if survivors == 0 else f"{survivors} UNREPAIRED"
        print(f"{name}: {len(rows)} records, {status}")
        if survivors or len(rows) != count:
            failed = True
    sys.exit(1 if failed else 0)
