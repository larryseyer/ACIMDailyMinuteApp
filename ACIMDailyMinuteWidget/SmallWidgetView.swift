import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
