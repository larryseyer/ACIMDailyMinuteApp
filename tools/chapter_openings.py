#!/usr/bin/env python3
"""Recover the chapter openings the Text lost, from data the bundle already has.

The pipeline's `text_sections` extractor cut each chapter at its first SECTION
heading and discarded everything between the chapter title and it. In the source
the opening prose is glued onto the last line of the wrapped chapter title --

    The Forgiveness
    of Illusions To empathize does not mean to join in SUFFERING...

-- so the opening went out with the heading. Eight spans are missing that way,
about 12,000 characters, including the whole opening of chapters 13, 16 and 20
and the line "How simple is salvation!" that opens chapter 31.

Every one of those spans is still in `segments`, which is a continuous cut of the
same PDFs. This module finds them by asking which parts of the segment stream no
section contains, and hands them back with the section each one belongs in front
of. Nothing is re-extracted and nothing is read from a PDF: the words come from
rows that already exist.

⛔ The comparison runs on NORMALIZED text -- letters and digits only, lowercased
-- because the two sides disagree about whitespace, line wrapping and letter
spacing, and none of that is a difference in the words.
"""
import re

from citations import display_paragraphs, normalize

# A window long enough that ordinary phrasing cannot repeat it by chance, short
# enough to still sit inside a one-sentence gap.
WINDOW = 40

# Below this a "gap" is the seam where a section boundary interrupts a window,
# not missing text. The smallest real gap is 356 characters.
MIN_GAP = 60

_UNITS = ["", "one", "two", "three", "four", "five", "six", "seven", "eight",
          "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
          "sixteen", "seventeen", "eighteen", "nineteen"]


def number_word(n):
    """`16` -> `sixteen`, `22` -> `twentytwo`, normalized.

    The chapter number is spelled out above each chapter title, and it arrives
    letter-spaced often enough (`thirte e n`, `twenty two`) that only the
    normalized form is worth comparing.
    """
    if n < 20:
        return _UNITS[n]
    tens = {20: "twenty", 30: "thirty"}[n - n % 10]
    return tens + (_UNITS[n % 10] if n % 10 else "")


def _windows(text):
    return {hash(text[i:i + WINDOW]) for i in range(len(text) - WINDOW + 1)}


def display_form(body):
    """The one string a reader would see, which is what both sides compare as."""
    return "\n\n".join(display_paragraphs(body))


def _normalized_with_index(text):
    """Normalized text, plus the offset in `text` each normalized character came from."""
    chars, index = [], []
    for offset, character in enumerate(text):
        if character.isalnum():
            chars.append(character.lower())
            index.append(offset)
    return "".join(chars), index


def gaps(sections, segments, family="Text"):
    """Every run of the segment stream that no section contains.

    `sections` are the raw section rows, `segments` the raw segment rows. Returns
    one dict per gap: the text that is missing, and the `(chapter, section)`
    whose opening words follow it -- which is where it belongs.
    """
    covered_windows = set()
    heads = {}
    for row in sections:
        body = normalize(display_form(row["body"]))
        covered_windows |= _windows(body)
        heads[body[:WINDOW + 20]] = (row["chapterNumber"], row["sectionNumber"])

    stream = "\n\n".join(
        display_form(row["body"])
        for row in sorted(segments, key=lambda r: r["segmentId"])
        if row["sourcePDF"].startswith(family)
    )
    normalized, index = _normalized_with_index(stream)

    covered = bytearray(len(normalized))
    for i in range(len(normalized) - WINDOW + 1):
        if hash(normalized[i:i + WINDOW]) in covered_windows:
            covered[i:i + WINDOW] = b"\1" * WINDOW

    found = []
    position = 0
    while position < len(normalized):
        if covered[position]:
            position += 1
            continue
        end = position
        while end < len(normalized) and not covered[end]:
            end += 1
        if end - position >= MIN_GAP:
            # Slice the DISPLAY text, not the normalized text: the words have to
            # come back with their punctuation and their paragraph breaks.
            start_offset = index[position]
            stop_offset = index[end] if end < len(index) else len(stream)
            found.append({
                "text": stream[start_offset:stop_offset],
                "normalized_length": end - position,
                "follows": heads.get(normalized[end:end + WINDOW + 20]),
            })
        position = end
    return found


# A paragraph that opens with a run of single letters is a letter-spaced
# heading the PDF set that way -- `p u b l i s h e r ’s n o t e`. Ordinary prose
# never opens with four of them, so the run is the signal.
#
# ⛔ The possessive has to be part of the run. Matching only single characters
# stops at the `’s` and leaves `’s n o t e` sitting in the body, which is not
# furniture any other check knows how to see.
_SINGLE = re.compile(r"^(?:(?:['’]s|\S) ){4,}", re.UNICODE)

# What sentence-ending punctuation looks like, so a splice knows whether it is
# joining two paragraphs or finishing a sentence someone cut in half.
SENTENCE_END = set('.!?"”’)')


def strip_chapter_heading(text, chapter_number, chapter_title):
    """Drop the chapter number and title the opening prose is glued to.

    ⛔ Fails loud. Keeping furniture silently would put `sixteen The Forgiveness
    of Illusions` into the body of a section a reader is going to read, and the
    only thing that would notice is a reader.
    """
    expected = number_word(chapter_number) + normalize(chapter_title)
    seen = []
    for offset, character in enumerate(text):
        if character.isalnum():
            seen.append(character.lower())
            consumed = "".join(seen)
            if consumed == expected:
                return text[offset + 1:].lstrip()
            if not expected.startswith(consumed):
                break
    raise ValueError(
        f"chapter {chapter_number}: opening does not start with "
        f"{expected!r} -- {text[:80]!r}"
    )


def strip_trailing_title(text, section_title):
    """Drop the heading of the section that follows, when it landed in the gap.

    The Preface's gap ends `...unaware of its REALITY.` / `the use of terms`,
    which is the next section's own heading and belongs to it, not here.
    """
    stripped = text.rstrip()
    tail = stripped.split("\n\n")[-1]
    if normalize(tail) == normalize(section_title):
        return "\n\n".join(stripped.split("\n\n")[:-1]).rstrip()
    return stripped


def strip_letterspaced_headings(text):
    """Un-glue a letter-spaced heading from the paragraph it was set into."""
    return "\n\n".join(_SINGLE.sub("", block) for block in text.split("\n\n"))


def recovered_sections(sections, segments):
    """What to splice where, one entry per gap, in reading order.

    `mode` is `prepend` where the chapter's Introduction survives and only lost
    its opening, and `new` where the whole opening was dropped and the chapter
    has no Introduction at all.
    """
    by_address = {(r["chapterNumber"], r["sectionNumber"]): r for r in sections}
    recovered = []
    for gap in gaps(sections, segments):
        if gap["follows"] is None:
            raise ValueError(f"gap belongs to no section: {gap['text'][:80]!r}")
        chapter, section = gap["follows"]
        row = by_address[(chapter, section)]

        text = gap["text"]
        if chapter:
            text = strip_chapter_heading(text, chapter, row["chapterTitle"])
        text = strip_trailing_title(text, row["sectionTitle"])
        text = strip_letterspaced_headings(text).strip()

        is_introduction = normalize(row["sectionTitle"]) == "introduction"
        recovered.append({
            "chapter": chapter,
            "section": section,
            "text": text,
            "mode": "prepend" if is_introduction else "new",
            # The Preface's opening is the publisher's own front matter and the
            # source titles it; a chapter's is an Introduction like the 28 that
            # survived. Neither title is invented.
            "title": "Publisher’s Note" if chapter == 0 else "Introduction",
        })
    return recovered


def splice(recovered_text, existing_body):
    """Join a recovered opening to the body it was cut from.

    ⛔ Two of the eight gaps end in the middle of a sentence -- chapter 7 stops
    at `...and His Kingdom. BY` and chapter 22 at `...in the same`, with the
    surviving body carrying on `ACCEPTING this power...` and `room and yet a
    world apart.` A paragraph break there would invent one where the book has a
    sentence, so the seam is a space and the two halves become one paragraph.
    """
    text = recovered_text.rstrip()
    separator = "\n\n" if text and text[-1] in SENTENCE_END else " "
    return text + separator + existing_body


if __name__ == "__main__":
    import json
    from pathlib import Path

    resources = Path(__file__).resolve().parent.parent / "ACIMDailyMinute" / "Resources"
    load = lambda name: json.loads((resources / name).read_text(encoding="utf-8"))
    for gap in gaps(load("ACIMTextSections.json"), load("ACIMSegments.json")):
        print("=" * 78)
        print(f"{gap['normalized_length']} chars, belongs before section {gap['follows']}")
        print("HEAD:", repr(gap["text"][:240]))
        print("TAIL:", repr(gap["text"][-240:]))
