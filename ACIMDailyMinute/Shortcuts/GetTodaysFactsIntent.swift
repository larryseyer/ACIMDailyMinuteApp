import AppIntents
import SwiftData
import Foundation

struct GetTodaysFactsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Today's Facts"
    static let description: IntentDescription = "Read today's verified news facts from ACIM Daily Minute"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.createReadOnly()
        let context = ModelContext(container)

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<Story> {
            $0.publishedAt >= startOfDay && $0.publishedAt < endOfDay
        }
        var descriptor = FetchDescriptor<Story>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20

        let stories = try context.fetch(descriptor)

        guard !stories.isEmpty else {
            return .result(dialog: "No stories published yet today. Check back later.")
        }

        let lines = stories.enumerated().map { index, story in
            "\(index + 1). \(story.fact) (\(story.sourceDisplay))"
        }
        let summary = "Today's \(stories.count) verified fact\(stories.count == 1 ? "" : "s"):\n\n\(lines.joined(separator: "\n"))"

        return .result(dialog: "\(summary)")
    }
}
