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
            DailyMinute.self,
            DailyLesson.self,
            Bookmark.self,
            ArchivedReading.self,
            Channel.self,
            CachedPodcastEpisode.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: containerURL,
            allowsSave: false
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
