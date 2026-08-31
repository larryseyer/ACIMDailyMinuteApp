import Foundation
import SwiftData

/// Reads the reader's own work out of the store and defaults into a
/// `BackupDocument`, and merges one back in.
///
/// The only file in this feature that touches `ModelContext` or `UserDefaults`.
/// The format and the merge are deliberately pure so a harness can drive them
/// (`tools/verify_backup.sh`); everything that cannot be pure is collected here
/// and kept thin.
@MainActor
enum BackupService {
    // MARK: - Which defaults are the reader's

    /// The keys that hold something the reader chose, and that nothing can
    /// recompute.
    private enum ReaderKey {
        static let dailyReminderEnabled = "dailyReminderEnabled"
        static let dailyReminderTimeInterval = "dailyReminderTimeInterval"
        static let notifyNewMinute = "notifyNewMinute"
        static let notifyNewLesson = "notifyNewLesson"
        static let notifyPhraseMatches = "notifyPhraseMatches"
        static let notifyLiveActivities = "notifyLiveActivities"
        static let lessonsLastWatchedIndex = "listen.lessons.lastWatchedIndex"
    }

    /// ⛔ Named here so the exclusion is a decision on the page rather than an
    /// omission someone later reads as an oversight. **None of these travels.**
    ///
    /// - Dedup ledgers and detection baselines — `phraseNotifiedItemKeys`,
    ///   `lastMinuteSegmentId`, `lastMinuteDate`, `lastLessonId`,
    ///   `phraseMatchBadge`. Importing one would suppress an alert on a device
    ///   that never showed it.
    /// - Fetch cooldowns — `lastForegroundCheck`, `lastDailyMinuteFetch`,
    ///   `lastDailyLessonFetch`, `lastFeedFetch`, `lastArchiveFetch`. Importing
    ///   one would stop a fetch that never happened here.
    /// - Cache schema markers — `contentSchemaVersion`, `podcastCacheSchemaVersion`.
    ///   They describe this device's store, not the reader.
    /// - `hasSeenOnboarding` — app state, not the reader's work. A new device
    ///   should still introduce itself.
    /// - `useCustomNotificationSound` — registered and never read anywhere.
    private enum NotTheReaders {}

    // MARK: - Writing

    static func makeDocument(
        in context: ModelContext,
        corpus: CorpusService = .shared,
        exportedAt: Date = Date()
    ) -> BackupDocument {
        let highlights = AnnotationStore.allHighlights(in: context)
        let notes = AnnotationStore.allNotes(in: context)
        let bookmarks = (try? context.fetch(
            FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []

        // ⛔ The citation comes from `AnnotationExport.entries` rather than from
        // the stored offset, because that is where the re-anchoring lives: a
        // mark's words may have moved since it was made, and the export exists
        // to name where they are NOW. Reproducing that arithmetic here would
        // give two answers to one question.
        let exported = AnnotationExport.entries(
            highlights: highlights, notes: notes, corpus: corpus
        )
        var citationsByHighlight: [UUID: String] = [:]
        for entry in exported.highlights where entry.citation != nil {
            citationsByHighlight[entry.id] = entry.citation
        }

        var namesByReadingKey: [String: String] = [:]
        func name(of rawKey: String) -> String? {
            if let cached = namesByReadingKey[rawKey] { return cached }
            guard let key = ReadingKey(rawValue: rawKey) else { return nil }
            let resolved = key.displayName(corpus: corpus)
            namesByReadingKey[rawKey] = resolved
            return resolved
        }

        return BackupDocument(
            exportedAt: exportedAt,
            editionNote: AnnotationExport.editionNote,
            highlights: highlights.map { highlight in
                BackupDocument.Highlight(
                    id: highlight.id,
                    readingKey: highlight.readingKey,
                    startOffset: highlight.startOffset,
                    length: highlight.length,
                    quote: highlight.quote,
                    createdAt: highlight.createdAt,
                    reading: name(of: highlight.readingKey),
                    citation: citationsByHighlight[highlight.id]
                )
            },
            notes: notes.map { note in
                BackupDocument.Note(
                    id: note.id,
                    readingKey: note.readingKey,
                    body: note.body,
                    createdAt: note.createdAt,
                    updatedAt: note.updatedAt,
                    highlightId: note.highlightID,
                    reading: name(of: note.readingKey)
                )
            },
            bookmarks: bookmarks.map { bookmark in
                BackupDocument.Bookmark(
                    itemKey: bookmark.itemKey,
                    channel: bookmark.channel,
                    createdAt: bookmark.createdAt,
                    readingKey: portableKey(forBookmark: bookmark.itemKey, in: context)
                )
            },
            settings: currentSettings()
        )
    }

    static func suggestedFilename(for document: BackupDocument) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "ACIM Daily Minute backup \(formatter.string(from: document.exportedAt)).json"
    }

    /// A restore onto a device with nothing on it should bring the reader's
    /// settings with it; a merge into work already in progress should not
    /// silently reach over and change them.
    static func shouldRestoreSettingsByDefault(in context: ModelContext) -> Bool {
        AnnotationStore.allHighlights(in: context).isEmpty
            && AnnotationStore.allNotes(in: context).isEmpty
    }

    // MARK: - Reading back

    @discardableResult
    static func apply(
        _ document: BackupDocument,
        restoreSettings: Bool,
        in context: ModelContext
    ) throws -> BackupMerge.MergePlan {
        var incoming = document
        incoming.bookmarks = document.bookmarks.map { bookmark in
            var translated = bookmark
            translated.itemKey = localItemKey(for: bookmark, in: context)
            return translated
        }

        let plan = BackupMerge.plan(local: snapshot(in: context), incoming: incoming)

        for highlight in plan.insertHighlights {
            let row = Highlight()
            row.id = highlight.id
            row.readingKey = highlight.readingKey
            row.startOffset = highlight.startOffset
            row.length = highlight.length
            row.quote = highlight.quote
            row.createdAt = highlight.createdAt
            // `isOrphaned` is left false on purpose. It is an answer about this
            // device's corpus, and `AnnotatableReadingText` re-anchors the
            // moment the reading is opened.
            context.insert(row)
        }
        if !plan.highlightCreatedAt.isEmpty {
            for row in AnnotationStore.allHighlights(in: context) {
                if let earlier = plan.highlightCreatedAt[row.id] { row.createdAt = earlier }
            }
        }

        for note in plan.insertNotes {
            let row = Note()
            row.id = note.id
            row.readingKey = note.readingKey
            row.body = note.body
            row.createdAt = note.createdAt
            row.updatedAt = note.updatedAt
            row.highlightID = note.highlightId
            context.insert(row)
        }
        if !plan.noteRevisions.isEmpty {
            for row in AnnotationStore.allNotes(in: context) {
                guard let revision = plan.noteRevisions[row.id] else { continue }
                row.body = revision.body
                row.createdAt = revision.createdAt
                row.updatedAt = revision.updatedAt
            }
        }

        let existingBookmarks = (try? context.fetch(FetchDescriptor<Bookmark>())) ?? []
        for bookmark in plan.insertBookmarks {
            let row = Bookmark()
            row.itemKey = bookmark.itemKey
            row.channel = bookmark.channel
            row.createdAt = bookmark.createdAt
            context.insert(row)
        }
        if !plan.bookmarkCreatedAt.isEmpty {
            for row in existingBookmarks {
                if let earlier = plan.bookmarkCreatedAt[row.itemKey] { row.createdAt = earlier }
            }
        }

        try context.save()
        applySettings(document.settings, restoreScalars: restoreSettings)
        return plan
    }

    private static func snapshot(in context: ModelContext) -> BackupMerge.LocalSnapshot {
        let bookmarks = (try? context.fetch(FetchDescriptor<Bookmark>())) ?? []
        return BackupMerge.LocalSnapshot(
            highlights: AnnotationStore.allHighlights(in: context).map {
                .init(id: $0.id, createdAt: $0.createdAt)
            },
            notes: AnnotationStore.allNotes(in: context).map {
                .init(id: $0.id, body: $0.body, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            bookmarks: bookmarks.map { .init(itemKey: $0.itemKey, createdAt: $0.createdAt) }
        )
    }

    // MARK: - Bookmark keys, which are not all positional

    /// The positional key for a bookmarked reading, where one can be worked out.
    ///
    /// `lesson:` and `text:` item keys are already `ReadingKey` raw values.
    /// `minute:` folds the body text into a hash, so two devices holding
    /// slightly different text for the same passage compute different keys —
    /// which is why the segment id is looked up and carried alongside.
    /// An archived minute has no segment id anywhere, so it carries nothing and
    /// falls back to its own key.
    private static func portableKey(forBookmark itemKey: String, in context: ModelContext) -> String? {
        if ReadingKey(rawValue: itemKey) != nil { return itemKey }
        let prefix = "minute:"
        guard itemKey.hasPrefix(prefix) else { return nil }
        let hash = String(itemKey.dropFirst(prefix.count))
        guard !hash.isEmpty else { return nil }
        let found = try? context.fetch(
            FetchDescriptor<DailyMinute>(predicate: #Predicate { $0.segmentHash == hash })
        ).first
        guard let minute = found, minute.segmentId > 0 else { return nil }
        return ReadingKey.segment(minute.segmentId).rawValue
    }

    /// The key **this** device would use for the reading a backup's bookmark
    /// names, so the same passage does not arrive as a second row.
    private static func localItemKey(
        for bookmark: BackupDocument.Bookmark,
        in context: ModelContext
    ) -> String {
        guard let raw = bookmark.readingKey, let key = ReadingKey(rawValue: raw) else {
            return bookmark.itemKey
        }
        switch key {
        case .lesson, .textSection:
            // These forms are the item key.
            return raw
        case .segment(let id):
            let found = try? context.fetch(
                FetchDescriptor<DailyMinute>(predicate: #Predicate { $0.segmentId == id })
            ).first
            guard let minute = found, !minute.segmentHash.isEmpty else { return bookmark.itemKey }
            return "minute:\(minute.segmentHash)"
        case .manual, .minuteDate:
            return bookmark.itemKey
        }
    }

    // MARK: - Settings

    private static func currentSettings() -> BackupDocument.Settings {
        let defaults = UserDefaults.standard
        // `object(forKey:)` consults the registration domain, so a registered
        // default is written and a key nobody has ever set is left out.
        func bool(_ key: String) -> Bool? {
            defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key)
        }
        let phrases = PhraseStorage.phrases
        let listened = PlaybackHistory.entries

        return BackupDocument.Settings(
            watchedPhrases: phrases.isEmpty ? nil : phrases,
            listenedEpisodes: listened.isEmpty ? nil : listened,
            dailyReminderEnabled: bool(ReaderKey.dailyReminderEnabled),
            dailyReminderTimeInterval: defaults.object(forKey: ReaderKey.dailyReminderTimeInterval)
                == nil ? nil : defaults.double(forKey: ReaderKey.dailyReminderTimeInterval),
            notifyNewMinute: bool(ReaderKey.notifyNewMinute),
            notifyNewLesson: bool(ReaderKey.notifyNewLesson),
            notifyPhraseMatches: bool(ReaderKey.notifyPhraseMatches),
            notifyLiveActivities: bool(ReaderKey.notifyLiveActivities),
            lessonsLastWatchedIndex: defaults.object(forKey: ReaderKey.lessonsLastWatchedIndex)
                == nil ? nil : defaults.integer(forKey: ReaderKey.lessonsLastWatchedIndex)
        )
    }

    /// Lossless settings merge whatever the reader chose, because a union of
    /// them cannot discard anything. The scalars — where a merge has no meaning
    /// and one value must displace another — move only on request.
    private static func applySettings(_ settings: BackupDocument.Settings, restoreScalars: Bool) {
        if let incoming = settings.watchedPhrases { mergePhrases(incoming) }
        if let incoming = settings.listenedEpisodes { mergeListened(incoming) }

        guard restoreScalars else { return }
        let defaults = UserDefaults.standard
        if let value = settings.notifyNewMinute { defaults.set(value, forKey: ReaderKey.notifyNewMinute) }
        if let value = settings.notifyNewLesson { defaults.set(value, forKey: ReaderKey.notifyNewLesson) }
        if let value = settings.notifyPhraseMatches {
            defaults.set(value, forKey: ReaderKey.notifyPhraseMatches)
        }
        if let value = settings.notifyLiveActivities {
            defaults.set(value, forKey: ReaderKey.notifyLiveActivities)
        }
        if let value = settings.lessonsLastWatchedIndex {
            defaults.set(value, forKey: ReaderKey.lessonsLastWatchedIndex)
        }
        if let value = settings.dailyReminderTimeInterval {
            defaults.set(value, forKey: ReaderKey.dailyReminderTimeInterval)
        }
        if let enabled = settings.dailyReminderEnabled {
            defaults.set(enabled, forKey: ReaderKey.dailyReminderEnabled)
            rescheduleReminder(
                enabled: enabled,
                at: settings.dailyReminderTimeInterval
                    ?? defaults.double(forKey: ReaderKey.dailyReminderTimeInterval)
            )
        }
    }

    /// Local phrases keep their places, so a full list is never displaced by an
    /// import; incoming ones fill whatever room is left.
    private static func mergePhrases(_ incoming: [String]) {
        var merged = PhraseStorage.phrases
        for phrase in incoming {
            let trimmed = phrase.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, merged.count < PhraseStorage.maxPhrases else { continue }
            guard !merged.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
            else { continue }
            merged.append(trimmed)
        }
        PhraseStorage.phrases = merged
    }

    /// A row reads "when you listened", and the most recent listen is the
    /// truthful answer — which makes the later of the two stamps the merge.
    private static func mergeListened(_ incoming: [String: Date]) {
        var merged = PlaybackHistory.entries
        for (episode, listenedAt) in incoming {
            guard !episode.isEmpty else { continue }
            if let existing = merged[episode], existing >= listenedAt { continue }
            merged[episode] = listenedAt
        }
        PlaybackHistory.entries = merged
    }

    /// The scheduled notification is OS-side state rebuilt from the two keys, so
    /// restoring the keys without rebuilding it would leave a reader with a
    /// reminder switch that says one thing and a phone that does another.
    private static func rescheduleReminder(enabled: Bool, at interval: Double) {
        let time = Date(timeIntervalSinceReferenceDate: interval)
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 9
        let minute = components.minute ?? 0
        Task {
            if enabled {
                await NotificationManager.shared.requestPermissionIfNeeded()
                await NotificationManager.shared.scheduleDailyReminder(hour: hour, minute: minute)
            } else {
                await NotificationManager.shared.cancelDailyReminder()
            }
        }
    }
}
