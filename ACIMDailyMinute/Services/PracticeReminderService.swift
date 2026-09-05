// ⛔ Practice reminders are notifications, and tvOS cannot deliver one. The
// planner behind this service (`Utilities/PracticePlanner.swift`) stays
// unfenced and pure — it is the thing 544,486 checks are written against.
// Only the layer that hands a plan to the notification centre is fenced.
#if !os(tvOS)
import Foundation
import SwiftData

/// Gathers what the planner needs and hands its plan to the notification
/// layer. Thin on purpose: every rule about when a reminder falls is in
/// `PracticePlanner`, which the harness proves; this file only reads the
/// reader's keys, finds the current lesson, and calls it.
///
/// The current lesson comes from `PracticeAnchorStore`, which is fed from
/// three directions — the feed persisting a lesson, the background refresh,
/// and a fold over the store whenever a `ModelContext` is at hand — and is
/// overridden by the reader's own place when they have set one.
@MainActor
enum PracticeReminderService {
    typealias Key = PracticeReminderKey

    /// Picker scrubbing calls `reschedule` many times a second; one plan
    /// half a second after the last call is enough.
    private static var pending: Task<Void, Never>?

    /// Lays the reminders out again from the current keys. Pass a context
    /// when there is one so the newest lesson in the store is counted; the
    /// background refresh has none and relies on what it fetched.
    static func reschedule(in context: ModelContext?) {
        if let context { seedAnchor(from: context) }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let plan = currentPlan()
            await NotificationManager.shared.replacePracticeReminders(with: plan, calendar: Calendar.current)
        }
    }

    /// The lesson the reminders name today, or nil when nothing has been
    /// published yet and the reader has not said where they are.
    static func currentLesson() -> Int? {
        track()?.lesson(on: Date(), calendar: Calendar.current)
    }

    static func currentPlan() -> [PracticePlanner.Reminder] {
        guard UserDefaults.standard.bool(forKey: Key.enabled), let track = track() else { return [] }
        let input = PracticePlanner.Input(
            records: WorkbookPracticeCatalog.all,
            titles: WorkbookCatalog.all,
            window: window(),
            track: track,
            now: Date(),
            calendar: Calendar.current
        )
        return PracticePlanner.plan(input)
    }

    // MARK: - Inputs

    static func track() -> LessonTrack? {
        let defaults = UserDefaults.standard
        let own = defaults.integer(forKey: Key.ownStartLesson)
        if own > 0,
           let raw = defaults.string(forKey: Key.ownStartDay),
           let day = localDayFormatter.date(from: raw) {
            return .own(startLesson: own, startDay: day)
        }
        guard let anchor = PracticeAnchorStore.current else { return nil }
        return .published(latestRecorded: anchor.number, recordedOn: localDay(of: anchor.date))
    }

    static func window() -> PracticeWindow {
        PracticeWindow(
            start: timeOfDay(forKey: Key.windowStart, fallback: TimeOfDay(hour: 7, minute: 0)),
            end: timeOfDay(forKey: Key.windowEnd, fallback: TimeOfDay(hour: 22, minute: 0))
        )
    }

    private static func timeOfDay(forKey key: String, fallback: TimeOfDay) -> TimeOfDay {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        let date = Date(timeIntervalSinceReferenceDate: UserDefaults.standard.double(forKey: key))
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: parts.hour ?? fallback.hour, minute: parts.minute ?? fallback.minute)
    }

    /// The newest recorded lesson in the store, folded the way the Lessons
    /// tab folds it, written to the anchor store where it is newer.
    static func seedAnchor(from context: ModelContext) {
        let lessons = (try? context.fetch(FetchDescriptor<DailyLesson>())) ?? []
        let archived = (try? context.fetch(FetchDescriptor<ArchivedReading>(
            predicate: #Predicate { $0.channel == "daily-lesson" }
        ))) ?? []
        guard let anchor = LessonSchedule.anchor(
            from: lessons.map { ($0.lessonNumber, $0.publishedAt) }
                + archived.map { ($0.lessonNumber ?? 0, $0.timestamp) }
        ) else { return }
        PracticeAnchorStore.record(lesson: anchor.number, day: LessonSchedule.formatted(anchor.date))
    }

    // MARK: - Days

    /// The reader's own `yyyy-MM-dd`, in the reader's zone — what
    /// `practiceOwnStartDay` holds.
    static let localDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.current.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// A publication day arrives as UTC midnight. Read as an instant in the
    /// reader's zone it is the evening before anywhere west of Greenwich,
    /// which would put every lesson a day early; so the day is carried across
    /// by its name and becomes the reader's own midnight.
    static func localDay(of publicationDay: Date) -> Date {
        localDayFormatter.date(from: LessonSchedule.formatted(publicationDay))
            ?? Calendar.current.startOfDay(for: publicationDay)
    }
}
#endif
