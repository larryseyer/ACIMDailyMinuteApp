import Foundation

/// Turns a reader's highlights and notes into plain text.
///
/// This is the reason the rest of the feature exists. There is no server and no
/// account, so nothing can ever re-send a reader what they wrote — if it cannot
/// leave the app as text a person can read, it is trapped, and the app is not
/// permanent. Shipped with the feature rather than after it for that reason.
///
/// A pure function: no `ModelContext`, no `Bundle`, no `Date()`. It takes values
/// and returns a string, so a harness can assert the exact output rather than
/// hoping the format still looks right.
enum AnnotationExport {
    /// One highlight, as export sees it. A value type so the format can be
    /// asserted without a SwiftData store.
    struct Entry {
        let key: ReadingKey
        let quote: String
        let startOffset: Int
        let createdAt: Date
        let isOrphaned: Bool
        /// Where the marked passage sits in the book, or nil where the reading
        /// has no addressable form. Resolved in `entries(_:_:)` so `plainText`
        /// stays a pure function whose exact output a harness can assert.
        let citation: String?
        let attachedNotes: [NoteEntry]
    }

    struct NoteEntry {
        let body: String
        let createdAt: Date
    }

    static let header = "A Course in Miracles — my highlights and notes"

    /// Which book the citations below point into.
    ///
    /// ⛔ Load-bearing, and the reason it is stated rather than assumed. This
    /// edition is not the one the familiar `T-1.I.1:1` notation addresses — its
    /// Chapter 1 is "Introduction to Miracles" and it carries 53 miracle
    /// principles rather than 50. A stranger reading this file years from now
    /// needs to know which book to open, and this line is the only place that
    /// can tell them.
    static let editionNote =
        "References like T-5.3.7 are chapter, section and paragraph of the "
        + "edition this app carries — the one whose Text opens with "
        + "\"Introduction to Miracles\" and lists 53 miracle principles. "
        + "W-45.3 is Workbook lesson and paragraph."

    /// The formatter the export reads dates through.
    ///
    /// Taken as a parameter with a long-style default because a harness that
    /// asserts exact output must not be at the mercy of the machine's locale.
    static func longDateFormatter(locale: Locale = Locale(identifier: "en_US_POSIX")) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }

    /// Every annotation, grouped by reading.
    ///
    /// Readings appear in the order the reader first annotated them. Within a
    /// reading, highlights come in reading order and standalone notes follow.
    /// Only the reader's own dates appear: when a reading was published is the
    /// app's bookkeeping and belongs nowhere a reader can see it.
    static func plainText(
        highlights: [Entry],
        standaloneNotesByReading: [(key: ReadingKey, notes: [NoteEntry])] = [],
        corpus: CorpusService = .shared,
        dateFormatter: DateFormatter = longDateFormatter()
    ) -> String {
        var groups: [(key: ReadingKey, earliest: Date, highlights: [Entry], notes: [NoteEntry])] = []

        func index(of key: ReadingKey, firstSeen: Date) -> Int {
            if let found = groups.firstIndex(where: { $0.key == key }) {
                if firstSeen < groups[found].earliest { groups[found].earliest = firstSeen }
                return found
            }
            groups.append((key: key, earliest: firstSeen, highlights: [], notes: []))
            return groups.count - 1
        }

        for entry in highlights.sorted(by: { $0.createdAt < $1.createdAt }) {
            groups[index(of: entry.key, firstSeen: entry.createdAt)].highlights.append(entry)
        }
        for reading in standaloneNotesByReading {
            guard let earliest = reading.notes.map(\.createdAt).min() else { continue }
            let at = index(of: reading.key, firstSeen: earliest)
            groups[at].notes.append(contentsOf: reading.notes)
        }

        var lines: [String] = [header, "", editionNote]
        for group in groups.sorted(by: { $0.earliest < $1.earliest }) {
            lines.append("")
            lines.append(group.key.displayName(corpus: corpus))
            for entry in group.highlights.sorted(by: {
                ($0.startOffset, $0.createdAt) < ($1.startOffset, $1.createdAt)
            }) {
                lines.append("  \"\(entry.quote)\"")
                let cited = entry.citation.map { " · \($0)" } ?? ""
                let marked = entry.isOrphaned ? " (passage not found in the current text)" : ""
                lines.append("    — highlighted \(dateFormatter.string(from: entry.createdAt))\(cited)\(marked)")
                for note in entry.attachedNotes.sorted(by: { $0.createdAt < $1.createdAt }) {
                    lines.append("    Note: \(note.body)")
                    lines.append("      — written \(dateFormatter.string(from: note.createdAt))")
                }
            }
            for note in group.notes.sorted(by: { $0.createdAt < $1.createdAt }) {
                lines.append("  Note: \(note.body)")
                lines.append("    — written \(dateFormatter.string(from: note.createdAt))")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Everything in the store, in export's own value types.
    ///
    /// The only place that touches models, kept to a handful of lines so the
    /// format itself stays testable without one.
    static func entries(
        highlights: [Highlight],
        notes: [Note],
        corpus: CorpusService = .shared
    ) -> (highlights: [Entry], standalone: [(key: ReadingKey, notes: [NoteEntry])]) {
        var notesByHighlight: [UUID: [NoteEntry]] = [:]
        var standaloneByKey: [String: (key: ReadingKey, notes: [NoteEntry])] = [:]

        for note in notes {
            let entry = NoteEntry(body: note.body, createdAt: note.createdAt)
            if let id = note.highlightID {
                notesByHighlight[id, default: []].append(entry)
            } else if let key = ReadingKey(rawValue: note.readingKey) {
                standaloneByKey[note.readingKey, default: (key: key, notes: [])].notes.append(entry)
            }
        }

        let converted = highlights.compactMap { highlight -> Entry? in
            guard let key = ReadingKey(rawValue: highlight.readingKey) else { return nil }
            return Entry(
                key: key,
                quote: highlight.quote,
                startOffset: highlight.startOffset,
                createdAt: highlight.createdAt,
                isOrphaned: highlight.isOrphaned,
                // An orphan's offset no longer points at its words, so citing it
                // would name a paragraph the reader never marked. The quote is
                // the only record left, and it is already printed above.
                citation: highlight.isOrphaned ? nil : CitationResolver.citation(
                    for: key,
                    characterOffset: highlight.startOffset,
                    corpus: corpus
                )?.rawValue,
                attachedNotes: notesByHighlight[highlight.id] ?? []
            )
        }
        return (converted, Array(standaloneByKey.values))
    }
}
