import Foundation

/// The file a reader carries their own work in.
///
/// There is no server and no account here, so nothing can ever re-send a reader
/// what they wrote. `AnnotationExport.plainText` already gets it out as prose a
/// person can read; this gets it out in a form that can be read back, so work
/// made on one machine can be continued on another.
///
/// Plain JSON with a `.json` extension, deliberately — not a private extension
/// and not a private UTI. The point of this file is that a Windows, Linux or
/// Android machine opens it with what it already has. A format only this app
/// could read would recreate the trap it exists to prevent.
///
/// A pure value type: no SwiftData, no SwiftUI, no `Bundle`, no `CorpusService`.
/// `tools/verify_backup.sh` compiles this file and `BackupMerge.swift` with
/// nothing else, and that compiling at all is what keeps the promise true.
struct BackupDocument: Codable, Equatable, Sendable {
    /// Written into every file and required on the way back in. A reader picking
    /// a file out of a folder of JSON should get a clear refusal, not a partial
    /// import of something else.
    static let formatIdentifier = "acim-daily-minute-backup"
    static let currentVersion = 1

    enum Failure: LocalizedError, Equatable {
        /// Valid JSON, but not one of ours.
        case notABackup
        /// Ours, but written by a later version of the app than this one.
        case unsupportedVersion(Int)
        /// Not readable as JSON at all, or ours but structurally broken.
        case unreadable

        var errorDescription: String? {
            switch self {
            case .notABackup:
                "That file is not an ACIM Daily Minute backup."
            case .unsupportedVersion(let version):
                "That backup was written by a newer version of the app (format \(version)). "
                + "Update the app and try again."
            case .unreadable:
                "That backup could not be read."
            }
        }
    }

    var format: String
    var formatVersion: Int
    var exportedAt: Date
    /// Which book the citations below point into, carried verbatim from
    /// `AnnotationExport.editionNote`.
    ///
    /// The citations in this file are not the ones of the widely-cited edition,
    /// and a stranger opening it years from now has no other way to learn that.
    var editionNote: String
    var highlights: [Highlight]
    var notes: [Note]
    var bookmarks: [Bookmark]
    var settings: Settings

    /// A passage the reader marked.
    ///
    /// `startOffset` and `length` are `Character` counts into
    /// `ReadingText.displayString(from:)` — never UTF-16 units.
    ///
    /// ⛔ They are carried even though the receiving device recomputes the
    /// position. `AnchorResolver` chooses among repeated occurrences of a quote
    /// by proximity to the stored offset, and the Course repeats itself
    /// constantly; an imported mark arriving without its offset would settle on
    /// the first occurrence, which is very often a different chapter.
    struct Highlight: Codable, Equatable, Sendable {
        var id: UUID
        var readingKey: String
        var startOffset: Int
        var length: Int
        var quote: String
        var createdAt: Date
        /// Written for a person, never read back. See `Decoration`.
        var reading: String?
        /// Written for a person, never read back. See `Decoration`.
        var citation: String?
    }

    /// Something the reader wrote.
    struct Note: Codable, Equatable, Sendable {
        var id: UUID
        var readingKey: String
        var body: String
        var createdAt: Date
        var updatedAt: Date
        /// The highlight this note is about, if it is about one rather than
        /// about the whole reading.
        var highlightId: UUID?
        /// Written for a person, never read back. See `Decoration`.
        var reading: String?
    }

    /// A reading the reader saved.
    struct Bookmark: Codable, Equatable, Sendable {
        var itemKey: String
        var channel: String
        var createdAt: Date
        /// The positional key for this reading where the exporting device could
        /// work one out.
        ///
        /// `itemKey` for a Daily Minute folds the body text into a hash, so two
        /// devices holding slightly different text for the same passage compute
        /// different keys and the bookmark would arrive as a second bookmark.
        /// An importer prefers this field and translates it to whatever
        /// `itemKey` it would use itself.
        var readingKey: String?
    }

    /// Everything the reader chose that is not an annotation.
    ///
    /// Every field is optional so an exporter writes only what exists and an
    /// importer skips what is absent. That is also how this format grows: a
    /// later version adds a key, and older versions ignore it. Nothing is ever
    /// written as a placeholder for something that does not exist yet.
    struct Settings: Codable, Equatable, Sendable {
        var watchedPhrases: [String]?
        var listenedEpisodes: [String: Date]?
        var dailyReminderEnabled: Bool?
        var dailyReminderTimeInterval: Double?
        var notifyNewMinute: Bool?
        var notifyNewLesson: Bool?
        var notifyPhraseMatches: Bool?
        var notifyLiveActivities: Bool?
        var lessonsLastWatchedIndex: Int?
        /// The reader's ribbons, book → position.
        ///
        /// Where a reader got to is theirs and nothing can recompute it, which
        /// is the whole test for what belongs in this file. It is also the one
        /// key here that **merges**: two devices' ribbons for one book resolve
        /// to the later of them, so it moves on an ordinary import rather than
        /// waiting for the reader to ask for their settings back.
        var readingPositions: [String: ReadingPosition]?

        static let empty = Settings()
    }

    /// ⛔ `Highlight.reading`, `Highlight.citation` and `Note.reading` are
    /// **written for a human and never read back.**
    ///
    /// They exist so the file reads as a document rather than as a table of
    /// identifiers — someone opening it in Notepad on a machine that never ran
    /// this app can see which passage each mark belongs to and where it sits in
    /// the book. Nothing merges them, nothing validates them, and nothing may
    /// come to depend on them: they are a snapshot of how one device named a
    /// reading on one day, and the receiving device derives its own.
    enum Decoration {}

    init(
        exportedAt: Date,
        editionNote: String,
        highlights: [Highlight] = [],
        notes: [Note] = [],
        bookmarks: [Bookmark] = [],
        settings: Settings = .empty
    ) {
        self.format = Self.formatIdentifier
        self.formatVersion = Self.currentVersion
        self.exportedAt = exportedAt
        self.editionNote = editionNote
        self.highlights = highlights
        self.notes = notes
        self.bookmarks = bookmarks
        self.settings = settings
    }
}

// MARK: - Reading and writing

extension BackupDocument {
    /// The resolution this format records time at: one millisecond.
    ///
    /// ⛔ Stated rather than left implicit, because `BackupMerge` compares at
    /// the same resolution. A file that recorded less precision than the merge
    /// compared with would make a device importing its own export look like a
    /// change every single time, and a reader syncing through a folder would
    /// see their notes touched by an import that did nothing.
    static let timeResolution: TimeInterval = 0.001

    /// Dates are written as ISO-8601 in UTC with milliseconds —
    /// `2026-08-30T14:05:09.125Z`.
    ///
    /// Fractional seconds are not decoration: a note's `updatedAt` is what the
    /// merge orders divergent passages by, and two edits a moment apart must
    /// not collapse into a tie.
    ///
    /// Built from `Calendar` arithmetic rather than an `ISO8601DateFormatter`
    /// on purpose. A formatter is a reference type Foundation does not call
    /// `Sendable`, so holding one would either make this file main-actor-bound
    /// or force a concurrency escape hatch — and this file has to stay a pure
    /// value type that a command-line harness can drive.
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static func iso8601String(from date: Date) -> String {
        // Split whole seconds from milliseconds before asking Calendar
        // anything, so the components come from an exact integer second and no
        // rounding can push a date into the next one.
        let totalMilliseconds = (date.timeIntervalSince1970 * 1000).rounded()
        let seconds = (totalMilliseconds / 1000).rounded(.down)
        let milliseconds = Int(totalMilliseconds - seconds * 1000)
        let whole = Date(timeIntervalSince1970: seconds)

        let parts = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: whole
        )
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
            parts.year ?? 0, parts.month ?? 1, parts.day ?? 1,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, milliseconds
        )
    }

    /// Reads back what `iso8601String` writes, and also accepts a whole-second
    /// stamp so a file someone tidied by hand still imports.
    static func date(fromISO8601 text: String) -> Date? {
        let characters = Array(text)
        guard characters.count >= 20, characters.last == "Z" else { return nil }

        func number(_ range: Range<Int>) -> Int? { Int(String(characters[range])) }
        guard characters[4] == "-", characters[7] == "-", characters[10] == "T",
              characters[13] == ":", characters[16] == ":",
              let year = number(0..<4), let month = number(5..<7), let day = number(8..<10),
              let hour = number(11..<13), let minute = number(14..<16),
              let second = number(17..<19)
        else { return nil }

        var milliseconds = 0
        if characters.count > 20 {
            guard characters[19] == "." else { return nil }
            let fraction = String(characters[20..<(characters.count - 1)])
            guard !fraction.isEmpty, fraction.allSatisfy(\.isWholeNumber),
                  let value = Int((fraction + "000").prefix(3))
            else { return nil }
            milliseconds = value
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        let calendar = utcCalendar
        guard let base = calendar.date(from: components) else { return nil }

        // ⛔ `Calendar` does not reject an out-of-range component, it rolls it
        // over: month 13 becomes January of the next year, and 30 February
        // becomes 1 or 2 March. A stamp is only real if reading the date back
        // gives the same numbers it was written with.
        let readBack = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: base
        )
        guard readBack.year == year, readBack.month == month, readBack.day == day,
              readBack.hour == hour, readBack.minute == minute, readBack.second == second
        else { return nil }

        return base.addingTimeInterval(Double(milliseconds) / 1000)
    }

    static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        // Sorted keys and pretty printing are for the person who opens this in a
        // text editor, and they also make two exports of the same state compare
        // equal as bytes.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(from: date))
        }
        return try encoder.encode(document)
    }

    static func decode(_ data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = self.date(fromISO8601: text) else { throw Failure.unreadable }
            return date
        }

        // The header is read first so a refusal can say which of the three
        // things went wrong. Every field is optional, so this decodes for any
        // JSON object and fails only for JSON that is not an object at all.
        struct Header: Decodable {
            let format: String?
            let formatVersion: Int?
        }
        guard let header = try? decoder.decode(Header.self, from: data) else {
            throw Failure.unreadable
        }
        guard header.format == formatIdentifier else { throw Failure.notABackup }
        guard let version = header.formatVersion else { throw Failure.notABackup }
        guard version <= currentVersion else { throw Failure.unsupportedVersion(version) }

        do {
            return try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw Failure.unreadable
        }
    }
}
