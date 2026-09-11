import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: Metric.card) {
            Text(entry.minuteText)
                .font(.acimReading)
                .lineLimit(5)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let n = entry.lessonNumber {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Lesson")
                        .font(.acimChipText)
                        .foregroundStyle(.secondary)
                    Text("\(n)")
                        .font(.acimCardTitle)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(Metric.card)
        .widgetURL(URL(string: "acimdailyminute://today")!)
        .containerBackground(Color.acimInk, for: .widget)
    }
}
