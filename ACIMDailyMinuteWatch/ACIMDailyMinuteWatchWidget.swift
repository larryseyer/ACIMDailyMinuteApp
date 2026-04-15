import WidgetKit
import SwiftUI
import SwiftData

struct WatchTimelineEntry: TimelineEntry {
    let date: Date
    let lessonNumber: Int?
    let minuteSnippet: String
}

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchTimelineEntry {
        WatchTimelineEntry(date: .now, lessonNumber: nil, minuteSnippet: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchTimelineEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchTimelineEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> WatchTimelineEntry {
        let context = ModelContext(SharedModelContainer.shared)
        var descriptor = FetchDescriptor<DailyMinute>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let minute = try? context.fetch(descriptor).first else {
            return WatchTimelineEntry(date: .now, lessonNumber: nil, minuteSnippet: "No daily minute yet")
        }

        var lessonDescriptor = FetchDescriptor<DailyLesson>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        lessonDescriptor.fetchLimit = 1
        let lessonNumber = try? context.fetch(lessonDescriptor).first?.lessonNumber

        return WatchTimelineEntry(
            date: .now,
            lessonNumber: lessonNumber,
            minuteSnippet: String(minute.text.prefix(100))
        )
    }
}

struct WatchCircularView: View {
    let entry: WatchTimelineEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("L")
                    .font(.caption2)
                Text(entry.lessonNumber.map(String.init) ?? "—")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
            }
        }
    }
}

struct WatchRectangularView: View {
    let entry: WatchTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "sun.max")
                Text("ACIM")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            Text(entry.minuteSnippet)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
    }
}

struct WatchInlineView: View {
    let entry: WatchTimelineEntry

    var body: some View {
        Text(entry.lessonNumber.map { "ACIM Lesson \($0)" } ?? "ACIM")
    }
}

struct ACIMDailyMinuteWatchWidget: Widget {
    let kind = "ACIMDailyMinuteWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            WatchCircularView(entry: entry)
        }
        .configurationDisplayName("ACIM Daily Minute")
        .description("Today's lesson at a glance")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
