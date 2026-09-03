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
    @AppStorage(Appearance.key) private var appearance = Appearance.dark.rawValue
#if os(iOS)
    @UIApplicationDelegateAdaptor(OrientationController.self) private var orientationController
#endif

    /// ⛔ The migration runs **here**, inside the container's own initializer,
    /// rather than in `onAppear`. By the time a view appears its `@Query`
    /// properties have already fetched, and a reader whose highlights had not
    /// been lifted across yet would watch an empty Saved tab draw itself.
    var sharedModelContainer: ModelContainer = {
        do {
            let container = try SharedModelContainer.makeContainer(allowsSave: true)
            ReaderStoreMigration.runIfNeeded(into: container)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let defaultReminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        UserDefaults.standard.register(defaults: [
            Appearance.key: Appearance.dark.rawValue,
            "notifyLiveActivities": false,
            // `dailyReminder*` is the Daily Minute reminder. The keys predate
            // the split and keep their names so a reader who had the one
            // reminder on still has one, at the same time, about the minute.
            "dailyReminderEnabled": false,
            "dailyReminderTimeInterval": defaultReminderTime.timeIntervalSinceReferenceDate,
            "lessonReminderEnabled": false,
            "lessonReminderTimeInterval": defaultReminderTime.timeIntervalSinceReferenceDate
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
                .preferredColorScheme((Appearance(rawValue: appearance) ?? .dark).colorScheme)
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 640)
                #endif
                .onAppear {
                    #if os(iOS)
                    BackgroundRefreshManager.scheduleRefresh()
                    #endif
                    // Ask once, at launch, so the answer is already known when
                    // a reminder is switched on rather than asked for in the
                    // middle of that gesture.
                    Task { await NotificationManager.shared.requestPermissionIfNeeded() }
                    // An annotation made on an archived minute knows only its
                    // date. Once the feed names the segment behind that date,
                    // the key is rewritten so the mark points at the permanent
                    // bundled corpus instead of the rolling window.
                    AnnotationStore.upgradeDateKeys(in: sharedModelContainer.mainContext)
                }
                #if os(iOS)
                .onChange(of: scenePhase) { _, newPhase in
                    // Foreground catch-up: BGAppRefreshTask is opportunistic
                    // on iOS and may never fire on older devices, so coming
                    // to the foreground is the primary moment the app learns
                    // which lesson the practice reminders should name.
                    if newPhase == .active {
                        BackgroundRefreshManager.performForegroundCheck()
                    }
                }
                #endif
                .onChange(of: scenePhase) { _, newPhase in
                    // A mark made and the app put away inside the debounce
                    // would otherwise wait for the next launch to reach the
                    // reader's folder.
                    if newPhase != .active {
                        FolderCopyService.flush()
                    }
                }
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
