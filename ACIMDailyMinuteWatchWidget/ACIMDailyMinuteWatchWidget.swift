import WidgetKit
import SwiftUI
import SwiftData

struct WatchTimelineEntry: TimelineEntry {
    let date: Date
    /// Today's Daily Minute, whole and already spacing-repaired.
    ///
    /// ⛔ There is no lesson number here, and its absence is the point. This
    /// entry used to carry one, drawn from a `DailyLesson` **nothing on the
    /// watch ever writes** — so the circular complication read `L —` on every
    /// face, permanently, and the rectangular one said `No lesson`. A
    /// complication that can only ever show a placeholder is worse than one
    /// that shows what the device actually holds.
    ///
    /// ⛔ It carries the whole passage rather than a cut of it, and **the
    /// truncating belongs to `Text`**. A character count cannot know how much
    /// fits: the same budget is three lines on a 49mm wrist at the smallest
    /// text size and half a line at the largest. Cutting here also cuts
    /// mid-word and with no ellipsis, so the wrist read `… To do n` and gave
    /// the reader no sign that anything followed.
    let text: String?
}

struct WatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchTimelineEntry {
        WatchTimelineEntry(date: .now, text: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchTimelineEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchTimelineEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    /// ⛔ `SharedModelContainer.sharedCacheOnly`, never
    /// `WatchDataService.shared.container` and never plain `shared`.
    ///
    /// Read-only, so by the rule in `SharedModelContainer.swift` it never
    /// mirrors — this extension needs no iCloud entitlement and cannot become a
    /// second container syncing one store inside one process. Dragging
    /// `WatchDataService` in here would have pulled `WatchConnectivity` and a
    /// writable store into an extension that needs neither.
    ///
    /// ⛔ And **cache-only**, because that is the shape `WatchDataService`
    /// writes. `shared` asks the same file for the nine-model schema, Core Data
    /// decides it must migrate in place, the read-only store refuses the write,
    /// and this `guard` takes the placeholder branch — silently, on the face,
    /// while the app beside it shows the passage. `ACIMDailyMinuteTimelineProvider`
    /// keeps `shared` because the phone's app writes the nine.
    private func fetchEntry() -> WatchTimelineEntry {
        guard let container = SharedModelContainer.sharedCacheOnly else {
            return WatchTimelineEntry(date: .now, text: nil)
        }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailyMinute>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let minute = try? context.fetch(descriptor).first else {
            return WatchTimelineEntry(date: .now, text: nil)
        }

        // ⛔ The complication draws feed text directly rather than through
        // `ReadingText`, so it owes the spacing repair by hand.
        return WatchTimelineEntry(date: .now, text: PunctuationSpacing.repaired(minute.text))
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
                Image(systemName: "book.closed")
                    .font(.title3)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("ACIM Daily Minute")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                if let text = entry.text {
                    Text(text)
                        .font(.caption)
                        .lineLimit(3)
                } else {
                    Text("Open to read today's passage")
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        case .accessoryInline:
            Text(entry.text ?? "ACIM Daily Minute")
        default:
            Text("ACIM Daily Minute")
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
        .description("Today's passage at a glance")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
