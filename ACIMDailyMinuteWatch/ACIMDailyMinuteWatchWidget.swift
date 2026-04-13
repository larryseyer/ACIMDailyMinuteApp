import WidgetKit
import SwiftUI
import SwiftData

struct WatchStoryEntry: TimelineEntry {
    let date: Date
    let storyCount: Int
    let latestFact: String
}

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchStoryEntry {
        WatchStoryEntry(date: .now, storyCount: 0, latestFact: "Loading facts...")
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStoryEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStoryEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> WatchStoryEntry {
        do {
            let container = try SharedModelContainer.createReadOnly()
            let context = ModelContext(container)
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let predicate = #Predicate<Story> { $0.publishedAt >= startOfDay }
            var descriptor = FetchDescriptor<Story>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 20
            let stories = try context.fetch(descriptor)
            return WatchStoryEntry(
                date: .now,
                storyCount: stories.count,
                latestFact: stories.first?.fact ?? "No stories yet"
            )
        } catch {
            return WatchStoryEntry(date: .now, storyCount: 0, latestFact: "Unable to load")
        }
    }
}

struct WatchCircularView: View {
    let entry: WatchStoryEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.storyCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("facts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WatchRectangularView: View {
    let entry: WatchStoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "newspaper")
                Text("ACIM Daily Minute")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            Text(entry.latestFact)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
    }
}

struct WatchInlineView: View {
    let entry: WatchStoryEntry

    var body: some View {
        Text("\(entry.storyCount) fact\(entry.storyCount == 1 ? "" : "s") today")
    }
}

struct ACIMDailyMinuteWatchWidget: Widget {
    let kind = "ACIMDailyMinuteWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            WatchCircularView(entry: entry)
        }
        .configurationDisplayName("ACIM Daily Minute")
        .description("Today's verified fact count")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
