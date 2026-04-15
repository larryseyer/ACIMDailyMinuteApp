import SwiftUI
import SwiftData

@main
struct ACIMDailyMinuteWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(WatchDataService.shared.container)
    }
}
