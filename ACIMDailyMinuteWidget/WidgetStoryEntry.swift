import WidgetKit

struct WidgetStoryEntry: TimelineEntry {
    let date: Date
    let minuteText: String
    let citation: String?
    let lessonNumber: Int?
    let publishedAt: Date?
    let nextPracticeText: String?

    static var placeholder: WidgetStoryEntry {
        WidgetStoryEntry(
            date: .now,
            minuteText: "Each day a passage from A Course in Miracles offers a moment of reflection and stillness.",
            citation: "W-1",
            lessonNumber: 1,
            publishedAt: .now,
            nextPracticeText: "7 am"
        )
    }

    static var empty: WidgetStoryEntry {
        WidgetStoryEntry(
            date: .now,
            minuteText: "No daily minute available",
            citation: nil,
            lessonNumber: nil,
            publishedAt: nil,
            nextPracticeText: nil
        )
    }
}
