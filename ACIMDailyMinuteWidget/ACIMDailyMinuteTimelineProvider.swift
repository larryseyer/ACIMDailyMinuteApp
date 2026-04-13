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
        completion(fetchEntry(limit: storyLimit(for: context.family)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetStoryEntry>) -> Void) {
        let entry = fetchEntry(limit: storyLimit(for: context.family))
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func storyLimit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 3
        case .systemLarge: return 5
        default: return 3
        }
    }

    private func fetchEntry(limit: Int) -> WidgetStoryEntry {
        do {
            let container = try SharedModelContainer.createReadOnly()
            let context = ModelContext(container)

            var storyDescriptor = FetchDescriptor<Story>(
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            storyDescriptor.fetchLimit = limit
            let stories = try context.fetch(storyDescriptor)

            guard !stories.isEmpty else { return .empty }

            let sourceDescriptor = FetchDescriptor<Source>()
            let allSources = try context.fetch(sourceDescriptor)
            let sourceMap = Dictionary(uniqueKeysWithValues: allSources.map { ($0.name, $0.accuracy) })

            let widgetStories = stories.map { story in
                let sourceNames = story.sourceDisplay
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }

                let ratings = sourceNames.compactMap { name in
                    sourceMap[name].map { (name: name, accuracy: $0) }
                }

                return WidgetStory(
                    id: story.id,
                    fact: story.fact,
                    sourceDisplay: story.sourceDisplay,
                    sourceRatings: ratings
                )
            }

            return WidgetStoryEntry(date: .now, stories: widgetStories)
        } catch {
            return .empty
        }
    }
}
