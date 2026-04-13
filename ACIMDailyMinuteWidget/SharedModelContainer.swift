import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.larryseyer.acimdailyminute"

    static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appending(path: "ACIMDailyMinute.sqlite")
    }

    /// Read-only container for widget extension (prevents accidental writes)
    static func createReadOnly() throws -> ModelContainer {
        let schema = Schema([
            Story.self,
            Source.self,
            Correction.self,
            Channel.self,
            ArchivedStory.self,
            Bookmark.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: containerURL,
            allowsSave: false
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
