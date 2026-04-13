import Foundation
import SwiftData
import CryptoKit

/// Lightweight data service for the watch — fetches both ACIM channels
/// directly from acimdailyminute.org and persists into the shared App
/// Group container. The watch is a standalone consumer; it deliberately
/// has no dependency on the iPhone target's `DataService`.
///
/// Future cleanup (Phase 5+) may hoist the DTOs into a file shared between
/// targets to remove the duplicated decoder shape; for now they're
/// duplicated and marked with a `MIRROR:` comment so drift is obvious.
actor WatchDataService {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// One-shot fetch of the Daily Minute and Daily Lesson endpoints.
    /// Both run concurrently (via `async let`) so the watch UI doesn't
    /// pay sequential round-trip latency on a small device.
    func fetchDailyContent() async throws {
        async let minute = fetchMinute()
        async let lesson = fetchLesson()
        let (minuteDTO, lessonDTO) = try await (minute, lesson)

        let context = ModelContext(modelContainer)
        try persistMinute(minuteDTO, in: context)
        try persistLesson(lessonDTO, in: context)
        try context.save()
    }

    // MARK: - Network

    private func fetchMinute() async throws -> WatchMinuteResponse {
        let url = URL(string: "https://www.acimdailyminute.org/daily-minute.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(WatchMinuteResponse.self, from: data)
    }

    private func fetchLesson() async throws -> WatchLessonResponse {
        let url = URL(string: "https://www.acimdailyminute.org/daily-lesson.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(WatchLessonResponse.self, from: data)
    }

    // MARK: - Persistence

    private func persistMinute(_ dto: WatchMinuteResponse, in context: ModelContext) throws {
        let segmentHash = sha256Truncated("minute:\(dto.segment_id)|\(dto.date)|\(dto.text)")
        let descriptor = FetchDescriptor<DailyMinute>(
            predicate: #Predicate { $0.segmentHash == segmentHash }
        )
        let minute = try context.fetch(descriptor).first ?? DailyMinute()
        let isNew = minute.segmentHash.isEmpty

        minute.segmentId = dto.segment_id
        minute.segmentHash = segmentHash
        minute.date = dto.date
        minute.publishedAt = parseDate(dto.date) ?? Date()
        minute.text = dto.text
        minute.sourcePDF = dto.source_pdf
        minute.sourceReference = dto.source_reference
        minute.wordCount = dto.word_count
        minute.audioURL = dto.audio_url.isEmpty ? nil : dto.audio_url
        minute.youtubeURL = dto.youtube_url.isEmpty ? nil : dto.youtube_url
        minute.youtubeID = dto.youtube_id.isEmpty ? nil : dto.youtube_id
        minute.tiktokURL = dto.tiktok_url.isEmpty ? nil : dto.tiktok_url
        if isNew { context.insert(minute) }
    }

    private func persistLesson(_ dto: WatchLessonResponse, in context: ModelContext) throws {
        let lessonNumber = dto.lesson_id
        let descriptor = FetchDescriptor<DailyLesson>(
            predicate: #Predicate { $0.lessonNumber == lessonNumber }
        )
        let lesson = try context.fetch(descriptor).first ?? DailyLesson()
        let isNew = lesson.segmentHash.isEmpty

        lesson.lessonNumber = lessonNumber
        lesson.lessonTitle = dto.title
        lesson.segmentHash = sha256Truncated("lesson:\(dto.lesson_id)|\(dto.date)|\(dto.text)")
        lesson.date = dto.date
        lesson.publishedAt = parseDate(dto.date) ?? Date()
        lesson.text = dto.text
        lesson.wordCount = dto.word_count
        lesson.audioURL = dto.audio_url.isEmpty ? nil : dto.audio_url
        lesson.youtubeURL = dto.youtube_url.isEmpty ? nil : dto.youtube_url
        lesson.youtubeID = dto.youtube_id.isEmpty ? nil : dto.youtube_id
        if isNew { context.insert(lesson) }
    }

    // MARK: - Helpers (self-contained — no dependency on phone target)

    private func parseDate(_ string: String) -> Date? {
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

    /// SHA-256 truncated to 16 hex chars. Duplicates the phone target's
    /// `HashUtility` to keep the watch target self-contained.
    /// MIRROR: keep in sync with HashUtility.sha256Truncated.
    private func sha256Truncated(_ input: String) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(input.utf8))
        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }
}

// MARK: - DTOs (self-contained, no dependency on phone target's DataService)
// MIRROR: keep in sync with DailyMinuteResponse / DailyLessonResponse in
// ACIMDailyMinute/Services/DataService.swift. Field shape must stay
// byte-identical so both targets decode the same JSON without divergence.

private struct WatchMinuteResponse: Codable, Sendable {
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
}

private struct WatchLessonResponse: Codable, Sendable {
    let lesson_id: Int
    let date: String
    let title: String
    let text: String
    let word_count: Int
    let audio_url: String
    let youtube_url: String
    let youtube_id: String
    let total_lessons: Int
}
