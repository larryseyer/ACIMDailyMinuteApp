import Foundation
import SwiftData
import WidgetKit

/// Two-phase service: network I/O returns DTOs; persistence is `@MainActor`
/// and writes into a caller-supplied `ModelContext`. Writing through the
/// SwiftUI-injected context lets `@Query` observe the changes immediately
/// without relying on cross-context auto-merge (which isn't reliable on
/// iOS 17).
struct DataService: Sendable {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Fetch (pure I/O — returns DTOs, no persistence)

    /// Returns `nil` if the cooldown window blocks the fetch.
    func fetchDailyMinute(baseURL: String = "https://www.acimdailyminute.org") async throws -> DailyMinuteResponse? {
        guard FetchCooldown.shouldFetch(
            key: FetchCooldownKey.dailyMinute,
            interval: FetchCooldownInterval.live
        ) else { return nil }

        let url = URL(string: "\(baseURL)/daily-minute.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DailyMinuteResponse.self, from: data)
    }

    /// Returns `nil` if the cooldown window blocks the fetch.
    func fetchDailyLesson(baseURL: String = "https://www.acimdailyminute.org") async throws -> DailyLessonResponse? {
        guard FetchCooldown.shouldFetch(
            key: FetchCooldownKey.dailyLesson,
            interval: FetchCooldownInterval.live
        ) else { return nil }

        let url = URL(string: "\(baseURL)/daily-lesson.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DailyLessonResponse.self, from: data)
    }

    // MARK: - Persist (MainActor — writes into caller's ModelContext)

    /// Upserts the Daily Minute and its inline archive into `context`, saves,
    /// marks the cooldown, and fires downstream side-effects (widget reload,
    /// Live Activity start when a *new* segment arrives).
    @MainActor
    @discardableResult
    static func persistMinute(_ dto: DailyMinuteResponse, in context: ModelContext) throws -> DailyMinuteResponse {
        let segmentHash = HashUtility.sha256Truncated("minute:\(dto.segment_id)|\(dto.date)|\(dto.text)")
        let publishedAt = parseISODate(dto.date) ?? Date()

        let descriptor = FetchDescriptor<DailyMinute>(
            predicate: #Predicate { $0.segmentHash == segmentHash }
        )
        let existing = try context.fetch(descriptor).first
        let isNew = existing == nil

        let minute = existing ?? DailyMinute()
        minute.segmentId = dto.segment_id
        minute.segmentHash = segmentHash
        minute.date = dto.date
        minute.publishedAt = publishedAt
        minute.text = dto.text
        minute.sourcePDF = dto.source_pdf
        minute.sourceReference = dto.source_reference
        minute.wordCount = dto.word_count
        minute.audioURL = dto.audio_url.isEmpty ? nil : dto.audio_url
        minute.youtubeURL = dto.youtube_url.isEmpty ? nil : dto.youtube_url
        minute.youtubeID = dto.youtube_id.isEmpty ? nil : dto.youtube_id
        minute.tiktokURL = dto.tiktok_url.isEmpty ? nil : dto.tiktok_url
        if isNew { context.insert(minute) }

        try ArchiveService.persistInlineMinutes(dto.archive, in: context)

        try context.save()
        FetchCooldown.markFetched(key: FetchCooldownKey.dailyMinute)
        WidgetCenter.shared.reloadAllTimelines()

        #if os(iOS)
        if isNew {
            LiveActivityManager.startOrUpdate(
                channel: "daily-minute",
                latestText: dto.text,
                publishedDate: publishedAt
            )
        }
        #endif

        return dto
    }

    /// Upserts the Daily Lesson and its inline archive. Mirrors `persistMinute`
    /// but keys uniqueness on `lessonNumber` (the `@Attribute(.unique)` field
    /// on `DailyLesson`).
    @MainActor
    @discardableResult
    static func persistLesson(_ dto: DailyLessonResponse, in context: ModelContext) throws -> DailyLessonResponse {
        let lessonNumber = dto.lesson_id
        let segmentHash = HashUtility.sha256Truncated("lesson:\(dto.lesson_id)|\(dto.date)|\(dto.text)")
        let publishedAt = parseISODate(dto.date) ?? Date()

        let descriptor = FetchDescriptor<DailyLesson>(
            predicate: #Predicate { $0.lessonNumber == lessonNumber }
        )
        let existing = try context.fetch(descriptor).first
        let isNew = existing == nil

        let lesson = existing ?? DailyLesson()
        lesson.lessonNumber = lessonNumber
        lesson.lessonTitle = dto.title
        lesson.segmentHash = segmentHash
        lesson.date = dto.date
        lesson.publishedAt = publishedAt
        lesson.text = dto.text
        lesson.wordCount = dto.word_count
        lesson.audioURL = dto.audio_url.isEmpty ? nil : dto.audio_url
        lesson.youtubeURL = dto.youtube_url.isEmpty ? nil : dto.youtube_url
        lesson.youtubeID = dto.youtube_id.isEmpty ? nil : dto.youtube_id
        if isNew { context.insert(lesson) }

        try ArchiveService.persistInlineLessons(dto.archive, in: context)

        try context.save()
        FetchCooldown.markFetched(key: FetchCooldownKey.dailyLesson)
        WidgetCenter.shared.reloadAllTimelines()

        #if os(iOS)
        if isNew {
            LiveActivityManager.startOrUpdate(
                channel: "daily-lesson",
                latestText: dto.text,
                publishedDate: publishedAt,
                lessonNumber: lessonNumber
            )
        }
        #endif

        return dto
    }

    // MARK: - Date Parsing

    /// Parses the `YYYY-MM-DD` strings the publisher emits in `date` fields.
    /// Falls back to ISO-8601 with time component for forward compatibility
    /// in case the publisher ever upgrades to richer timestamps.
    @MainActor
    static func parseISODate(_ string: String) -> Date? {
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dayOnly.dateFormat = "yyyy-MM-dd"
        if let date = dayOnly.date(from: string) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }
}

// MARK: - DTOs

/// Top-level shape of `/daily-minute.json`.
///
/// Field names use snake_case to match the publisher (`github_push.py`)
/// verbatim — no `CodingKeys` needed, which keeps drift detection trivial:
/// any new server field becomes a compile error if added here, and any
/// renamed field becomes a decode error at runtime.
struct DailyMinuteResponse: Codable, Sendable {
    let segment_id: Int
    let date: String
    let text: String
    let source_pdf: String
    let source_reference: String
    let word_count: Int
    let audio_url: String
    let youtube_url: String
    let youtube_id: String
    let tiktok_url: String
    let archive: [InlineArchiveMinuteDTO]
}

struct InlineArchiveMinuteDTO: Codable, Sendable {
    let date: String
    let text: String
    let source_reference: String
    let audio_url: String
}

/// Top-level shape of `/daily-lesson.json`. The publisher omits
/// `segment_id`, `source_pdf`, `source_reference`, and `tiktok_url` from
/// the lesson endpoint by design — model defaults handle those fields
/// (parallel-schema choice, see Phase 3.2 handoff).
struct DailyLessonResponse: Codable, Sendable {
    let lesson_id: Int
    let date: String
    let title: String
    let text: String
    let word_count: Int
    let audio_url: String
    let youtube_url: String
    let youtube_id: String
    let total_lessons: Int
    let archive: [InlineArchiveLessonDTO]
}

struct InlineArchiveLessonDTO: Codable, Sendable {
    let lesson_id: Int
    let title: String
    let date: String
    let audio_url: String
}
