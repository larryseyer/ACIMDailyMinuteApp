import Foundation
@preconcurrency import UserNotifications

extension Notification.Name {
    /// Posted when a reminder notification is tapped. The object is the
    /// `DeepLinkRoute` the tap should land on, and `ContentView` follows it
    /// exactly as it follows a URL.
    static let reminderTapped = Notification.Name("reminderTapped")
    /// Posted when onboarding is dismissed so the Daily Minute view can
    /// guarantee a fresh fetch even if its `.task` was deferred behind
    /// `fullScreenCover`.
    static let forceMinuteRefresh = Notification.Name("forceMinuteRefresh")
    /// Sibling of `forceMinuteRefresh` for the lessons tab.
    static let forceLessonRefresh = Notification.Name("forceLessonRefresh")
    /// Posted by the macOS ⌘, menu command (and any future trigger) to open
    /// the in-app Settings sheet. The legacy SwiftUI `Settings` scene was
    /// removed so macOS uses the same modal Settings flow as iOS.
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    /// Posted by the macOS "About ACIM Daily Minute" menu command to open
    /// the custom About sheet, replacing AppKit's default minimal panel.
    static let openAboutRequested = Notification.Name("openAboutRequested")
}

/// Presents notifications as banners even when the app is in the foreground,
/// and routes a tap on a reminder to the reading it names.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let route = NotificationManager.route(for: userInfo) else { return }
        NotificationCenter.default.post(name: .reminderTapped, object: route)
    }
}

/// The one place a `UNNotificationRequest` is built.
///
/// ⛔ **Every request this app sends is `interruptionLevel = .active` — never
/// `.timeSensitive`, never `.critical`.** A reminder to practise must yield to
/// Focus and Do Not Disturb, because the reader set those on purpose and a
/// Course lesson is not an emergency. `tools/verify_practice_reminders.sh`
/// greps for this and fails the moment a higher level appears anywhere in the
/// app.
actor NotificationManager {
    static let shared = NotificationManager()
    private let delegate = NotificationDelegate()

    /// The two repeating daily reminders. Each has a switch and a time of its
    /// own, because the Daily Minute and the Daily Lesson are two readings a
    /// reader may want at two different moments of the day.
    enum DailyReminderKind: String, CaseIterable, Sendable {
        case minute
        case lesson

        /// Constant per kind, so re-adding replaces rather than stacks.
        var identifier: String { "acim.dailyReminder.\(rawValue)" }

        var title: String {
            switch self {
            case .minute: "Today's Daily Minute"
            case .lesson: "Today's Workbook lesson"
            }
        }

        var body: String {
            switch self {
            case .minute: "A short passage from the Course is ready."
            case .lesson: "Open today's lesson and begin the day with it."
            }
        }

        var route: DeepLinkRoute {
            switch self {
            case .minute: .today
            case .lesson: .lessons
            }
        }
    }

    /// The identifier the single reminder carried before it was split in two.
    /// A phone that scheduled it keeps it until something removes it, so both
    /// daily schedulers remove it on their way through.
    private static let legacyDailyReminderID = "acim.dailyReminder"

    func setupDelegate() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    // MARK: - The daily reminders

    /// Brings the OS-side schedule for one daily reminder into line with the
    /// reader's switch and time. The time arrives as the
    /// `timeIntervalSinceReferenceDate` the settings key stores; only its
    /// hour and minute matter.
    func applyDailyReminder(_ kind: DailyReminderKind, enabled: Bool, timeInterval: Double) async {
        guard enabled else {
            cancelDailyReminder(kind)
            return
        }
        await requestPermissionIfNeeded()
        let time = Date(timeIntervalSinceReferenceDate: timeInterval)
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        await scheduleDailyReminder(kind, hour: components.hour ?? 9, minute: components.minute ?? 0)
    }

    /// Schedules a recurring local notification at the reader's preferred time
    /// of day. Re-adding with the same identifier replaces any prior schedule,
    /// so callers can safely invoke this on every settings change.
    func scheduleDailyReminder(_ kind: DailyReminderKind, hour: Int, minute: Int) async {
        cancelDailyReminder(kind)

        let content = makeContent(
            title: kind.title,
            body: kind.body,
            userInfo: ["type": "dailyReminder", "kind": kind.rawValue]
        )

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: kind.identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelDailyReminder(_ kind: DailyReminderKind) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [kind.identifier, Self.legacyDailyReminderID]
        )
    }

    // MARK: - The test

    func fireTest() async {
        await requestPermissionIfNeeded()
        let content = makeContent(
            title: "ACIM Daily Minute",
            body: "Test notification — your reminders are configured.",
            userInfo: [:]
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "acim.testNotification",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Shared pieces

    /// Where a tap on a notification lands, read back from the `userInfo`
    /// the request was built with. Nil for anything unrecognised, including
    /// the test notification.
    nonisolated static func route(for userInfo: [AnyHashable: Any]) -> DeepLinkRoute? {
        switch userInfo["type"] as? String {
        case "dailyReminder":
            guard let raw = userInfo["kind"] as? String,
                  let kind = DailyReminderKind(rawValue: raw) else { return nil }
            return kind.route
        default:
            return nil
        }
    }

    /// Every notification's content is built here, so the interruption level
    /// and the chime are decided once.
    private func makeContent(title: String, body: String, userInfo: [String: String]) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferredSound()
        content.userInfo = userInfo
        content.interruptionLevel = .active
        return content
    }

    private func preferredSound() -> UNNotificationSound {
        guard Bundle.main.url(forResource: "ACIMChime", withExtension: "caf") != nil else {
            assertionFailure("ACIMChime.caf missing from bundle")
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName("ACIMChime.caf"))
    }
}
