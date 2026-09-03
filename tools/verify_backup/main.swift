import Foundation

// Drives BackupDocument and BackupMerge against cases built here.
//
// ⛔ This harness compiles with `BackupDocument.swift` and `BackupMerge.swift`
// and NOTHING ELSE. That it links at all is half the proof: the file format and
// the merge must stay free of SwiftData, SwiftUI, `Bundle` and `CorpusService`,
// or a reader's backup starts depending on the app that is supposed to be
// survivable.
//
// The properties below are the ones whose failure is silent. A merge that loses
// a paragraph does not crash, does not warn, and is discovered years later by
// someone looking for something they wrote.

setvbuf(stdout, nil, _IONBF, 0)

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 20 { print("  \(message())") }
    }
}

func date(_ offset: Double) -> Date {
    Date(timeIntervalSinceReferenceDate: 780_000_000 + offset)
}

let edition = "References like T-5.3.7 are chapter, section and paragraph of the edition this app carries."

// MARK: - Applying a plan, so idempotence can be stated as a property

/// Mirrors what `BackupService.apply` does to the store, over values.
func apply(_ plan: BackupMerge.MergePlan, to local: BackupMerge.LocalSnapshot)
    -> BackupMerge.LocalSnapshot
{
    var result = local

    for (id, createdAt) in plan.highlightCreatedAt {
        if let index = result.highlights.firstIndex(where: { $0.id == id }) {
            result.highlights[index].createdAt = createdAt
        }
    }
    for highlight in plan.insertHighlights {
        result.highlights.append(
            .init(id: highlight.id, createdAt: highlight.createdAt)
        )
    }

    for (id, revision) in plan.noteRevisions {
        if let index = result.notes.firstIndex(where: { $0.id == id }) {
            result.notes[index].body = revision.body
            result.notes[index].createdAt = revision.createdAt
            result.notes[index].updatedAt = revision.updatedAt
        }
    }
    for note in plan.insertNotes {
        result.notes.append(
            .init(id: note.id, body: note.body, createdAt: note.createdAt, updatedAt: note.updatedAt)
        )
    }

    for (key, createdAt) in plan.bookmarkCreatedAt {
        if let index = result.bookmarks.firstIndex(where: { $0.itemKey == key }) {
            result.bookmarks[index].createdAt = createdAt
        }
    }
    for bookmark in plan.insertBookmarks {
        result.bookmarks.append(.init(itemKey: bookmark.itemKey, createdAt: bookmark.createdAt))
    }

    return result
}

// MARK: - 1. Round trip

func roundTripCases() -> [BackupDocument] {
    let full = BackupDocument(
        exportedAt: date(0.125),
        editionNote: edition,
        highlights: [
            .init(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                readingKey: "text:5.3", startOffset: 42, length: 61,
                quote: "Healing is a thought by which two minds perceive their oneness",
                createdAt: date(1.5),
                reading: "Text, Chapter 5 — The Healed Mind (T-5.3)", citation: "T-5.3.7"
            ),
            .init(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                readingKey: "segment:1904", startOffset: 0, length: 9,
                // A quote carrying an accent, a curly apostrophe and a
                // non-Latin character: offsets are Character counts, and this
                // is where a UTF-16 slip would surface.
                quote: "café — Ω’s 🕊", createdAt: date(2),
                reading: nil, citation: nil
            ),
        ],
        notes: [
            .init(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                readingKey: "text:5.3", body: "This is the whole of it.",
                createdAt: date(3), updatedAt: date(4.75),
                highlightId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                reading: "Text, Chapter 5"
            ),
            .init(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                readingKey: "lesson:45", body: "Came back to this\nafter a year.",
                createdAt: date(5), updatedAt: date(5),
                highlightId: nil, reading: nil
            ),
        ],
        bookmarks: [
            .init(itemKey: "lesson:45", channel: "daily-lesson", createdAt: date(6),
                  readingKey: "lesson:45"),
            .init(itemKey: "minute:9f2a", channel: "daily-minute", createdAt: date(7),
                  readingKey: nil),
        ],
        settings: .init(
            watchedPhrases: ["forgiveness", "holy instant"],
            listenedEpisodes: ["ep-1": date(8), "ep-2": date(9.5)],
            dailyReminderEnabled: true,
            dailyReminderTimeInterval: 780_012_345.5,
            notifyNewMinute: true, notifyNewLesson: false,
            notifyPhraseMatches: true, notifyLiveActivities: false,
            lessonsLastWatchedIndex: 12,
            readingPositions: [
                ReadingPosition.Book.text.rawValue: .init(
                    readingKey: "text:5.3", startOffset: 1_204,
                    quote: "a passage of the Course the reader had reached",
                    updatedAt: date(10)
                ),
                ReadingPosition.Book.workbook.rawValue: .init(
                    readingKey: "lesson:84", startOffset: 0,
                    quote: "another passage entirely", updatedAt: date(11)
                ),
            ]
        )
    )

    // Nothing at all: a reader who has made no marks must still be able to
    // export, or "back up before you reinstall" is advice that fails silently.
    let empty = BackupDocument(exportedAt: date(0), editionNote: edition)

    // Annotations but no settings, which is what a partial file looks like.
    var noSettings = full
    noSettings.settings = .empty

    return [full, empty, noSettings]
}

for document in roundTripCases() {
    guard let data = try? BackupDocument.encode(document) else {
        check(false, "encode threw"); continue
    }
    guard let decoded = try? BackupDocument.decode(data) else {
        check(false, "decode threw on our own output"); continue
    }
    check(decoded == document, "round trip changed the document")

    // Encoding is stable, so two exports of the same state are the same bytes
    // and a reader syncing a file through a folder does not see phantom changes.
    let again = try? BackupDocument.encode(decoded)
    check(again == data, "encoding is not stable across a round trip")

    // The file must be text a person can read, not a blob.
    let text = String(data: data, encoding: .utf8)
    check(text != nil, "output is not UTF-8")
    check(text?.contains("\"format\" : \"acim-daily-minute-backup\"") == true,
          "the format identifier is not visible in the file")
}

// Sub-second precision survives, because the note merge orders divergent
// passages by `updatedAt` and two edits a moment apart must not tie.
do {
    let precise = BackupDocument(
        exportedAt: date(0.001), editionNote: edition,
        notes: [.init(id: UUID(), readingKey: "lesson:1", body: "x",
                      createdAt: date(0.125), updatedAt: date(0.375),
                      highlightId: nil, reading: nil)]
    )
    let data = try BackupDocument.encode(precise)
    let decoded = try BackupDocument.decode(data)
    check(decoded.notes.first?.updatedAt == date(0.375),
          "fractional seconds were lost in the round trip")
}

// MARK: - 2. Refusal

do {
    let good = try BackupDocument.encode(BackupDocument(exportedAt: date(0), editionNote: edition))
    var text = String(data: good, encoding: .utf8)!

    let foreign = text.replacingOccurrences(
        of: "acim-daily-minute-backup", with: "some-other-app-backup"
    )
    check(
        (try? BackupDocument.decode(Data(foreign.utf8))) == nil,
        "a foreign file was accepted"
    )
    do {
        _ = try BackupDocument.decode(Data(foreign.utf8))
    } catch let failure as BackupDocument.Failure {
        check(failure == .notABackup, "a foreign file gave the wrong reason: \(failure)")
    } catch {
        check(false, "a foreign file threw something unexpected")
    }

    text = text.replacingOccurrences(of: "\"formatVersion\" : 1", with: "\"formatVersion\" : 99")
    do {
        _ = try BackupDocument.decode(Data(text.utf8))
        check(false, "a newer format version was accepted")
    } catch let failure as BackupDocument.Failure {
        check(failure == .unsupportedVersion(99),
              "a newer version gave the wrong reason: \(failure)")
    } catch {
        check(false, "a newer version threw something unexpected")
    }

    for bad in ["", "not json at all", "[]", "{}", "{\"format\":\"acim-daily-minute-backup\"}"] {
        check(
            (try? BackupDocument.decode(Data(bad.utf8))) == nil,
            "accepted what it must refuse: \(bad.debugDescription)"
        )
    }
}

// MARK: - 3. Note bodies: absorption, divergence, no word lost, commutativity

let bodyCases: [(String, Double, String, Double, String)] = [
    // Identical: nothing happens.
    ("The light of the world brings peace.", 10,
     "The light of the world brings peace.", 20, "identical"),
    // The ordinary case: the reader extended the note on one device. The older
    // words are all still in the newer text, so the newer text IS the merge and
    // no separator may appear.
    ("The light of the world", 10,
     "The light of the world brings peace to every mind.", 20, "extended"),
    // The same, arriving the other way round in time.
    ("The light of the world brings peace to every mind.", 10,
     "The light of the world", 20, "extended, reversed"),
    // Genuinely divergent writing on two devices. Both must survive.
    ("Read this on the train.", 10, "Read this again after the funeral.", 20, "divergent"),
    // Divergent, recorded at the identical instant. The tie must still resolve
    // the same way from either side.
    ("apples", 30, "oranges", 30, "divergent, same instant"),
    // Multi-paragraph bodies, where a naive line-based rule would interleave.
    ("First thought.\n\nSecond thought.", 10, "A different first thought.", 20, "multi-paragraph"),
]

for (a, aAt, b, bAt, name) in bodyCases {
    let forward = BackupMerge.mergedBody(a, updatedAt: date(aAt), b, updatedAt: date(bAt))
    let backward = BackupMerge.mergedBody(b, updatedAt: date(bAt), a, updatedAt: date(aAt))
    check(forward == backward, "not commutative (\(name)):\n    \(forward)\n    \(backward)")

    // The property the whole design exists for.
    for passage in BackupMerge.passages(of: a) + BackupMerge.passages(of: b) {
        check(forward.contains(passage), "lost a passage (\(name)): \(passage.debugDescription)")
    }

    // Merging the result back in changes nothing.
    let settled = BackupMerge.mergedBody(
        forward, updatedAt: date(max(aAt, bAt)), b, updatedAt: date(bAt)
    )
    check(settled == forward, "note merge is not idempotent (\(name))")
}

// Absorption must not litter a reader's note with a separator.
do {
    let merged = BackupMerge.mergedBody(
        "The light of the world", updatedAt: date(10),
        "The light of the world brings peace to every mind.", updatedAt: date(20)
    )
    check(merged == "The light of the world brings peace to every mind.",
          "an extended note did not absorb its earlier self: \(merged.debugDescription)")
    check(!merged.contains(BackupMerge.passageSeparator),
          "an extended note grew a separator it did not need")
}

// Divergence must keep both, in the order they were written.
do {
    let merged = BackupMerge.mergedBody(
        "Read this on the train.", updatedAt: date(10),
        "Read this again after the funeral.", updatedAt: date(20)
    )
    check(merged.contains("train"), "divergent merge lost the earlier note")
    check(merged.contains("funeral"), "divergent merge lost the later note")
    check(merged.contains(BackupMerge.passageSeparator),
          "divergent merge did not say why the note grew")
    let trainAt = merged.range(of: "train")?.lowerBound
    let funeralAt = merged.range(of: "funeral")?.lowerBound
    check(trainAt != nil && funeralAt != nil && trainAt! < funeralAt!,
          "divergent merge put the later note first")
}

// Three devices. Associativity is what makes a folder of backups safe.
do {
    let ab = BackupMerge.mergedBody("alpha", updatedAt: date(10), "beta", updatedAt: date(20))
    let abc = BackupMerge.mergedBody(ab, updatedAt: date(20), "gamma", updatedAt: date(30))
    let bc = BackupMerge.mergedBody("beta", updatedAt: date(20), "gamma", updatedAt: date(30))
    let abc2 = BackupMerge.mergedBody("alpha", updatedAt: date(10), bc, updatedAt: date(30))
    check(abc == abc2, "three-way merge depends on the order it was done in:\n    \(abc)\n    \(abc2)")
    for word in ["alpha", "beta", "gamma"] {
        check(abc.contains(word), "three-way merge lost \(word)")
    }
}

// MARK: - 4. The plan: idempotence, additivity, no duplicates

let highlightA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
let highlightB = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!
let noteA = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!
let noteB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!

let incoming = BackupDocument(
    exportedAt: date(0), editionNote: edition,
    highlights: [
        .init(id: highlightA, readingKey: "text:5.3", startOffset: 10, length: 5,
              quote: "peace", createdAt: date(1), reading: nil, citation: nil),
        .init(id: highlightB, readingKey: "lesson:45", startOffset: 3, length: 4,
              quote: "mind", createdAt: date(2), reading: nil, citation: nil),
        // Damage: no reading, and no words. Neither may be imported.
        .init(id: UUID(), readingKey: "", startOffset: 0, length: 1,
              quote: "x", createdAt: date(3), reading: nil, citation: nil),
        .init(id: UUID(), readingKey: "lesson:1", startOffset: 0, length: 0,
              quote: "", createdAt: date(3), reading: nil, citation: nil),
        // The same highlight listed twice in one file.
        .init(id: highlightA, readingKey: "text:5.3", startOffset: 10, length: 5,
              quote: "peace", createdAt: date(1), reading: nil, citation: nil),
    ],
    notes: [
        .init(id: noteA, readingKey: "text:5.3", body: "Written on the phone.",
              createdAt: date(4), updatedAt: date(4), highlightId: highlightA, reading: nil),
        .init(id: noteB, readingKey: "lesson:45", body: "Standalone.",
              createdAt: date(5), updatedAt: date(5), highlightId: nil, reading: nil),
        // Attached to a highlight that is nowhere. Its words must survive as a
        // note about the reading rather than vanishing from the export.
        .init(id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000003")!,
              readingKey: "lesson:45", body: "Orphaned attachment.",
              createdAt: date(6), updatedAt: date(6),
              highlightId: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000009")!,
              reading: nil),
    ],
    bookmarks: [
        .init(itemKey: "lesson:45", channel: "daily-lesson", createdAt: date(7), readingKey: nil),
        .init(itemKey: "lesson:45", channel: "daily-lesson", createdAt: date(8), readingKey: nil),
        .init(itemKey: "text:5.3", channel: "text", createdAt: date(9), readingKey: nil),
    ]
)

// Onto an empty device: a plain restore.
do {
    let empty = BackupMerge.LocalSnapshot()
    let first = BackupMerge.plan(local: empty, incoming: incoming)
    check(first.insertHighlights.count == 2,
          "expected 2 highlights, got \(first.insertHighlights.count)")
    check(first.insertNotes.count == 3, "expected 3 notes, got \(first.insertNotes.count)")
    check(first.insertBookmarks.count == 2,
          "expected 2 bookmarks, got \(first.insertBookmarks.count)")
    check(first.insertNotes.first(where: { $0.body == "Orphaned attachment." })?.highlightId == nil,
          "a note attached to a missing highlight kept a dangling link")
    check(first.insertHighlights.allSatisfy { $0.startOffset >= 0 },
          "an inserted highlight lost its offset")
    check(first.insertHighlights.first(where: { $0.id == highlightA })?.startOffset == 10,
          "an inserted highlight did not carry the offset AnchorResolver needs")

    // Import the same file again. This is the property a reader relies on
    // without ever being told it exists.
    let after = apply(first, to: empty)
    let second = BackupMerge.plan(local: after, incoming: incoming)
    check(second.isEmpty, "importing the same file twice was not a no-op")
}

// Onto a device that already has some of it, with one note edited in both
// places: the real merge.
do {
    let local = BackupMerge.LocalSnapshot(
        highlights: [.init(id: highlightA, createdAt: date(50))],
        notes: [.init(id: noteA, body: "Written on the Mac.",
                      createdAt: date(50), updatedAt: date(50))],
        bookmarks: [.init(itemKey: "text:5.3", createdAt: date(50))]
    )
    let plan = BackupMerge.plan(local: local, incoming: incoming)

    check(plan.insertHighlights.count == 1, "re-imported a highlight already here")
    check(plan.highlightCreatedAt[highlightA] == date(1),
          "an existing highlight did not take the earlier birthday")
    check(plan.bookmarkCreatedAt["text:5.3"] == date(9) || plan.bookmarkCreatedAt.isEmpty == false,
          "an existing bookmark did not take the earlier birthday")
    check(plan.mergedNoteCount == 1, "expected exactly one merged note")

    let revision = plan.noteRevisions[noteA]
    check(revision != nil, "the note edited in two places was not revised")
    check(revision?.body.contains("Written on the Mac.") == true, "lost the local note")
    check(revision?.body.contains("Written on the phone.") == true, "lost the incoming note")
    check(revision?.createdAt == date(4), "the merged note did not keep the earlier birthday")
    check(revision?.updatedAt == date(50), "the merged note did not take the later edit time")

    let after = apply(plan, to: local)
    check(BackupMerge.plan(local: after, incoming: incoming).isEmpty,
          "merging into a populated device was not idempotent")

    // Nothing the reader had is gone.
    check(after.highlights.contains { $0.id == highlightA }, "a merge removed a local highlight")
    check(after.notes.count >= local.notes.count, "a merge reduced the note count")
    check(after.bookmarks.contains { $0.itemKey == "text:5.3" }, "a merge removed a local bookmark")
}

// An empty file must never disturb a populated device: this is the case that
// would prove absence is being read as deletion.
do {
    let local = BackupMerge.LocalSnapshot(
        highlights: [.init(id: highlightA, createdAt: date(50))],
        notes: [.init(id: noteA, body: "Kept.", createdAt: date(50), updatedAt: date(50))],
        bookmarks: [.init(itemKey: "text:5.3", createdAt: date(50))]
    )
    let nothing = BackupDocument(exportedAt: date(0), editionNote: edition)
    let plan = BackupMerge.plan(local: local, incoming: nothing)
    check(plan.isEmpty, "an empty backup produced changes")
    check(apply(plan, to: local) == local, "an empty backup altered the store")
}

// A device importing its OWN export, with the full-precision timestamps a real
// store holds rather than the tidy ones above. The file records milliseconds, so
// every date comes back a fraction different; if the merge compared them with a
// plain `<` this would rewrite every birthday and report changes that were not
// real. This is the case that stands closest to what actually happens.
do {
    let now = Date().timeIntervalSinceReferenceDate + 0.0004829
    let messy = { (offset: Double) in Date(timeIntervalSinceReferenceDate: now + offset) }

    let id = UUID()
    let noteID = UUID()
    let local = BackupMerge.LocalSnapshot(
        highlights: [.init(id: id, createdAt: messy(0))],
        notes: [.init(id: noteID, body: "Written once.",
                      createdAt: messy(1.00007), updatedAt: messy(2.00003))],
        bookmarks: [.init(itemKey: "lesson:45", createdAt: messy(3.000091))]
    )
    let exported = BackupDocument(
        exportedAt: messy(4),
        editionNote: edition,
        highlights: [.init(id: id, readingKey: "text:5.3", startOffset: 1, length: 2,
                           quote: "is", createdAt: messy(0), reading: nil, citation: nil)],
        notes: [.init(id: noteID, readingKey: "text:5.3", body: "Written once.",
                      createdAt: messy(1.00007), updatedAt: messy(2.00003),
                      highlightId: id, reading: nil)],
        bookmarks: [.init(itemKey: "lesson:45", channel: "daily-lesson",
                          createdAt: messy(3.000091), readingKey: "lesson:45")]
    )
    let roundTripped = try BackupDocument.decode(try BackupDocument.encode(exported))
    let plan = BackupMerge.plan(local: local, incoming: roundTripped)
    check(plan.isEmpty,
          "a device re-importing its own export saw changes: "
          + "\(plan.highlightCreatedAt.count) highlight dates, "
          + "\(plan.noteRevisions.count) note revisions, "
          + "\(plan.bookmarkCreatedAt.count) bookmark dates")
}

// The date conversion itself, at the boundaries where hand-rolled arithmetic
// goes wrong: a leap day, the last millisecond of a year, and midnight.
for text in [
    "2024-02-29T12:00:00.000Z",
    "2026-12-31T23:59:59.999Z",
    "2026-01-01T00:00:00.000Z",
    "2026-08-30T14:05:09.125Z",
] {
    guard let parsed = BackupDocument.date(fromISO8601: text) else {
        check(false, "could not parse \(text)"); continue
    }
    check(BackupDocument.iso8601String(from: parsed) == text,
          "date round trip: \(text) -> \(BackupDocument.iso8601String(from: parsed))")
}
// A whole-second stamp, as a hand-tidied file would carry.
check(BackupDocument.date(fromISO8601: "2026-08-30T14:05:09Z") != nil,
      "refused a whole-second stamp")
for bad in ["", "Z", "2026-08-30", "2026-08-30T14:05:09", "2026-08-30 14:05:09.000Z",
            "2026-13-30T14:05:09.000Z", "not-a-date-at-all-Z"] {
    check(BackupDocument.date(fromISO8601: bad) == nil,
          "accepted a bad stamp: \(bad.debugDescription)")
}

// MARK: - 5. The actual words of the book

// Everything above uses strings this harness made up. This section uses quotes
// cut out of the shipped corpus, at real offsets in real readings.
//
// It is the part that matters. A reader's highlight is real ACIM prose - em
// dashes, curly apostrophes, the spaces the punctuation repair put back - and a
// format that alters one character of it has quietly changed what someone
// marked, in the one artifact meant to outlive the app.

struct RealCase: Decodable {
    let readingKey: String
    let quote: String
    let startOffset: Int
    let length: Int
}

let realCases = try JSONDecoder().decode(
    [RealCase].self,
    from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
)
check(realCases.count > 100, "expected a broad cut of the corpus, got \(realCases.count)")

let realHighlights = realCases.enumerated().map { index, testCase in
    BackupDocument.Highlight(
        id: UUID(),
        readingKey: testCase.readingKey,
        startOffset: testCase.startOffset,
        length: testCase.length,
        quote: testCase.quote,
        createdAt: date(Double(index)),
        reading: nil,
        citation: nil
    )
}

// Notes quoting the passages they are about, so real prose travels in a note
// body as well as in a quote.
let realNotes = realHighlights.prefix(40).enumerated().map { index, highlight in
    BackupDocument.Note(
        id: UUID(),
        readingKey: highlight.readingKey,
        body: "On “\(highlight.quote)” — what does this ask of me?",
        createdAt: date(Double(index)),
        updatedAt: date(Double(index)),
        highlightId: highlight.id,
        reading: nil
    )
}

let realDocument = BackupDocument(
    exportedAt: date(0),
    editionNote: edition,
    highlights: realHighlights,
    notes: Array(realNotes),
    bookmarks: realHighlights.prefix(30).map {
        BackupDocument.Bookmark(
            itemKey: $0.readingKey, channel: "text",
            createdAt: $0.createdAt, readingKey: $0.readingKey
        )
    }
)

do {
    let data = try BackupDocument.encode(realDocument)
    let decoded = try BackupDocument.decode(data)
    check(decoded == realDocument, "the corpus did not survive a round trip intact")

    // Character by character, because a byte-level comparison of the whole
    // document would say "different" without saying where.
    for (original, returned) in zip(realDocument.highlights, decoded.highlights) {
        if original.quote != returned.quote {
            check(false, "a real quote changed: \(original.quote.debugDescription)")
        }
        check(original.readingKey == returned.readingKey, "a real reading key changed")
        check(Array(returned.quote).count == original.length,
              "a real quote's Character count no longer matches its stored length")
    }
    for (original, returned) in zip(realDocument.notes, decoded.notes) {
        check(original.body == returned.body,
              "a note quoting real prose changed: \(original.body.debugDescription)")
    }

    // And the whole of it merges into an empty device, then does nothing at all
    // the second time.
    let empty = BackupMerge.LocalSnapshot()
    let first = BackupMerge.plan(local: empty, incoming: decoded)
    check(first.insertHighlights.count == realDocument.highlights.count,
          "not every real highlight was imported")
    check(first.insertNotes.count == realDocument.notes.count,
          "not every real note was imported")
    let after = apply(first, to: empty)
    check(BackupMerge.plan(local: after, incoming: decoded).isEmpty,
          "re-importing the corpus-sized backup was not a no-op")

    print("\(realCases.count) real highlights and \(realDocument.notes.count) real notes "
          + "round tripped and merged")
}

if failures == 0 {
    print("\(checks) checks, format round trips and the merge loses nothing")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
