import Foundation

/// The names the app posts and observes, on every platform.
///
/// ⛔ **These live apart from `NotificationManager` on purpose.** That file is
/// fenced `#if !os(tvOS)` — tvOS has UserNotifications but no deliverable local
/// notifications, only badging — and these are plain constants that
/// `ContentView` subscribes to everywhere. Leaving them inside the fence took
/// `.openSettingsRequested` and `.reminderTapped` out of the tvOS build with it,
/// and the failure read as `Notification.Name has no member`, which says nothing
/// about the real cause. A constant does not belong behind a platform fence.
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
