import AppIntents
import Foundation
import SwiftData

struct GetTodaysReadingIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Today's Reading"
    static let description: IntentDescription = "Read today's passage from ACIM Daily Minute"
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Read-only: a Shortcut reports today's reading, it never changes one.
        let container = try SharedModelContainer.makeContainer(allowsSave: false)
        let context = container.mainContext

        var descriptor = FetchDescriptor<DailyMinute>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let minute = try context.fetch(descriptor).first, !minute.text.isEmpty else {
            return .result(value: "", dialog: "No Daily Minute available yet today.")
        }

        let dialog = "Today's Daily Minute: \(minute.text)"
        return .result(value: minute.text, dialog: IntentDialog(stringLiteral: dialog))
    }
}
