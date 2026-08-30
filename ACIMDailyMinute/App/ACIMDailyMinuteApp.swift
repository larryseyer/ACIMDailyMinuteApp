import SwiftUI
import SwiftData
#if os(iOS)
import UIKit

/// Owns the app's allowed interface orientations.
///
/// A `requestGeometryUpdate` on its own is reverted by the system almost
/// immediately; the window's delegate has to agree by reporting a matching
/// supported-orientation mask. This holds that mask so the lesson video can
/// force landscape while it is on screen and hand control back afterwards.
final class OrientationController: NSObject, UIApplicationDelegate {
    static var mask: UIInterfaceOrientationMask = .all

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.mask
    }

    /// Forcing rotation is an iPhone-only behavior. iPad keeps its freedom to
    /// rotate — the screen is large enough that a forced turn is an
    /// interruption rather than a help, and it breaks Split View.
    static var forcesRotation: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    static func lockLandscape() {
        guard forcesRotation else { return }
        apply(.landscape, rotatingTo: .landscapeRight)
    }

    static func unlock() {
        guard forcesRotation else { return }
        apply(.all, rotatingTo: .portrait)
    }

    private static func apply(
        _ newMask: UIInterfaceOrientationMask,
        rotatingTo orientation: UIInterfaceOrientationMask
    ) {
        mask = newMask
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        scene.keyWindow?.rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
#endif

@main
struct ACIMDailyMinuteApp: App {
    @Environment(\.scenePhase) private var scenePhase
#if os(iOS)
    @UIApplicationDelegateAdaptor(OrientationController.self) private var orientationController
#endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyMinute.self,
            DailyLesson.self,
            Bookmark.self,
            ArchivedReading.self,
            Channel.self,
            CachedPodcastEpisode.self,
            SegmentMedia.self
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
        let defaultReminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        UserDefaults.standard.register(defaults: [
            "useCustomNotificationSound": true,
            "notifyNewMinute": true,
            "notifyNewLesson": true,
            "notifyPhraseMatches": true,
            "notifyLiveActivities": false,
            "dailyReminderEnabled": false,
            "dailyReminderTimeInterval": defaultReminderTime.timeIntervalSinceReferenceDate
        ])
        #if os(iOS)
        BackgroundRefreshManager.register()
        _ = PhoneWatchSyncService.shared
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
                    // Ask once, at launch. This used to be reached only by
                    // switching on the daily reminder, so anyone who left that
                    // off was never prompted — and every new-minute, new-lesson
                    // and watched-phrase notification was silently discarded
                    // for want of authorisation.
                    Task { await NotificationManager.shared.requestPermissionIfNeeded() }
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
