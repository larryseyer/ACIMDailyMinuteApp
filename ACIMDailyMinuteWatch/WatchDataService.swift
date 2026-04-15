import Foundation
import SwiftData
import CryptoKit
import WatchConnectivity

final class WatchDataService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchDataService()

    let container: ModelContainer

    private override init() {
        let schema = Schema([
            DailyMinute.self,
            DailyLesson.self,
            Bookmark.self,
            ArchivedReading.self,
            Channel.self,
            CachedPodcastEpisode.self
        ])
        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.larryseyer.acimdailyminute")!
            .appending(path: "ACIMDailyMinute.sqlite")
        let config = ModelConfiguration(
            schema: schema,
            url: containerURL,
            allowsSave: true
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create Watch ModelContainer: \(error)")
        }
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingPayload(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingPayload(applicationContext)
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let text = payload["text"] as? String,
              let publishedInterval = payload["publishedAt"] as? TimeInterval,
              let dateString = payload["date"] as? String,
              let segmentHash = payload["segmentHash"] as? String else { return }

        let publishedAt = Date(timeIntervalSince1970: publishedInterval)
        Task { @MainActor in
            let descriptor = FetchDescriptor<DailyMinute>(
                predicate: #Predicate { $0.segmentHash == segmentHash }
            )
            let existing = try? container.mainContext.fetch(descriptor)
            guard existing?.isEmpty ?? true else { return }

            let minute = DailyMinute()
            minute.segmentHash = segmentHash
            minute.date = dateString
            minute.publishedAt = publishedAt
            minute.text = text
            container.mainContext.insert(minute)
            try? container.mainContext.save()
        }
    }

    @MainActor
    func fetchTodaysMinute() -> DailyMinute? {
        var descriptor = FetchDescriptor<DailyMinute>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first
    }

    @MainActor
    func fetchTodaysLessonNumber() -> Int? {
        var descriptor = FetchDescriptor<DailyLesson>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first?.lessonNumber
    }

    func fetchDailyContent() async throws {
        async let minute = fetchMinute()
        async let lesson = fetchLesson()
        let (minuteDTO, lessonDTO) = try await (minute, lesson)

        let context = ModelContext(container)
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

    // MARK: - Helpers

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

    private func sha256Truncated(_ input: String) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(input.utf8))
        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }
}

// MARK: - DTOs

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
