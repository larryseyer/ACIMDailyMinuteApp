import Foundation
@preconcurrency import UserNotifications

extension Notification.Name {
    /// Posted when a phrase-match notification is tapped — Settings opens
    /// the Phrases editor so the user can immediately tweak the watchlist.
    static let phrasesTapped = Notification.Name("phrasesTapped")
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
/// and routes phrase-match taps back into the Settings UI.
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
        if userInfo["type"] as? String == "phraseMatch" {
            NotificationCenter.default.post(name: .phrasesTapped, object: nil)
        }
    }
}

actor NotificationManager {
    static let shared = NotificationManager()
    private let delegate = NotificationDelegate()

    /// Identifier for the user's daily reading reminder, scheduled by
    /// `scheduleDailyReminder(hour:minute:)`. Constant string so subsequent
    /// calls update the existing trigger instead of stacking duplicates.
    private static let dailyReminderID = "acim.dailyReminder"

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

    func sendNotification(title: String, body: String, identifier: String, userInfo: [String: String] = [:]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferredSound()
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedules a recurring local notification at the user's preferred time
    /// of day. Re-adding with the same identifier replaces any prior
    /// schedule, so callers can safely invoke this on every settings change.
    func scheduleDailyReminder(hour: Int = 7, minute: Int = 0) async {
        await cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Today's ACIM reading"
        content.body = "A new Daily Minute and Lesson are ready."
        content.sound = preferredSound()
        content.userInfo = ["type": "dailyReminder"]

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderID,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func fireTest() async {
        await requestPermissionIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "ACIM Daily Minute"
        content.body = "Test notification — your daily reminder is configured."
        content.sound = preferredSound()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "acim.testNotification",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelDailyReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.dailyReminderID]
        )
    }

    private func preferredSound() -> UNNotificationSound {
        guard Bundle.main.url(forResource: "ACIMChime", withExtension: "caf") != nil else {
            assertionFailure("ACIMChime.caf missing from bundle")
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName("ACIMChime.caf"))
    }
}
