import WidgetKit
import SwiftUI
import SwiftData

struct WatchTimelineEntry: TimelineEntry {
    let date: Date
    let lessonNumber: Int?
    let firstPhraseSnippet: String?
}

struct WatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchTimelineEntry {
        WatchTimelineEntry(date: .now, lessonNumber: nil, firstPhraseSnippet: "Loading...")
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
        let context = ModelContext(WatchDataService.shared.container)
        var descriptor = FetchDescriptor<DailyMinute>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let minute = try? context.fetch(descriptor).first else {
            return WatchTimelineEntry(date: .now, lessonNumber: nil, firstPhraseSnippet: nil)
        }

        var lessonDescriptor = FetchDescriptor<DailyLesson>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        lessonDescriptor.fetchLimit = 1
        let lessonNumber = try? context.fetch(lessonDescriptor).first?.lessonNumber

        return WatchTimelineEntry(
            date: .now,
            lessonNumber: lessonNumber,
            firstPhraseSnippet: String(minute.text.prefix(100))
        )
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: WatchTimelineEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("L")
                        .font(.caption2)
                    Text(entry.lessonNumber.map(String.init) ?? "\u{2014}")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("ACIM")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                Text(entry.lessonNumber.map { "Lesson \($0)" } ?? "No lesson")
                    .font(.headline)
                if let snippet = entry.firstPhraseSnippet {
                    Text(snippet)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        case .accessoryInline:
            Text(entry.lessonNumber.map { "ACIM Lesson \($0)" } ?? "ACIM")
        default:
            Text("ACIM")
        }
    }
}

struct ACIMDailyMinuteWatchWidget: Widget {
    let kind = "com.larryseyer.acimdailyminute.watch.complication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("ACIM Daily Minute")
        .description("Today's lesson at a glance")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
