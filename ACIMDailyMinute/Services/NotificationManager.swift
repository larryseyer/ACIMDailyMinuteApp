import Foundation
@preconcurrency import UserNotifications

extension Notification.Name {
    static let watchedTermsTapped = Notification.Name("watchedTermsTapped")
    /// Posted when onboarding is dismissed so StoriesView can guarantee a
    /// fresh fetch even if its `.task` was deferred behind `fullScreenCover`.
    static let forceStoriesRefresh = Notification.Name("forceStoriesRefresh")
    /// Posted by the macOS ⌘, menu command (and any future trigger) to open
    /// the in-app Settings sheet. The legacy SwiftUI `Settings` scene was
    /// removed so macOS uses the same modal Settings flow as iOS.
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    /// Posted by the macOS "About ACIM Daily Minute" menu command to open the custom
    /// About sheet, replacing AppKit's default minimal panel.
    static let openAboutRequested = Notification.Name("openAboutRequested")
}

/// Presents notifications as banners even when the app is in the foreground.
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
        if userInfo["type"] as? String == "watchedTerms" {
            NotificationCenter.default.post(name: .watchedTermsTapped, object: nil)
        }
    }
}

actor NotificationManager {
    static let shared = NotificationManager()
    private let delegate = NotificationDelegate()

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
        let useCustomSound = UserDefaults.standard.bool(forKey: "useCustomNotificationSound")
        content.sound = useCustomSound
            ? UNNotificationSound(named: UNNotificationSoundName("ACIMChime.caf"))
            : .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
