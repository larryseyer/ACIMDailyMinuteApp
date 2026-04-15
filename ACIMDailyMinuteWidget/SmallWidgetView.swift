import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetStoryEntry

    private var relativeDateString: String {
        guard let date = entry.publishedAt else { return "No date" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(relativeDateString)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.minuteText)
                .font(.callout)
                .lineLimit(4)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if let n = entry.lessonNumber {
                Text("Lesson \(n)")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
        }
        .padding(12)
        .widgetURL(URL(string: "acimdailyminute://today")!)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
