import SwiftUI
import WidgetKit

private func relativeDateString(from date: Date?) -> String {
    guard let date else { return "No date" }
    if Calendar.current.isDateInToday(date) { return "Today" }
    if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
    return date.formatted(.dateTime.month(.abbreviated).day())
}

struct LargeWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(relativeDateString(from: entry.publishedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.tint)
                        .font(.caption)
                }
            }
            Text(entry.minuteText)
                .font(.body)
                .lineLimit(12)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if let n = entry.lessonNumber {
                HStack {
                    Image(systemName: "book.closed")
                    Text("Lesson \(n)")
                }
                .font(.caption)
                .foregroundStyle(.tint)
            }
        }
        .padding(16)
        .widgetURL(URL(string: "acimdailyminute://today")!)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
