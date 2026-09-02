import Foundation
import SwiftData

/// Create, read and delete a reader's highlights and notes.
///
/// Every read re-anchors: a highlight is resolved against the text as it stands
/// now, a drifted range is corrected and saved, and a quote that cannot be found
/// is flagged rather than deleted. A reader's mark is never thrown away because
/// the publisher moved a comma.
@MainActor
enum AnnotationStore {
    // MARK: - Highlights

    /// Highlights for one reading, re-anchored against what the reader is
    /// looking at right now and returned in reading order.
    ///
    /// `display` must be `ReadingText.displayString(from:)` of the same reading.
    /// Any other string silently produces wrong offsets.
    static func highlights(
        for key: ReadingKey,
        displayString display: String,
        in context: ModelContext
    ) -> [Highlight] {
        reanchor(key, displayString: display, in: context)
        return highlightsRaw(key.rawValue, in: context)
            .sorted { ($0.startOffset, $0.createdAt) < ($1.startOffset, $1.createdAt) }
    }

    /// Corrects stored offsets against the text as it stands now, saving what
    /// moved and flagging what can no longer be found.
    ///
    /// Separate from reading so a view can re-anchor once when it appears rather
    /// than writing to the store from inside its own body.
    static func reanchor(
        _ key: ReadingKey,
        displayString display: String,
        in context: ModelContext
    ) {
        let fetched = highlightsRaw(key.rawValue, in: context)
        var changed = false
        for highlight in fetched {
            let resolution = AnchorResolver.resolve(
                startOffset: highlight.startOffset,
                length: highlight.length,
                quote: highlight.quote,
                in: display
            )

            // A quote stored before the spacing repair still reads
            // `planned.We must`. Writing the repaired form back once it has been
            // found again is what keeps the Saved tab's rows, the note editor's
            // quoted passage and the plain-text export reading like the page —
            // none of which needs a change of its own. Only on a successful
            // resolution: an orphan's quote is the only record of what the
            // reader marked.
            if resolution != .orphaned {
                let repaired = PunctuationSpacing.repaired(highlight.quote)
                if repaired != highlight.quote {
                    highlight.quote = repaired
                    changed = true
                }
            }

            switch resolution {
            case .exact:
                // A publisher reverting an edit brings an orphan back.
                if highlight.isOrphaned {
                    highlight.isOrphaned = false
                    changed = true
                }
            case .moved(let range):
                highlight.startOffset = range.lowerBound
                highlight.length = range.count
                highlight.isOrphaned = false
                changed = true
            case .orphaned:
                if !highlight.isOrphaned {
                    highlight.isOrphaned = true
                    changed = true
                }
            }
        }
        // A repaired quote or a moved offset is what the backup file carries,
        // so the folder copy follows it — but only when something moved, since
        // this runs every time a reading opens.
        if changed { FolderCopyService.noteChange(in: context) }
    }

    /// Every highlight the reader has made, newest first. For the Saved tab.
    static func allHighlights(in context: ModelContext) -> [Highlight] {
        (try? context.fetch(
            FetchDescriptor<Highlight>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []
    }

    @discardableResult
    static func addHighlight(
        readingKey: ReadingKey,
        range: Range<Int>,
        quote: String,
        in context: ModelContext
    ) -> Highlight? {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, range.lowerBound >= 0, !range.isEmpty else { return nil }

        let raw = readingKey.rawValue
        let existing = highlightsRaw(raw, in: context).first {
            $0.startOffset == range.lowerBound && $0.length == range.count
        }
        if let existing { return existing }

        let highlight = Highlight()
        highlight.readingKey = raw
        highlight.startOffset = range.lowerBound
        highlight.length = range.count
        highlight.quote = quote
        context.insert(highlight)
        FolderCopyService.noteChange(in: context)
        return highlight
    }

    /// Deleting a mark must never take the reader's writing with it. A note that
    /// pointed at this highlight becomes a note about the reading.
    static func delete(_ highlight: Highlight, in context: ModelContext) {
        let id = highlight.id
        let attached = (try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.highlightID == id })
        )) ?? []
        for note in attached { note.highlightID = nil }
        context.delete(highlight)
        FolderCopyService.noteChange(in: context)
    }

    // MARK: - Notes

    static func notes(for key: ReadingKey, in context: ModelContext) -> [Note] {
        let raw = key.rawValue
        let fetched = (try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.readingKey == raw })
        )) ?? []
        return fetched.sorted { $0.createdAt < $1.createdAt }
    }

    static func allNotes(in context: ModelContext) -> [Note] {
        (try? context.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []
    }

    @discardableResult
    static func addNote(
        readingKey: ReadingKey,
        body: String,
        highlightID: UUID? = nil,
        in context: ModelContext
    ) -> Note? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let note = Note()
        note.readingKey = readingKey.rawValue
        note.body = trimmed
        note.highlightID = highlightID
        context.insert(note)
        FolderCopyService.noteChange(in: context)
        return note
    }

    /// Editing keeps the note's birthday and moves only its last-touched time.
    static func update(_ note: Note, body: String, in context: ModelContext) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != note.body else { return }
        note.body = trimmed
        note.updatedAt = Date()
        FolderCopyService.noteChange(in: context)
    }

    static func delete(_ note: Note, in context: ModelContext) {
        context.delete(note)
        FolderCopyService.noteChange(in: context)
    }

    // MARK: - Growing a date key up into a corpus key

    /// Rewrites `minute-date:<date>` keys to `segment:<id>` once the mapping is
    /// known. Idempotent and cheap, so it is safe to call on launch.
    ///
    /// Rewritten in place rather than resolved at read time: the alternative
    /// pays a lookup on every read forever to preserve an audit trail no reader
    /// will ever ask for. An annotation made on an archived minute ends up
    /// anchored to the permanent bundled corpus, like every other one.
    static func upgradeDateKeys(in context: ModelContext) {
        let media = (try? context.fetch(FetchDescriptor<SegmentMedia>())) ?? []
        var segmentByDate: [String: Int] = [:]
        for row in media where row.segmentId > 0 && !row.publishedDate.isEmpty {
            segmentByDate[row.publishedDate] = row.segmentId
        }
        guard !segmentByDate.isEmpty else { return }

        let prefix = "minute-date:"
        for highlight in allHighlights(in: context) where highlight.readingKey.hasPrefix(prefix) {
            let date = String(highlight.readingKey.dropFirst(prefix.count))
            if let id = segmentByDate[date] {
                highlight.readingKey = ReadingKey.segment(id).rawValue
            }
        }
        for note in allNotes(in: context) where note.readingKey.hasPrefix(prefix) {
            let date = String(note.readingKey.dropFirst(prefix.count))
            if let id = segmentByDate[date] {
                note.readingKey = ReadingKey.segment(id).rawValue
            }
        }
    }

    private static func highlightsRaw(_ raw: String, in context: ModelContext) -> [Highlight] {
        (try? context.fetch(
            FetchDescriptor<Highlight>(predicate: #Predicate { $0.readingKey == raw })
        )) ?? []
    }
}
