import Foundation

/// Deciding what an imported backup changes, and what it leaves alone.
///
/// ⛔ **The rule this whole file exists to keep: a merge may never make a
/// reader's words fewer.** "Last write wins" fails that outright, which is why
/// it is rejected rather than tuned — it silently discards writing that took
/// someone years to produce and that nothing anywhere can re-send them.
///
/// Each record shape gets the rule its shape actually calls for:
///
/// - **Highlights have no conflict to resolve.** Nothing a reader does after
///   making one changes it; `startOffset`, `length`, `quote` and `isOrphaned`
///   are rewritten only by `AnnotationStore.reanchor`, against the corpus as it
///   stands on that device. So a highlight already present simply stays, and a
///   new one is inserted.
/// - **Notes are the only records a reader edits**, so they are the only place a
///   real conflict can arise. It is resolved by keeping both.
/// - **Bookmarks are a boolean fact** about a reading. Union.
///
/// A pure value type with no SwiftData and no SwiftUI: it takes a snapshot of
/// what is here and a decoded document, and returns a plan someone else applies.
enum BackupMerge {
    // MARK: - What is here

    /// The parts of the local store a merge actually needs. Deliberately not the
    /// models: the merge is arithmetic over values, and keeping it that way is
    /// what lets `tools/verify_backup.sh` drive it.
    struct LocalSnapshot: Equatable, Sendable {
        struct HighlightState: Equatable, Sendable {
            var id: UUID
            var createdAt: Date

            init(id: UUID, createdAt: Date) {
                self.id = id
                self.createdAt = createdAt
            }
        }

        struct NoteState: Equatable, Sendable {
            var id: UUID
            var body: String
            var createdAt: Date
            var updatedAt: Date

            init(id: UUID, body: String, createdAt: Date, updatedAt: Date) {
                self.id = id
                self.body = body
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        struct BookmarkState: Equatable, Sendable {
            var itemKey: String
            var createdAt: Date

            init(itemKey: String, createdAt: Date) {
                self.itemKey = itemKey
                self.createdAt = createdAt
            }
        }

        var highlights: [HighlightState]
        var notes: [NoteState]
        var bookmarks: [BookmarkState]

        init(
            highlights: [HighlightState] = [],
            notes: [NoteState] = [],
            bookmarks: [BookmarkState] = []
        ) {
            self.highlights = highlights
            self.notes = notes
            self.bookmarks = bookmarks
        }
    }

    // MARK: - What to do about it

    /// A new body, birthday and last-touched time for a note that exists on both
    /// sides.
    struct NoteRevision: Equatable, Sendable {
        var body: String
        var createdAt: Date
        var updatedAt: Date
    }

    /// Everything an import will do.
    ///
    /// ⛔ **There is no field here that can express a deletion, and that is the
    /// design rather than an omission.** A backup file is a snapshot, not a log,
    /// so a record's absence from it carries no information at all — it may mean
    /// the reader deleted it, or it may mean the file predates it. Treating
    /// absence as deletion would let a six-month-old file erase six months of
    /// work. Import is strictly additive, and the import screen says so in those
    /// words before the reader taps.
    struct MergePlan: Equatable, Sendable {
        var insertHighlights: [BackupDocument.Highlight] = []
        /// Existing highlights whose birthday should move earlier.
        var highlightCreatedAt: [UUID: Date] = [:]
        var insertNotes: [BackupDocument.Note] = []
        var noteRevisions: [UUID: NoteRevision] = [:]
        var insertBookmarks: [BackupDocument.Bookmark] = []
        /// Existing bookmarks whose birthday should move earlier.
        var bookmarkCreatedAt: [String: Date] = [:]
        /// Notes that existed on both sides and whose text actually grew,
        /// because the same note had been written in two places. Reported to
        /// the reader, who is entitled to know their note is now longer than
        /// they left it.
        var mergedNoteCount: Int = 0

        var isEmpty: Bool {
            insertHighlights.isEmpty
                && highlightCreatedAt.isEmpty
                && insertNotes.isEmpty
                && noteRevisions.isEmpty
                && insertBookmarks.isEmpty
                && bookmarkCreatedAt.isEmpty
        }
    }

    // MARK: - The merge

    static func plan(local: LocalSnapshot, incoming: BackupDocument) -> MergePlan {
        var plan = MergePlan()

        // --- Highlights ---------------------------------------------------
        var highlightsByID: [UUID: LocalSnapshot.HighlightState] = [:]
        for state in local.highlights where highlightsByID[state.id] == nil {
            highlightsByID[state.id] = state
        }
        var insertedHighlightIDs: Set<UUID> = []

        for highlight in incoming.highlights {
            // A row with no reading or no words is not a mark anyone made; it is
            // damage, and importing it would put an undeletable blank in the
            // Saved tab.
            guard !highlight.readingKey.isEmpty, !highlight.quote.isEmpty else { continue }

            if let existing = highlightsByID[highlight.id] {
                // The incoming offsets are dropped. Position is this device's
                // answer about this device's corpus, and `reanchor` gives it
                // whenever the reading is next opened.
                if isEarlier(highlight.createdAt, than: existing.createdAt) {
                    plan.highlightCreatedAt[highlight.id] = highlight.createdAt
                }
            } else if insertedHighlightIDs.insert(highlight.id).inserted {
                // ⛔ Inserted WITH its offsets. `AnchorResolver` picks among
                // repeated occurrences of a quote by proximity to the stored
                // offset; the Course repeats itself constantly, so a mark
                // arriving without one would settle on the first occurrence,
                // very often in a different chapter.
                plan.insertHighlights.append(highlight)
            }
        }

        // --- Notes --------------------------------------------------------
        var notesByID: [UUID: LocalSnapshot.NoteState] = [:]
        for state in local.notes where notesByID[state.id] == nil {
            notesByID[state.id] = state
        }
        var insertedNoteIDs: Set<UUID> = []

        // A note whose highlight is nowhere — not here, and not arriving — would
        // vanish from the plain-text export, which buckets attached notes by
        // their highlight. It becomes a note about the reading instead, which is
        // an ordinary thing for a note to be, and its words survive.
        let knownHighlightIDs = Set(highlightsByID.keys).union(insertedHighlightIDs)

        for note in incoming.notes {
            let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty, !note.readingKey.isEmpty else { continue }

            if let existing = notesByID[note.id] {
                let merged = mergedBody(
                    existing.body, updatedAt: existing.updatedAt,
                    body, updatedAt: note.updatedAt
                )
                let createdAt = isEarlier(note.createdAt, than: existing.createdAt)
                    ? note.createdAt : existing.createdAt
                let updatedAt = isEarlier(existing.updatedAt, than: note.updatedAt)
                    ? note.updatedAt : existing.updatedAt
                guard merged != existing.body
                    || createdAt != existing.createdAt
                    || updatedAt != existing.updatedAt
                else { continue }

                plan.noteRevisions[note.id] = NoteRevision(
                    body: merged, createdAt: createdAt, updatedAt: updatedAt
                )
                if merged != existing.body { plan.mergedNoteCount += 1 }
            } else if insertedNoteIDs.insert(note.id).inserted {
                var arriving = note
                arriving.body = body
                if let attached = note.highlightId, !knownHighlightIDs.contains(attached) {
                    arriving.highlightId = nil
                }
                plan.insertNotes.append(arriving)
            }
        }

        // --- Bookmarks ----------------------------------------------------
        var bookmarksByKey: [String: LocalSnapshot.BookmarkState] = [:]
        for state in local.bookmarks where bookmarksByKey[state.itemKey] == nil {
            bookmarksByKey[state.itemKey] = state
        }
        var insertedBookmarkKeys: Set<String> = []

        for bookmark in incoming.bookmarks {
            guard !bookmark.itemKey.isEmpty else { continue }
            if let existing = bookmarksByKey[bookmark.itemKey] {
                if isEarlier(bookmark.createdAt, than: existing.createdAt) {
                    plan.bookmarkCreatedAt[bookmark.itemKey] = bookmark.createdAt
                }
            } else if insertedBookmarkKeys.insert(bookmark.itemKey).inserted {
                plan.insertBookmarks.append(bookmark)
            }
        }

        return plan
    }

    /// Earlier by at least as much as the file can record.
    ///
    /// ⛔ A plain `<` looks right and is wrong here. The store keeps a `Date` at
    /// full precision and the file writes milliseconds, so a device importing
    /// its OWN export would find every birthday a fraction earlier than the one
    /// it holds, rewrite them all, and report changes it did not really make.
    /// Comparing at the format's own resolution is what makes importing a
    /// backup twice genuinely do nothing the second time.
    private static func isEarlier(_ candidate: Date, than current: Date) -> Bool {
        current.timeIntervalSince(candidate) >= BackupDocument.timeResolution
    }

    // MARK: - Merging two versions of one note

    /// The line that appears between passages of a note that was written in two
    /// places. It is visible on purpose: a reader whose note is longer than they
    /// left it is owed an explanation inside the note itself.
    static let passageSeparator = "——— also written on another device ———"

    /// A note's body, read as the ordered list of passages it is made of.
    ///
    /// A body that has never been merged is one passage. Splitting on the
    /// separator is what makes merging associative: the third device's copy
    /// merges against passages, not against one opaque blob.
    static func passages(of body: String) -> [String] {
        body.components(separatedBy: passageSeparator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// The union of two versions of the same note, losing nothing.
    ///
    /// Passages from the side last touched earlier come first, so a note reads
    /// in the order it was written. A passage wholly contained in another is
    /// dropped — that is not a compromise but the correct reading of the
    /// ordinary case, where the reader simply extended a note and every earlier
    /// word is still present in the later text. Only genuinely divergent writing
    /// produces a separator.
    ///
    /// Order depends on recorded timestamps and text, never on which argument
    /// came first, so merging A into B and B into A give the same note.
    static func mergedBody(
        _ a: String, updatedAt aUpdated: Date,
        _ b: String, updatedAt bUpdated: Date
    ) -> String {
        let aPassages = passages(of: a)
        let bPassages = passages(of: b)

        // Two devices can genuinely record the same instant, so a tie still has
        // to resolve the same way from either side. It breaks first on which
        // body already holds MORE passages.
        //
        // ⛔ That clause is not a nicety. A merged body is a different string
        // from either of the bodies it came from, so a tie broken on the text
        // alone sorts it differently than its own inputs did — and re-importing
        // the same file would shuffle a reader's note into a new order every
        // time. Preferring the accumulated side keeps the order it already has,
        // which is the order the reader wrote in.
        let aFirst = (aUpdated, -aPassages.count, a) <= (bUpdated, -bPassages.count, b)
        let ordered = aFirst ? aPassages + bPassages : bPassages + aPassages

        var kept: [String] = []
        for passage in ordered {
            // Already have these words, verbatim or inside something longer.
            if kept.contains(where: { $0 == passage || $0.contains(passage) }) { continue }
            // A later passage that swallows an earlier one replaces it in place,
            // so the order the reader wrote in survives.
            if let index = kept.firstIndex(where: { passage.contains($0) }) {
                kept[index] = passage
                kept = dropContained(in: kept, keeping: index)
                continue
            }
            kept.append(passage)
        }

        return kept.joined(separator: "\n\n\(passageSeparator)\n\n")
    }

    /// After a passage grew in place it may now contain others. Removes those,
    /// leaving the grown passage where it was.
    private static func dropContained(in passages: [String], keeping index: Int) -> [String] {
        let grown = passages[index]
        var result: [String] = []
        for (position, passage) in passages.enumerated() {
            if position != index, grown.contains(passage) { continue }
            result.append(passage)
        }
        return result
    }
}
