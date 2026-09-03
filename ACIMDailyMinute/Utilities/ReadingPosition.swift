import Foundation

/// Where the reader got to in a book — the ribbon a printed copy has and this
/// app did not.
///
/// A pure value: no SwiftUI, no SwiftData, no `UserDefaults`, no `Bundle`, no
/// `CorpusService`, no `Date()`. `tools/verify_reading_position.sh` compiles this
/// file with `ReadingKey.swift`, `AnchorResolver.swift` and
/// `PunctuationSpacing.swift` and nothing else, so the purity is not a
/// convention anyone has to remember: breaking it breaks the check.
///
/// ⛔ **This is not a `ReadingSpotlight`, and the two must not be conflated.** A
/// spotlight is a pointer that is never stored, never exported and never keyed,
/// and it *paints*. This is stored, it travels in the reader's backup, and it
/// scrolls without marking anything — a reader's place is not a reader's mark.
struct ReadingPosition: Codable, Equatable, Sendable {
    /// How many characters of the reading are kept alongside the offset.
    ///
    /// ⛔ Not decoration and not a guess. A stored offset alone cannot survive a
    /// corpus repair — the punctuation-spacing repair moved 6,221 of them — so
    /// the place is found again by its words, exactly as a highlight is. 120 was
    /// measured over the shipped bundle rather than chosen: a 120-character cut
    /// is unique within its own reading at **all 2,948** Text paragraph starts,
    /// and the 8 of 653 Workbook starts that repeat are a lesson's own refrain,
    /// which `AnchorResolver` settles by proximity to `startOffset`.
    static let quoteLength = 120

    /// The file this travels in records milliseconds, so two devices comparing
    /// the same moment must compare it at that resolution. Full-precision `<`
    /// would make a device re-importing its own backup find every ribbon a
    /// fraction older than the one it holds, and the merge would stop being
    /// commutative — which is the property that lets a folder two machines
    /// write into settle on one answer.
    static let timeResolution: TimeInterval = 0.001

    /// Which of the Course's books a ribbon belongs to.
    ///
    /// One ribbon per book rather than one for the app, because the Course is
    /// three books read in three rhythms — the Text straight through, the
    /// Workbook one lesson a day — and a single ribbon would have each erase the
    /// other. The app already models this: the nav bar names the book.
    enum Book: String, Codable, CaseIterable, Sendable {
        case text
        case workbook
    }

    /// The raw `ReadingKey` — `text:5.3`, `lesson:84`.
    var readingKey: String
    /// A `Character` offset into `ReadingText.displayString(from:)`, never a
    /// UTF-16 unit. Crossing that boundary anywhere but
    /// `SelectableReadingText`'s two conversion helpers shifts every offset
    /// after the first accented character.
    var startOffset: Int
    /// The words at that offset, so the place is found again after the text
    /// under it changes. Empty only for an empty reading.
    var quote: String
    var updatedAt: Date

    // MARK: - Which readings can hold one

    /// The book a key belongs to, or nil where a ribbon would mean nothing.
    ///
    /// ⛔ A Daily Minute is a **day**, not a thread through a book: it is chosen
    /// by the server, it is different tomorrow, and resuming one is not a thing
    /// a reader can want. The Manual is bundled as 105 word-count cuts with no
    /// structure to resume *into*; it joins here when piece E gives it one, and
    /// until then nothing is written as a placeholder for it.
    static func book(for key: ReadingKey) -> Book? {
        switch key {
        case .textSection: .text
        case .lesson: .workbook
        case .segment, .manual, .minuteDate: nil
        }
    }

    var book: Book? {
        ReadingKey(rawValue: readingKey).flatMap(Self.book(for:))
    }

    // MARK: - Making one

    /// A position in `display`, or nil where this reading can hold no ribbon.
    ///
    /// The offset is clamped rather than refused. It arrives from a text view
    /// measuring a live layout, and a reading that is momentarily half-laid-out
    /// should leave the reader at its top, never lose their book entirely.
    static func make(
        key: ReadingKey,
        startOffset: Int,
        in display: String,
        at now: Date
    ) -> ReadingPosition? {
        guard Self.book(for: key) != nil else { return nil }
        let characters = Array(display)
        let clamped = max(0, min(startOffset, characters.count))
        let end = min(clamped + quoteLength, characters.count)
        return ReadingPosition(
            readingKey: key.rawValue,
            startOffset: clamped,
            quote: String(characters[clamped..<end]),
            updatedAt: now
        )
    }

    // MARK: - Finding it again

    /// Where this position lands in the string a screen is actually drawing.
    ///
    /// The screen may draw a different string from the one the position was made
    /// against — a lesson the feed has published draws the feed's text, and a
    /// corpus repair moves the bundle's — so the words are found again with the
    /// same resolver a highlight uses. A position whose words are gone opens the
    /// reading at its top, which is honest: the app no longer knows where the
    /// reader was, and guessing with a stale offset would land them anywhere.
    func offset(in display: String) -> Int {
        guard !quote.isEmpty else { return 0 }
        switch AnchorResolver.resolve(
            startOffset: startOffset,
            length: quote.count,
            quote: quote,
            in: display
        ) {
        case .exact(let range), .moved(let range): return range.lowerBound
        case .orphaned: return 0
        }
    }

    // MARK: - Two devices

    /// True when `self` is the later of two ribbons for one book.
    ///
    /// A total order, not just a date comparison: equal moments fall through to
    /// the reading and then the offset, so the merge below is commutative and
    /// associative even when a reader's two devices stamp the same millisecond.
    func isLater(than other: ReadingPosition) -> Bool {
        let mine = (updatedAt.timeIntervalSinceReferenceDate / Self.timeResolution).rounded()
        let theirs = (other.updatedAt.timeIntervalSinceReferenceDate / Self.timeResolution).rounded()
        if mine != theirs { return mine > theirs }
        if readingKey != other.readingKey { return readingKey > other.readingKey }
        return startOffset > other.startOffset
    }

    /// The union of two devices' ribbons, book by book, keeping the later of
    /// each.
    ///
    /// A merge here has a meaning — the later place is where the reader actually
    /// got to — which is why the ribbon travels with the listened history
    /// rather than with the scalars, where one value has to displace
    /// another and only a reader can say which.
    ///
    /// ⛔ It can never move a book's ribbon backwards, which is the same promise
    /// `BackupMerge` makes about a reader's words: an import may add to what this
    /// device knows and may never take from it.
    static func merged(
        _ mine: [String: ReadingPosition],
        _ theirs: [String: ReadingPosition]
    ) -> [String: ReadingPosition] {
        var result = mine
        for (book, incoming) in theirs {
            guard let existing = result[book] else {
                result[book] = incoming
                continue
            }
            if incoming.isLater(than: existing) { result[book] = incoming }
        }
        return result
    }

    // MARK: - At rest

    /// The stored form: book → position. Keyed by `Book.rawValue` so the shape
    /// on disk and the shape in the backup file are one shape.
    static func decode(_ data: Data) -> [String: ReadingPosition] {
        guard !data.isEmpty,
              let decoded = try? JSONDecoder().decode([String: ReadingPosition].self, from: data)
        else { return [:] }
        // A key no version of this app has ever written is not a book. Dropping
        // it here means a file from a later version, or a hand-edited one,
        // cannot put a ribbon somewhere nothing can open.
        return decoded.filter { Book(rawValue: $0.key) != nil }
    }

    static func encode(_ entries: [String: ReadingPosition]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data()
    }
}
