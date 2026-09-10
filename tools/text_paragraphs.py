#!/usr/bin/env python3
"""Recover paragraph structure from the Text's raw PDF extraction.

The Text is the only bundled corpus without a curated `text_paragraphs`
column, so its bodies still carry the shape of the page they were scanned
from: paragraphs marked by a first-line indent, blank lines that are page
breaks rather than paragraph breaks, and running heads and page numbers
sitting in the middle of sentences.

The output is display form -- paragraphs joined by a blank line, every
paragraph a single line -- so that Swift's ReadingText.displayString leaves
it byte-for-byte unchanged. That equality is what keeps a stored highlight
offset and the string on screen measuring the same thing.
"""
import re

# Closing punctuation that can end a sentence. A quotation mark or bracket
# counts because a paragraph often ends inside one.
SENTENCE_END = set('.!?"”’)')

# Below this indent a line is body text; at or above it the line is centred
# page furniture rather than prose.
FURNITURE_INDENT = 20

# A first-line indent. Wider than this is furniture, narrower is noise.
PARAGRAPH_INDENT = range(2, 16)


def title_key(text):
    """Reduce a heading to letters and digits so hyphenation and quotation
    marks cannot stop a running head from matching its own title."""
    return re.sub(r"[^A-Z0-9]", "", text.upper())


def heading_key(text):
    """title_key, ignoring a leading chapter or page number.

    Chapter 11's running heads are `11 GOD'S PLAN FOR SALVATION`. Matching
    only the title leaves the number on the line, so `is_shouted_heading`
    cannot see it, and the line is joined into the sentence.
    """
    return title_key(re.sub(r"^\d{1,3}\s+", "", text.strip()))


def running_head_keys(rows):
    """Every heading that can appear as a running head, as match keys."""
    keys = {title_key("TEXT"), title_key("MIRACLES")}
    for row in rows:
        keys.add(title_key(row["chapterTitle"]))
        keys.add(title_key(row["sectionTitle"]))
    keys.discard("")
    return keys


def is_shouted_heading(stripped, keys):
    """A line that is nothing but a heading, in capitals.

    Six running heads lost their centring during extraction and sit flush at
    the margin, where the indent test cannot see them -- one of them mid-
    sentence. The lowercase test is what keeps this from eating real prose:
    the Course quotes its own section titles in the body ("To HAVE, GIVE all
    TO all"), and those carry lowercase letters.
    """
    if any(character.islower() for character in stripped):
        return False
    return heading_key(stripped) in keys


def is_furniture(line, keys):
    stripped = line.strip()
    if not stripped:
        return False
    if re.fullmatch(r"[….·\s]+", stripped):
        return True
    if is_shouted_heading(stripped, keys):
        return True
    if len(line) - len(line.lstrip()) < FURNITURE_INDENT:
        return False
    if re.fullmatch(r"\d{1,3}|[ivxlcdm]{1,7}", stripped):
        return True
    return heading_key(stripped) in keys


def paragraphs(body, keys):
    """The section as a list of display paragraphs."""
    result = []
    current = []
    after_blank = False

    for line in body.split("\n"):
        if not line.strip():
            after_blank = True
            continue
        if is_furniture(line, keys):
            continue

        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        previous = current[-1] if current else ""
        ends_sentence = bool(previous) and previous[-1] in SENTENCE_END
        ends_colon = previous.endswith(":")

        starts_paragraph = False
        if not current:
            starts_paragraph = False
        elif indent <= 1 and re.match(r"\d{1,3}\.\s", stripped):
            starts_paragraph = True
        elif indent in PARAGRAPH_INDENT and (ends_sentence or ends_colon):
            starts_paragraph = True
        elif after_blank and ends_sentence:
            starts_paragraph = True

        if starts_paragraph:
            result.append(" ".join(current))
            current = []
        current.append(stripped)
        after_blank = False

    if current:
        result.append(" ".join(current))
    return [re.sub(r"\s+", " ", p).strip() for p in result if p.strip()]


def strip_running_heads(text, chapter_number, chapter_title):
    """Pull a numbered running head out of a display-form paragraph.

    The line-level skip cannot see a head that has already been joined into
    a sentence. One of Chapter 11's twelve sits on a line-wrap hyphen
    (`re-` / `inforcement`); that hyphen is the wrap, not the word.
    """
    if not chapter_number or not chapter_title:
        return text
    title = re.escape(chapter_title)
    number = re.escape(str(chapter_number))
    hyphenated = re.compile(
        rf"(?<=[A-Za-z])- {number} {title} (?=[A-Za-z])"
    )
    spaced = re.compile(rf" {number} {title} ")
    return spaced.sub(" ", hyphenated.sub("", text))


def display_body(body, keys, chapter_number=None, chapter_title=None):
    """The section in display form: what the reader sees, verbatim."""
    text = "\n\n".join(paragraphs(body, keys))
    return strip_running_heads(text, chapter_number, chapter_title)


def display_string(raw):
    """Swift's `ReadingText.displayString`, in Python.

    Kept character-for-character equivalent on purpose: this is the function
    that decides what the reader sees and what every stored highlight offset
    is counted against, so the export is only correct if applying it changes
    nothing.
    """
    blocks = re.split(r"\n[ \t]*\n[ \t\n]*", raw)
    paragraphs_out = [re.sub(r"\s+", " ", block).strip() for block in blocks]
    return "\n\n".join(p for p in paragraphs_out if p)


# A run of single letters is a heading the page set letter-spaced -- the
# Preface's `p u b l i s h e r ’s n o t e`. It is furniture, and it is furniture
# no indent rule can see, because it sits glued to the front of real prose. The
# possessive belongs inside the run: matching single characters alone stops at
# the `’s` and leaves `’s n o t e` in the body.
LETTER_SPACED = re.compile(r"(?:(?:['\u2019]s|[^\W\d_]) ){3,}", re.UNICODE)


def _self_check():
    title = "GOD’S PLAN FOR SALVATION"
    keep = "The Holy Spirit does not need your help in this."
    if strip_running_heads(keep, 11, title) != keep:
        raise SystemExit(f"FAIL ate prose: {keep!r}")
    glued = "God’s answer 11 GOD’S PLAN FOR SALVATION to YOU."
    got = strip_running_heads(glued, 11, title)
    if got != "God’s answer to YOU.":
        raise SystemExit(f"FAIL strip {glued!r} -> {got!r}")
    wrapped = "this as re- 11 GOD’S PLAN FOR SALVATION inforcement."
    got = strip_running_heads(wrapped, 11, title)
    if got != "this as reinforcement.":
        raise SystemExit(f"FAIL hyphen {wrapped!r} -> {got!r}")
    keys = {title_key(title), title_key("TEXT")}
    if not is_shouted_heading("11 GOD’S PLAN FOR SALVATION", keys):
        raise SystemExit("FAIL numbered running head is not furniture")
    if is_shouted_heading('To HAVE, GIVE all TO all', keys):
        raise SystemExit("FAIL quoted title with lowercase was eaten")


def verify(rows):
    """Assert the properties the app depends on. Returns a report."""
    keys = running_head_keys(rows)
    furniture = []
    broken = []
    reshaped = []
    letter_spaced = []
    total = 0

    for row in rows:
        body = row["body"]
        where = f"{row['chapterNumber']}.{row['sectionNumber']}"

        if display_string(body) != body:
            reshaped.append(where)

        blocks = body.split("\n\n")
        total += len(blocks)
        for block in blocks[:-1]:
            # A colon or semicolon ends a paragraph that introduces a list or a
            # quotation, which is one legitimate way to break mid-thought. The
            # other is a line of set verse inside a quotation the next line
            # closes -- the Preface's couplet, "Do not attempt to break God's
            # copyright, / because His Authorship alone can copy right." The
            # page sets those as two centred lines, so joining them would
            # flatten structure the book has.
            if not block:
                continue
            open_quote = block.count("\u201c") > block.count("\u201d")
            if block[-1] in SENTENCE_END or block[-1] in ":;":
                continue
            if open_quote and block[-1] == ",":
                continue
            broken.append((where, block[-60:]))
        for block in blocks:
            if "\n" in block:
                reshaped.append(where)
            stripped = block.strip()
            for match in LETTER_SPACED.finditer(block):
                letter_spaced.append((where, match.group()[:60]))
            if re.fullmatch(r"\d{1,3}|[ivxlcdm]{1,7}", stripped):
                furniture.append((where, stripped))
            elif is_shouted_heading(stripped, keys):
                furniture.append((where, stripped[:60]))

    running = []
    by_chapter = {}
    for row in rows:
        by_chapter.setdefault(row["chapterNumber"], row["chapterTitle"])
    for row in rows:
        title = by_chapter.get(row["chapterNumber"])
        if not title or not row["chapterNumber"]:
            continue
        pattern = re.compile(
            rf"{re.escape(str(row['chapterNumber']))} {re.escape(title)}"
        )
        where = f"{row['chapterNumber']}.{row['sectionNumber']}"
        for match in pattern.finditer(row["body"]):
            running.append((where, match.group()))

    return {
        "sections": len(rows),
        "paragraphs": total,
        "not_display_form": sorted(set(reshaped)),
        "page_furniture": furniture,
        "mid_sentence_breaks": broken,
        "letter_spaced_headings": letter_spaced,
        "running_heads_in_prose": running,
    }


if __name__ == "__main__":
    import json
    import sys
    from pathlib import Path

    _self_check()

    path = (
        Path(__file__).resolve().parent.parent
        / "ACIMDailyMinute" / "Resources" / "ACIMTextSections.json"
    )
    rows = json.loads(path.read_text(encoding="utf-8"))
    write = "--write" in sys.argv
    if write:
        rewritten = 0
        for row in rows:
            cleaned = strip_running_heads(
                row["body"], row["chapterNumber"], row["chapterTitle"]
            )
            if cleaned != row["body"]:
                row["body"] = cleaned
                rewritten += 1
        path.write_text(
            json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        print(f"rewrote {rewritten} sections")

    report = verify(rows)
    print(f"sections: {report['sections']}  paragraphs: {report['paragraphs']}")
    failed = False
    for name in ("not_display_form", "page_furniture", "mid_sentence_breaks",
                 "letter_spaced_headings", "running_heads_in_prose"):
        entries = report[name]
        print(f"{name}: {len(entries)}")
        for entry in entries[:10]:
            print("   ", entry)
        if entries:
            failed = True
    sys.exit(1 if failed else 0)
