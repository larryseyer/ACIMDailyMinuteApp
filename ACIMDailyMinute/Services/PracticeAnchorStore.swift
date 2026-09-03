import Foundation

/// The newest published lesson the app has heard of without opening its
/// store — what the background refresh learned from the feed.
///
/// The Today and Lessons tabs know the current lesson from the `DailyLesson`
/// rows the feed has been persisted into. A background refresh has no
/// `ModelContext`, so it leaves its answer here instead, and the practice
/// reminders take the newer of the two. ⛔ These two keys are device-local
/// and named in `BackupService`'s exclusion list: they describe what THIS
/// device last fetched, not anything the reader chose.
enum PracticeAnchorStore {
    /// The reader's switch for the practice reminders, read here so the
    /// background refresh can decide whether a fetch has any purpose.
    static let remindersEnabledKey = "practiceRemindersEnabled"

    private static let lessonKey = "practiceAnchorLesson"
    private static let dayKey = "practiceAnchorDay"

    /// Records a published lesson, keeping only the newest. `day` is the
    /// publisher's own `yyyy-MM-dd`.
    static func record(lesson: Int, day: String) {
        let defaults = UserDefaults.standard
        guard lesson > defaults.integer(forKey: lessonKey) else { return }
        defaults.set(lesson, forKey: lessonKey)
        defaults.set(day, forKey: dayKey)
    }

    /// The newest recorded lesson and the day it was published, or nil when
    /// no refresh has ever learned one.
    static var current: (number: Int, date: Date)? {
        let defaults = UserDefaults.standard
        let lesson = defaults.integer(forKey: lessonKey)
        guard lesson > 0,
              let raw = defaults.string(forKey: dayKey),
              let date = LessonSchedule.day(from: raw) else { return nil }
        return (lesson, date)
    }
}
