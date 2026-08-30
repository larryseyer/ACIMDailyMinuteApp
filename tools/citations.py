#!/usr/bin/env python3
"""Citations for the bundled corpus: the format, and where a passage sits.

A citation is the interoperability layer that lets a reader move between this
app, a paper book, and whatever comes after both.

This addresses THE EDITION THIS APP SHIPS. Measured against the bundle, our
Chapter 1 is "INTRODUCTION TO MIRACLES" and carries 53 numbered miracle
principles rather than 50, and a chapter's Introduction occupies section 1 --
so the familiar `T-1.I.1:1` notation would point a reader at the wrong words.
Arabic section numbers are the visible signal that these are not those
citations. There is no sentence number: two defensible splitters disagree on
644 of 3,564 paragraphs, and no published sentence numbering exists for this
edition to settle it.

Kept character-for-character equivalent to `Citation` in Swift, which renders
section, lesson and highlight citations at render time while this module writes
segment citations at export. `tools/verify_citation_agreement.sh` is what keeps
them one format and one paragraph rule.
"""
import bisect
import re

from punctuation_spacing import repair

# The segment locator's shape, measured rather than chosen: a 100-character
# normalized probe resolves 1,865 of 1,878 addressable segments and ambiguously
# resolves none. The slide exists because 21 of those (10 Text, 11 Workbook)
# open with page furniture the paragraph recovery correctly removed -- a chapter
# numeral spelled out ("fifteen"), a section heading, a quoted section title.
PROBE = 100
SLIDE_STEP = 20
SLIDE_LIMIT = 600

_NON_ALPHANUMERIC = re.compile(r"[^a-z0-9]+")
_BLANK_LINE = re.compile(r"\n[ \t]*\n[ \t\n]*")
_WHITESPACE_RUN = re.compile(r"\s+")


def normalize(text):
    """Letters and digits only, lowercased.

    Immune to the spacing repair, quote style, paragraph recovery and
    running-head removal -- which is the whole reason a segment written before
    any of those can still be found afterwards.
    """
    return _NON_ALPHANUMERIC.sub("", text.lower())


def display_paragraphs(raw):
    """The paragraphs a reader sees. Mirrors `ReadingText.paragraphs` in Swift.

    A blank line is structure; a lone newline is a wrapping artifact. The Text's
    bundled bodies are already display form, so this is a no-op over them and
    returns the same 2,911 paragraphs the export's split produced. Lesson bodies
    arrive hard-wrapped, so for those this is the only rule that gives the right
    answer.
    """
    blocks = _BLANK_LINE.split(repair(raw))
    return [p for p in (_WHITESPACE_RUN.sub(" ", b).strip() for b in blocks) if p]


def paragraph_number(offset, display_string):
    """Which paragraph a character offset falls in, 1-based.

    Mirrors `Citation.paragraphNumber(atCharacterOffset:in:)`. An offset landing
    between the two newlines belongs to the paragraph that just ended.
    """
    if offset <= 0:
        return 1
    number = 1
    previous_was_newline = False
    for character in display_string[:offset]:
        if character == "\n":
            if previous_was_newline:
                number += 1
                previous_was_newline = False
            else:
                previous_was_newline = True
        else:
            previous_was_newline = False
    return number


def text_citation(chapter, section, paragraph):
    """The Preface has one section, so a middle number would carry nothing."""
    if chapter == 0:
        return f"Pref.{paragraph}"
    return f"T-{chapter}.{section}.{paragraph}"


def lesson_citation(lesson_number, paragraph):
    return f"W-{lesson_number}.{paragraph}"


def introduction_citation(lesson_number, paragraph):
    """Lesson ids 0 and 500 are the two Part Introductions."""
    part = "I" if lesson_number == 0 else "II"
    return f"W-p{part}.in.{paragraph}"


def addressable_paragraphs(sections, lessons, introductions):
    """Two searchable streams, keyed by the `source_pdf` family that uses them.

    Two streams and not one: a segment from the Text is searched only against
    the Text, and a Workbook segment only against the Workbook. The Workbook
    quotes the Text constantly, so one combined stream would manufacture
    ambiguity that does not exist.

    Each value is `(stream, citations, starts)`: `citations[i]` is the citation
    of the paragraph whose normalized text begins at `starts[i]`, so a hit
    offset resolves by bisection without rebuilding anything.
    """
    def build(groups):
        stream_parts, citations, starts = [], [], []
        position = 0
        for citation_for, body in groups:
            for index, paragraph in enumerate(display_paragraphs(body), start=1):
                normalized = normalize(paragraph)
                starts.append(position)
                citations.append(citation_for(index))
                stream_parts.append(normalized)
                position += len(normalized)
        return "".join(stream_parts), citations, starts

    text_groups = [
        ((lambda i, s=section: text_citation(s["chapterNumber"], s["sectionNumber"], i)),
         section["body"])
        for section in sections
    ]
    workbook_groups = [
        ((lambda i, r=row: introduction_citation(r["lessonNumber"], i)), row["body"])
        for row in introductions
    ] + [
        ((lambda i, r=row: lesson_citation(r["lessonNumber"], i)), row["body"])
        for row in lessons
    ]

    return {"Text": build(text_groups), "Workbook": build(workbook_groups)}


def locate(body, index):
    """The citation of the paragraph a passage BEGINS in, or None.

    The start is the confident half and the only half that is cited. A located
    Text segment spans three paragraphs most of the time and 239 of 1,256 cross
    a section boundary, so a range would need two forms -- and its end would be
    start-plus-length, which assumes the passage runs contiguously through the
    stream. The sliding cases prove furniture is sometimes removed mid-passage,
    so that assumption does not always hold. The start is anchored to an exact
    match; the end is not.

    A passage that does not resolve uniquely gets no citation. It is never
    guessed: a wrong pointer printed into an export outlives the app.
    """
    stream, citations, starts = index
    normalized = normalize(body)
    if len(normalized) < PROBE:
        return None

    limit = min(len(normalized) - PROBE, SLIDE_LIMIT)
    for offset in range(0, limit + 1, SLIDE_STEP):
        probe = normalized[offset:offset + PROBE]
        first = stream.find(probe)
        if first < 0:
            continue
        if stream.find(probe, first + 1) >= 0:
            continue  # ambiguous at this probe; a later probe may still be unique
        return citations[bisect.bisect_right(starts, first) - 1]
    return None
