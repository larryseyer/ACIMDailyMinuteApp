import Foundation
import SwiftData

/// Lightweight data service for the watch — fetches stories directly from www.acimdailyminute.org.
/// No dependency on the iPhone app; the watch is a standalone consumer.
actor WatchDataService {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchStories() async throws {
        let url = URL(string: "https://www.acimdailyminute.org/stories.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WatchStoriesResponse.self, from: data)

        let context = ModelContext(modelContainer)
        for dto in response.stories {
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
            }
        }
        try context.save()
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - DTOs (self-contained, no dependency on main app's DataService)

private struct WatchStoriesResponse: Codable, Sendable {
    let date: String
    let source: String?
    let stories: [WatchStoryDTO]
}

private struct WatchStoryDTO: Codable, Sendable {
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
