#!/usr/bin/env python3
"""Strip letter-spaced headings the PDF set into the body.

The page set titles with a space between each letter -- `p u b l i s h e r ’s
n o t e`, `l e s s o n 11`, `w h o a r e g o d ’s t e ac h e r s ?`. Extraction
kept the spaces, so the heading sits in the paragraph a reader would read.

The Text's recovered openings already un-glue these. Lessons and introductions
never had them. They remain in the Manual and in the segment stream, and a
re-export from the pipeline database would glue them back on. This is the one
strip, applied over the rows that exist.

A heading is removed only when it is a known title (a Manual question, a What
Is reading, the publisher's note, a spelled chapter number, `lesson N`) AND
the original has at least one space inside a title word. `What is a miracle?`
as a sentence the Course asks is left alone: those spaces sit at word
boundaries. The rule is idempotent and returns the input unchanged when it
finds nothing.
"""
import re

# Readable forms, collapsed to the match key. Longest key wins so
# `whatistheholyspirit?` is not eaten by `whatis`.
_TITLES = {
    "whoaregodsteachers?": "who are gods teachers?",
    "whoaretheirpupils?": "who are their pupils?",
    "whatarethelevelsofteaching?": "what are the levels of teaching?",
    "whatarethecharacteristicsofgodsteachers?":
        "what are the characteristics of gods teachers?",
    "howishealingaccomplished?": "how is healing accomplished?",
    "ishealingcertain?": "is healing certain?",
    "shouldhealingberepeated?": "should healing be repeated?",
    "howcanperceptionoforderofdifficultiesbeavoided?":
        "how can perception of order of difficulties be avoided?",
    # The extractor inserted a `the` the title does not have.
    "howcantheperceptionoforderofdifficultiesbeavoided?":
        "how can the perception of order of difficulties be avoided?",
    "arechangesrequiredinthelifesituationofgodsteachers?":
        "are changes required in the life situation of gods teachers?",
    "howisjudgmentrelinquished?": "how is judgment relinquished?",
    "howisjudgementrelinquished?": "how is judgement relinquished?",
    "howispeacepossibleinthisworld?": "how is peace possible in this world?",
    "howmanyteachersofgodareneededtosavetheworld?":
        "how many teachers of god are needed to save the world?",
    "whatistherealmeaningofsacrifice?": "what is the real meaning of sacrifice?",
    "howwilltheworldend?": "how will the world end?",
    "iseachonetobejudgedintheend?": "is each one to be judged in the end?",
    "howshouldtheteacherofgodspendhisday?":
        "how should the teacher of god spend his day?",
    "howdogodsteachersdealwiththeirpupilsthoughtsofmagic?":
        "how do gods teachers deal with their pupils thoughts of magic?",
    "howiscorrectionmade?": "how is correction made?",
    "whatisjustice?": "what is justice?",
    "whatisthepeaceofgod?": "what is the peace of god?",
    "whatistheroleofwordsinhealing?": "what is the role of words in healing?",
    "howarehealingandatonementrelated?":
        "how are healing and atonement related?",
    "doesjesushaveaspecialplaceinhealing?":
        "does jesus have a special place in healing?",
    "isreincarnationtrue?": "is reincarnation true?",
    "arepsychicpowersdesirable?": "are psychic powers desirable?",
    "cangodbereacheddirectly?": "can god be reached directly?",
    "whatisdeath?": "what is death?",
    "whatistheresurrection?": "what is the resurrection?",
    "whatisforgiveness?": "what is forgiveness?",
    "whatissalvation?": "what is salvation?",
    "whatistheworld?": "what is the world?",
    "whatissin?": "what is sin?",
    "whatisthebody?": "what is the body?",
    "whatisthechrist?": "what is the christ?",
    "whatistheholyspirit?": "what is the holy spirit?",
    "whatistherealworld?": "what is the real world?",
    "whatisthesecondcoming?": "what is the second coming?",
    "whatisthelastjudgement?": "what is the last judgement?",
    "whatiscreation?": "what is creation?",
    "whatistheego?": "what is the ego?",
    "whatisamiracle?": "what is a miracle?",
    "whatami?": "what am i?",
    "publishersnote": "publishers note",
}

_UNITS = ["", "one", "two", "three", "four", "five", "six", "seven", "eight",
          "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
          "sixteen", "seventeen", "eighteen", "nineteen"]


def _number_word(n):
    if n < 20:
        return _UNITS[n]
    tens = {20: "twenty", 30: "thirty"}[n - n % 10]
    return tens + (_UNITS[n % 10] if n % 10 else "")


def _number_canonical(n):
    if n < 20:
        return _UNITS[n]
    tens = {20: "twenty", 30: "thirty"}[n - n % 10]
    unit = _UNITS[n % 10]
    return tens + (" " + unit if unit else "")


for _n in range(1, 32):
    _TITLES[_number_word(_n)] = _number_canonical(_n)

# Longest collapsed key first so a short title cannot win inside a long one.
_TITLE_KEYS = sorted(_TITLES, key=len, reverse=True)

# Two-word chapter numbers (`twenty one`) are furniture even without
# letter-spacing when they are the whole paragraph. One-word numbers (`one`)
# are not: a paragraph that is just a word the book uses constantly is prose
# until it is spaced out (`Th r e e`).
_WHOLE_NUMBER = {_number_word(n) for n in range(20, 32)}

_COLLAPSE = re.compile(r"[^a-z0-9?]+")
_LESSON = re.compile(r"^\s*l\s*e\s*s\s*s\s*o\s*n(?:\s+\d+)+\s*", re.I)
# The detector that proves leftovers: three single letters in a row, spaced.
LETTER_SPACED = re.compile(r"(?:(?:['\u2019]s|[^\W\d_]) ){3,}", re.UNICODE)


def collapse(text):
    return _COLLAPSE.sub("", text.lower())


def _original_end(text, target):
    """Index in `text` after consuming the collapsed `target`, or None."""
    seen = []
    for index, character in enumerate(text):
        lowered = character.lower()
        if lowered.isalnum() or lowered == "?":
            seen.append(lowered)
            consumed = "".join(seen)
            if consumed == target:
                return index + 1
            if not target.startswith(consumed):
                return None
    return None


def extra_letter_spaces(span, canonical):
    """Spaces that sit inside a canonical word, or None if `span` is not that title.

    Word-boundary spaces (`What is a miracle?`) are not extra. A space inside
    `teachers` or `thirteen` is. Alignment failure means this span is not the
    title, not that it is safe prose.
    """
    words = re.findall(r"[a-z0-9]+", canonical.lower())
    if not words:
        return None
    text = span.lower()
    cursor = 0
    extra = 0

    def skip_separators(index):
        while index < len(text) and not text[index].isalnum():
            index += 1
        return index

    def count_separators(index):
        spaces = 0
        while index < len(text) and not text[index].isalnum():
            if text[index].isspace():
                spaces += 1
            index += 1
        return index, spaces

    for word_index, word in enumerate(words):
        for letter_index, letter in enumerate(word):
            if letter_index == 0:
                cursor = skip_separators(cursor)
            else:
                cursor, spaces = count_separators(cursor)
                extra += spaces
            if cursor >= len(text) or text[cursor] != letter:
                return None
            cursor += 1
    return extra


def _title_match(text):
    """`(end_index, key)` for a letter-spaced title at the start of `text`."""
    collapsed = collapse(text)
    if not collapsed:
        return None
    for key in _TITLE_KEYS:
        if not collapsed.startswith(key):
            continue
        end = _original_end(text, key)
        if end is None:
            continue
        extra = extra_letter_spaces(text[:end], _TITLES[key])
        if extra is None or extra < 1:
            continue
        return end, key
    return None


def _needs_more(text):
    """The start is a letter-spaced prefix of a title that has not finished."""
    collapsed = collapse(text)
    if len(collapsed) < 8:
        return False
    for key in _TITLE_KEYS:
        if key.startswith(collapsed) and collapsed != key:
            extra = extra_letter_spaces(text, _TITLES[key])
            # Incomplete: alignment may fail at the missing tail. Count extra
            # spaces on whatever letters did match by using the prefix of the
            # canonical that we have letters for -- a cheap stand-in: if the
            # fragment itself already has internal spaces, keep joining.
            if extra is not None and extra >= 1:
                return True
            if extra is None and LETTER_SPACED.search(text):
                return True
            # Mixed OCR (`w hat ar e`) often fails LETTER_SPACED too; a
            # collapsed prefix of a known title plus any internal space is
            # enough to look at the next paragraph.
            if extra is None and any(character.isspace() for character in text.strip()):
                return True
    return False


def _whole_number_paragraph(block):
    """A paragraph that is only a spelled chapter number, as furniture."""
    collapsed = collapse(block)
    if collapsed not in _TITLES or collapsed not in {
            _number_word(n) for n in range(1, 32)}:
        return False
    extra = extra_letter_spaces(block, _TITLES[collapsed])
    if extra is not None and extra >= 1:
        return True
    return collapsed in _WHOLE_NUMBER


def strip(text):
    """The body with letter-spaced headings removed. Unchanged if none."""
    if not text:
        return text
    blocks = text.split("\n\n")
    changed = False
    index = 0
    while index < len(blocks):
        block = blocks[index]

        lesson = _LESSON.match(block)
        if lesson:
            rest = block[lesson.end():].lstrip()
            blocks[index:index + 1] = [rest] if rest else []
            changed = True
            continue

        if _whole_number_paragraph(block):
            blocks[index:index + 1] = []
            changed = True
            continue

        matched = False
        limit = min(4, len(blocks) - index)
        for span_count in range(1, limit + 1):
            joined = "\n\n".join(blocks[index:index + span_count])
            found = _title_match(joined)
            if found is not None:
                end, _key = found
                rest = joined[end:].lstrip(" \t")
                if rest.startswith("\n\n"):
                    rest = rest[2:]
                elif rest.startswith("\n"):
                    rest = rest[1:]
                leftover = [part for part in rest.split("\n\n") if part != ""] if rest else []
                blocks[index:index + span_count] = leftover
                changed = True
                matched = True
                break
            if span_count == 1 and not _needs_more(joined):
                break
        if matched:
            continue
        index += 1

    if not changed:
        return text
    return "\n\n".join(part.strip() for part in blocks if part.strip())


def occurrences(text):
    """How many letter-spaced runs remain. Zero means clean."""
    return len(LETTER_SPACED.findall(text))


def _self_check():
    """The cases the rule is built on. Fail loud; a silent miss is a reader."""
    keep = [
        "What is a miracle? A miracle is a correction.",
        "who are their pupils? Certain pupils have been assigned",
        "how is correction made? Correction of a lasting nature",
        "This is a course in MIND TRAINING.",
        "One wholly perfect teacher, whose learning is complete, suffices.",
    ]
    for sample in keep:
        got = strip(sample)
        if got != sample:
            raise SystemExit(f"FAIL ate prose: {sample!r} -> {got!r}")

    gone = [
        ("w h o a r e g o d ’s t e ac h e r s ? A teacher of God",
         "A teacher of God"),
        ("l e s s o n 11\n\n“My meaningless thoughts",
         "“My meaningless thoughts"),
        ("le s s on 13\n\n“A meaningless world",
         "“A meaningless world"),
        ("lesson 10 0\n\n“My part is essential",
         "“My part is essential"),
        ("p u b l i s h e r ’s n o t e In the months",
         "In the months"),
        ("fourte e n Bringing Illusions to Truth Unless you",
         "Bringing Illusions to Truth Unless you"),
        ("Th r e e\n\nRetraining the Mind This is a course",
         "Retraining the Mind This is a course"),
        ("twenty one\n\nReason and Perception",
         "Reason and Perception"),
        ("w hat i s f o r g i v e n e s s ? Forgiveness recognizes",
         "Forgiveness recognizes"),
        ("h ow i s peac e p o s s i ble\n\nin this world? This is a question",
         "This is a question"),
        ("how is judgeme nt re linquishe d? Judgement, like other devices",
         "Judgement, like other devices"),
        ("how will the world e nd?",
         ""),
        ("h ow can th e pe rc e p t i on of\n\n"
         "o r d e r o f d i f f i c u l t i e s b e av o i d e d ? The belief",
         "The belief"),
    ]
    for sample, expected in gone:
        got = strip(sample)
        if got != expected:
            raise SystemExit(f"FAIL strip {sample!r}\n  got {got!r}\n  expected {expected!r}")
        if strip(got) != got:
            raise SystemExit(f"FAIL not idempotent: {sample!r}")


if __name__ == "__main__":
    import json
    import sys
    from pathlib import Path

    _self_check()

    resources = (
        Path(__file__).resolve().parent.parent
        / "ACIMDailyMinute" / "Resources"
    )
    expected = {
        "ACIMTextSections.json": 272,
        "Workbook365Bodies.json": 365,
        "WorkbookIntroductions.json": 22,
        "ACIMManual.json": 105,
        "ACIMSegments.json": 1983,
    }
    write = "--write" in sys.argv
    failed = False
    for name, count in expected.items():
        path = resources / name
        rows = json.loads(path.read_text(encoding="utf-8"))
        survivors = 0
        rewritten = 0
        for row in rows:
            body = row["body"]
            cleaned = strip(body)
            if cleaned != body:
                rewritten += 1
                row["body"] = cleaned
            survivors += occurrences(row["body"] if write else cleaned)
        status = "clean" if survivors == 0 else f"{survivors} LEFT"
        print(f"{name}: {len(rows)} records, {rewritten} rewritten, {status}")
        if survivors or len(rows) != count:
            failed = True
        if write and rewritten:
            path.write_text(
                json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"
            )
    if failed and not write:
        sys.exit(1)
    if failed:
        sys.exit(1)
    print("OK")
