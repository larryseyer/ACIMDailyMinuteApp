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
    static func persistInlineLessons(_ items: [InlineArchiveLessonDTO], in context: ModelContext) throws {
        guard !items.isEmpty else { return }
        let channel = "daily-lesson"
        let existingHashes = try fetchExistingHashes(in: context)

        for item in items {
            // Lesson archive entries don't ship a `text` body — only a title,
            // date, and audio link. Hash the title so each lesson stays unique.
            let lineHash = HashUtility.sha256Truncated("\(channel)|\(item.date)|\(item.title)")
            guard !existingHashes.contains(lineHash) else { continue }

            let row = ArchivedReading()
            row.lineHash = lineHash
            row.channel = channel
            row.dateString = item.date
            row.timestamp = DataService.parseISODate(item.date)
            row.text = item.title
            row.sourceReference = ""
            row.lessonNumber = item.lesson_id
            row.audioURL = item.audio_url.isEmpty ? nil : item.audio_url
            row.searchableText = item.title
            context.insert(row)
        }
    }

    private static func fetchExistingHashes(in context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<ArchivedReading>()
        let rows = try context.fetch(descriptor)
        return Set(rows.map(\.lineHash))
    }
}
