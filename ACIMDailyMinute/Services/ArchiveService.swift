import Foundation
import SwiftData

/// Persists the inline `archive[]` arrays delivered alongside `/daily-minute.json`
/// and `/daily-lesson.json` into SwiftData as `ArchivedReading` rows.
///
/// The ACIM publisher embeds the rolling archive directly inside each channel's
/// JSON payload, so this service does no network I/O of its own — it's invoked
/// by `DataService` after a successful fetch + decode.
///
/// Runs on the main actor because SwiftData's `ModelContext` is itself
/// main-actor-isolated. Idempotent by design: rows are upserted by `lineHash`,
/// so re-persisting the same archive is a no-op.
@MainActor
final class ArchiveService {
    /// Upserts inline Daily Minute archive entries. Pre-fetches the full set of
    /// existing `lineHash` values once before the loop so the method runs in
    /// O(n) rather than O(n²) on the typical 30-entry rolling window.
    static func persistInlineMinutes(_ items: [InlineArchiveMinuteDTO], in context: ModelContext) throws {
        guard !items.isEmpty else { return }
        let channel = "daily-minute"
        let existingHashes = try fetchExistingHashes(in: context)

        for item in items {
            let lineHash = HashUtility.sha256Truncated("\(channel)|\(item.date)|\(item.text)")
            guard !existingHashes.contains(lineHash) else { continue }

            let row = ArchivedReading()
            row.lineHash = lineHash
            row.channel = channel
            row.dateString = item.date
            row.timestamp = DataService.parseISODate(item.date)
            row.text = item.text
            row.sourceReference = item.source_reference
            row.lessonNumber = nil
            row.audioURL = item.audio_url.isEmpty ? nil : item.audio_url
            row.searchableText = "\(item.text) \(item.source_reference)"
            context.insert(row)
        }
    }

    /// Upserts inline Daily Lesson archive entries. Lesson archive items don't
    /// carry a `source_reference` field — the `lessonTitle` plays the equivalent
    /// human-readable role and is folded into `searchableText`.
    ///
    /// Identity is the lesson number, not a hash of date + title. Lesson titles
    /// have been re-canonicalised at least once, and a title-derived hash makes
    /// a corrected title look like an entirely new lesson: the old row stays,
    /// the new row lands beside it, and a `.first` lookup is free to return
    /// whichever it likes — including the stale one, which carries no video.
    /// Keying on the lesson number makes re-ingestion a true upsert and lets
    /// this collapse duplicates that the old scheme already created.
    static func persistInlineLessons(_ items: [InlineArchiveLessonDTO], in context: ModelContext) throws {
        guard !items.isEmpty else { return }
        let channel = "daily-lesson"

        var rowsByLesson: [Int: ArchivedReading] = [:]
        let existing = try context.fetch(
            FetchDescriptor<ArchivedReading>(
                predicate: #Predicate { $0.channel == channel }
            )
        )
        for row in existing {
            guard let number = row.lessonNumber else { continue }
            if rowsByLesson[number] == nil {
                rowsByLesson[number] = row
            } else {
                context.delete(row)
            }
        }

        for item in items {
            let row: ArchivedReading
            if let known = rowsByLesson[item.lesson_id] {
                row = known
            } else {
                row = ArchivedReading()
                context.insert(row)
                rowsByLesson[item.lesson_id] = row
            }

            row.lineHash = HashUtility.sha256Truncated("\(channel)|lesson|\(item.lesson_id)")
            row.channel = channel
            row.dateString = item.date
            row.timestamp = DataService.parseISODate(item.date)
            row.text = item.title
            row.sourceReference = ""
            row.lessonNumber = item.lesson_id
            row.audioURL = item.audio_url.isEmpty ? nil : item.audio_url
            row.youtubeID = (item.youtube_id?.isEmpty == false) ? item.youtube_id : nil
            row.searchableText = item.title
        }
    }

    private static func fetchExistingHashes(in context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<ArchivedReading>()
        let rows = try context.fetch(descriptor)
        return Set(rows.map(\.lineHash))
    }
}
