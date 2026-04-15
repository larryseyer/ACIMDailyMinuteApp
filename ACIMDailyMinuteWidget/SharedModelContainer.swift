import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.larryseyer.acimdailyminute"

    static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appending(path: "ACIMDailyMinute.sqlite")
    }

    static let shared: ModelContainer = {
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
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create widget ModelContainer: \(error)")
        }
    }()
}
