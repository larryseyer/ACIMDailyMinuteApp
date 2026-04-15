import WidgetKit

struct WidgetStoryEntry: TimelineEntry {
    let date: Date
    let minuteText: String
    let lessonNumber: Int?
    let publishedAt: Date?

    static var placeholder: WidgetStoryEntry {
        WidgetStoryEntry(
            date: .now,
            minuteText: "Each day a passage from A Course in Miracles offers a moment of reflection and stillness.",
            lessonNumber: 1,
            publishedAt: .now
        )
    }

    static var empty: WidgetStoryEntry {
        WidgetStoryEntry(
            date: .now,
            minuteText: "No daily minute available",
            lessonNumber: nil,
            publishedAt: nil
        )
    }
}
