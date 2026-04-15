import SwiftUI
import SwiftData

@main
struct ACIMDailyMinuteApp: App {
    @Environment(\.scenePhase) private var scenePhase

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

    init() {
        UserDefaults.standard.register(defaults: [
            "useCustomNotificationSound": true,
            "notifyNewMinute": true,
            "notifyNewLesson": true,
            "notifyPhraseMatches": true,
            "notifyLiveActivities": false
        ])
        #if os(iOS)
        BackgroundRefreshManager.register()
        #endif
        Task { await NotificationManager.shared.setupDelegate() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 640)
                #endif
                .onAppear {
                    #if os(iOS)
                    BackgroundRefreshManager.scheduleRefresh()
                    #endif
                }
                #if os(iOS)
                .onChange(of: scenePhase) { _, newPhase in
                    // Foreground catch-up: BGAppRefreshTask is opportunistic
                    // on iOS and may never fire on older devices. Running the
                    // notification checks when the app becomes active is the
                    // only way to guarantee the user sees new facts/
                    // corrections they missed while the app was closed.
                    if newPhase == .active {
                        BackgroundRefreshManager.performForegroundCheck()
                    }
                }
                #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 500, height: 900)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ACIM Daily Minute") {
                    NotificationCenter.default.post(
                        name: .openAboutRequested,
                        object: nil
                    )
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(
                        name: .openSettingsRequested,
                        object: nil
                    )
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}
