import WidgetKit

struct WidgetStory: Identifiable {
    let id: String
    let fact: String
    let sourceDisplay: String
    let sourceRatings: [(name: String, accuracy: Double)]
}

struct WidgetStoryEntry: TimelineEntry {
    let date: Date
    let stories: [WidgetStory]

    static var placeholder: WidgetStoryEntry {
        WidgetStoryEntry(
            date: .now,
            stories: [
                WidgetStory(
                    id: "placeholder-1",
                    fact: "Loading verified facts...",
                    sourceDisplay: "ACIM Daily Minute",
                    sourceRatings: []
                )
            ]
        )
    }

    static var empty: WidgetStoryEntry {
        WidgetStoryEntry(date: .now, stories: [])
    }
}
