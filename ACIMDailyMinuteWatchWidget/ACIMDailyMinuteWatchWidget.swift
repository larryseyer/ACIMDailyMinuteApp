import WidgetKit
import SwiftUI
import SwiftData

struct WatchTimelineEntry: TimelineEntry {
    let date: Date
    /// The opening of today's Daily Minute, already spacing-repaired.
    ///
    /// ⛔ There is no lesson number here, and its absence is the point. This
    /// entry used to carry one, drawn from a `DailyLesson` **nothing on the
    /// watch ever writes** — so the circular complication read `L —` on every
    /// face, permanently, and the rectangular one said `No lesson`. A
    /// complication that can only ever show a placeholder is worse than one
    /// that shows what the device actually holds.
    let snippet: String?
}

struct WatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchTimelineEntry {
        WatchTimelineEntry(date: .now, snippet: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchTimelineEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchTimelineEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    /// ⛔ `SharedModelContainer.shared`, never `WatchDataService.shared.container`.
    /// The shared one is **read-only**, and by the rule in
    /// `SharedModelContainer.swift` a read-only configuration never mirrors — so
    /// this extension needs no iCloud entitlement and cannot become a second
    /// container syncing one store inside one process. It is the same call
    /// `ACIMDailyMinuteTimelineProvider` makes on iOS, and dragging
    /// `WatchDataService` in here would have pulled `WatchConnectivity` and a
    /// writable store into an extension that needs neither.
    private func fetchEntry() -> WatchTimelineEntry {
        guard let container = SharedModelContainer.shared else {
            return WatchTimelineEntry(date: .now, snippet: nil)
        }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DailyMinute>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let minute = try? context.fetch(descriptor).first else {
            return WatchTimelineEntry(date: .now, snippet: nil)
        }

        // ⛔ Repair FIRST, then cut. The complication draws feed text directly
        // rather than through `ReadingText`, so it owes the spacing repair by
        // hand — and truncating before repairing would cut inside a join the
        // repair was about to make.
        let repaired = PunctuationSpacing.repaired(minute.text)
        return WatchTimelineEntry(date: .now, snippet: String(repaired.prefix(100)))
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
                if let snippet = entry.snippet {
                    Text(snippet)
                        .font(.caption)
                        .lineLimit(3)
                } else {
                    Text("Open to read today's passage")
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        case .accessoryInline:
            Text(entry.snippet.map { String($0.prefix(40)) } ?? "ACIM Daily Minute")
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
