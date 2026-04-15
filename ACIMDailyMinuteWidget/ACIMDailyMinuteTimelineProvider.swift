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
            let container = SharedModelContainer.shared
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

            return WidgetStoryEntry(
                date: .now,
                minuteText: minute.text,
                lessonNumber: lessons.first?.lessonNumber,
                publishedAt: minute.publishedAt
            )
        } catch {
            return .empty
        }
    }
}
