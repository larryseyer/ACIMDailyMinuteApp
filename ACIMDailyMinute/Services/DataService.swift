import Foundation
import SwiftData
import WidgetKit

/// Two-phase service: network I/O returns DTOs; persistence is `@MainActor`
/// and writes into a caller-supplied `ModelContext`. Writing through the
/// SwiftUI-injected context lets `@Query` observe the changes immediately
/// without relying on cross-context auto-merge (which isn't reliable on
/// iOS 17 and caused the "only one story on first launch" bug).
struct DataService: Sendable {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Fetch (pure I/O — returns DTOs, no persistence)

    /// Returns `nil` if the cooldown window blocks the fetch, otherwise the
    /// decoded stories. Callers are responsible for persisting the DTOs on
    /// the MainActor via `persistStories(_:in:)`.
    func fetchStoryDTOs(baseURL: String = "https://www.acimdailyminute.org") async throws -> [StoryDTO]? {
        guard FetchCooldown.shouldFetch(
            key: FetchCooldownKey.stories,
            interval: FetchCooldownInterval.live
        ) else { return nil }

        let url = URL(string: "\(baseURL)/stories.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(StoriesResponse.self, from: data)
        return response.stories
    }

    func fetchCorrectionDTOs(baseURL: String = "https://www.acimdailyminute.org") async throws -> [CorrectionDTO]? {
        guard FetchCooldown.shouldFetch(
            key: FetchCooldownKey.corrections,
            interval: FetchCooldownInterval.live
        ) else { return nil }

        let url = URL(string: "\(baseURL)/corrections.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(CorrectionsResponse.self, from: data)
        return response.corrections
    }

    // MARK: - Persist (MainActor — writes into caller's ModelContext)

    /// Upserts the DTOs into `context`, saves, marks the cooldown, and fires
    /// downstream side-effects (widget reload, LiveActivity update). Returns
    /// the DTOs so callers can feed watched-term matching, etc.
    @MainActor
    @discardableResult
    static func persistStories(_ dtos: [StoryDTO], in context: ModelContext) throws -> [StoryDTO] {
        var newCount = 0
        var latestNewFact = ""
        var latestNewDate = Date.distantPast

        for dto in dtos {
            let descriptor = FetchDescriptor<Story>(
                predicate: #Predicate { $0.storyHash == dto.hash }
            )
            let existing = try context.fetch(descriptor)

            if let story = existing.first {
                story.fact = dto.fact
                story.sourceDisplay = dto.source
                story.sourceURLs = dto.sourceURLs ?? [:]
                story.audioURL = dto.audio
                story.status = dto.status ?? ""
            } else {
                let story = Story()
                story.id = dto.id
                story.storyHash = dto.hash
                story.fact = dto.fact
                story.sourceDisplay = dto.source
                story.sourceURLs = dto.sourceURLs ?? [:]
                story.audioURL = dto.audio
                story.publishedAt = parseDate(dto.publishedAt) ?? Date()
                story.status = dto.status ?? ""
                context.insert(story)
                newCount += 1
                if story.publishedAt > latestNewDate {
                    latestNewDate = story.publishedAt
                    latestNewFact = dto.fact
                }
            }
        }
        try context.save()
        FetchCooldown.markFetched(key: FetchCooldownKey.stories)
        WidgetCenter.shared.reloadAllTimelines()

        #if os(iOS)
        if newCount > 0 {
            LiveActivityManager.startOrUpdate(
                storyCount: newCount,
                latestFact: latestNewFact,
                publishedDate: latestNewDate
            )
        }
        #endif

        return dtos
    }

    @MainActor
    static func persistCorrections(_ dtos: [CorrectionDTO], in context: ModelContext) throws {
        for dto in dtos {
            let descriptor = FetchDescriptor<Correction>(
                predicate: #Predicate { $0.storyId == dto.storyId }
            )
            let existing = try context.fetch(descriptor)

            if let correction = existing.first {
                correction.originalFact = dto.originalFact
                correction.correctedFact = dto.correctedFact
                correction.reason = dto.reason
                correction.correctingSources = dto.correctingSources
                correction.type = dto.type
            } else {
                let correction = Correction()
                correction.storyId = dto.storyId
                correction.originalFact = dto.originalFact
                correction.correctedFact = dto.correctedFact
                correction.reason = dto.reason
                correction.correctingSources = dto.correctingSources
                correction.correctedAt = parseDate(dto.correctedAt) ?? Date()
                correction.type = dto.type
                context.insert(correction)
            }
        }
        try context.save()
        FetchCooldown.markFetched(key: FetchCooldownKey.corrections)
    }

    // MARK: - Date Parsing

    @MainActor
    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - DTOs

struct StoriesResponse: Codable, Sendable {
    let date: String
    let source: String?
    let stories: [StoryDTO]
}

struct StoryDTO: Codable, Sendable {
    let id: String
    let hash: String
    let fact: String
    let source: String
    let sourceURLs: [String: String]?
    let audio: String?
    let publishedAt: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, hash, fact, source, audio, status
        case sourceURLs = "source_urls"
        case publishedAt = "published_at"
    }
}

struct CorrectionsResponse: Codable, Sendable {
    let corrections: [CorrectionDTO]
}

struct CorrectionDTO: Codable, Sendable {
    let storyId: String
    let originalFact: String
    let correctedFact: String
    let reason: String
    let correctingSources: [String]
    let correctedAt: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case reason, type
        case storyId = "story_id"
        case originalFact = "original_fact"
        case correctedFact = "corrected_fact"
        case correctingSources = "correcting_sources"
        case correctedAt = "corrected_at"
    }
}
