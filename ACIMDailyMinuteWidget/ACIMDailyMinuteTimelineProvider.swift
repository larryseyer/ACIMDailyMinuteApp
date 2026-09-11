import WidgetKit
import SwiftData

struct ACIMDailyMinuteTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetStoryEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetStoryEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetStoryEntry>) -> Void) {
        let entry = fetchEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }

    private func fetchEntry() -> WidgetStoryEntry {
        do {
            // `shared` is optional now: a widget that cannot open the store
            // draws its empty state instead of taking the process down.
            guard let container = SharedModelContainer.shared else { return .empty }
            let context = ModelContext(container)

            var minuteDescriptor = FetchDescriptor<DailyMinute>(
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            minuteDescriptor.fetchLimit = 1
            let minutes = try context.fetch(minuteDescriptor)

            guard let minute = minutes.first else { return .empty }

            var lessonDescriptor = FetchDescriptor<DailyLesson>(
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            lessonDescriptor.fetchLimit = 1
            let lessons = try context.fetch(lessonDescriptor)
            let lessonNumber = lessons.first?.lessonNumber

            return WidgetStoryEntry(
                date: .now,
                // The widget draws the feed's text directly rather than through
                // `ReadingText.displayString`, so the spacing repair has to
                // happen here or `Source,Which` reaches a lock screen.
                minuteText: PunctuationSpacing.repaired(minute.text),
                citation: CorpusService.shared.segment(id: minute.segmentId)?.citation,
                lessonNumber: lessonNumber,
                publishedAt: minute.publishedAt,
                nextPracticeText: Self.nextPracticeText(lessonNumber: lessonNumber)
            )
        } catch {
            return .empty
        }
    }

    /// Same slot walk `PracticeCard` uses. The widget cannot see the app's
    /// `UserDefaults.standard` window or own-start lesson, so this uses the
    /// publisher's lesson and the 7–22 fallback the service uses when those
    /// keys are unset.
    private static func nextPracticeText(lessonNumber: Int?) -> String? {
        guard let lessonNumber,
              let record = WorkbookPracticeCatalog.record(for: lessonNumber) else {
            return nil
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        let window = PracticeWindow(
            start: TimeOfDay(hour: 7, minute: 0),
            end: TimeOfDay(hour: 22, minute: 0)
        )
        guard let slot = PracticePlanner.slots(for: record, in: window)
            .first(where: { $0.time >= now }) else {
            return nil
        }
        return timeText(slot.time)
    }

    private static func timeText(_ time: TimeOfDay) -> String {
        let hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12
        let suffix = time.hour < 12 ? "am" : "pm"
        if time.minute == 0 { return "\(hour12) \(suffix)" }
        return String(format: "%d:%02d %@", hour12, time.minute, suffix)
    }
}
