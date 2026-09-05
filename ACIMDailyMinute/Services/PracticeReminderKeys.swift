import Foundation

/// The `UserDefaults` keys the practice reminders are stored under.
///
/// ⛔ **These live apart from `PracticeReminderService` on purpose.** That file
/// is fenced `#if !os(tvOS)` — a television cannot deliver a notification — but
/// these are plain strings, and the app registers their defaults on every
/// platform. A constant does not belong behind a platform fence; the same
/// mistake fenced `Notification.Name` out of the tvOS build and the error it
/// produced named neither the fence nor the cause.
enum PracticeReminderKey {
        static let enabled = PracticeAnchorStore.remindersEnabledKey
        static let windowStart = "practiceWindowStartInterval"
        static let windowEnd = "practiceWindowEndInterval"
        /// 0 means the reader follows the published lesson.
        static let ownStartLesson = "practiceOwnStartLesson"
        /// The reader's own `yyyy-MM-dd`, in their own zone.
        static let ownStartDay = "practiceOwnStartDay"
}
