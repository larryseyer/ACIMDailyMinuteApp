import AppIntents
import Foundation

struct GetTodaysFactsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Today's Reading"
    static let description: IntentDescription = "Read today's passage from ACIM Daily Minute"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Today's ACIM Daily Minute will be available in a future update.")
    }
}
