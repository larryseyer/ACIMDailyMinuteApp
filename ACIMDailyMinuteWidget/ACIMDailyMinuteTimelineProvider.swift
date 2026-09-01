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

            let bookmarkKey = "minute:\(minute.segmentHash)"
            var bookmarkDescriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate { $0.itemKey == bookmarkKey }
            )
            bookmarkDescriptor.fetchLimit = 1
            let bookmarks = try context.fetch(bookmarkDescriptor)

            return WidgetStoryEntry(
                date: .now,
                // The widget draws the feed's text directly rather than through
                // `ReadingText.displayString`, so the spacing repair has to
                // happen here or `Source,Which` reaches a lock screen.
                minuteText: PunctuationSpacing.repaired(minute.text),
                lessonNumber: lessons.first?.lessonNumber,
                publishedAt: minute.publishedAt,
                isBookmarked: !bookmarks.isEmpty
            )
        } catch {
            return .empty
        }
    }
}
