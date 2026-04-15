import SwiftUI
import WidgetKit

private func relativeDateString(from date: Date?) -> String {
    guard let date else { return "No date" }
    if Calendar.current.isDateInToday(date) { return "Today" }
    if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
    return date.formatted(.dateTime.month(.abbreviated).day())
}

struct MediumWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(relativeDateString(from: entry.publishedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.minuteText)
                    .font(.subheadline)
                    .lineLimit(5)
                    .truncationMode(.tail)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                if let n = entry.lessonNumber {
                    Text("Lesson")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(n)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Spacer(minLength: 0)
                Text("Open today's minute")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            .frame(width: 100)
        }
        .padding(12)
        .widgetURL(URL(string: "acimdailyminute://today")!)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
