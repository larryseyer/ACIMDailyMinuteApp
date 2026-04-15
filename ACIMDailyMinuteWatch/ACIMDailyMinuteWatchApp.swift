import SwiftUI
import SwiftData

@main
struct ACIMDailyMinuteWatchApp: App {
    var sharedModelContainer: ModelContainer = {
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
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
