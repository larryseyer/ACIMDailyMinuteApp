import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.tight) {
            Text(entry.minuteText)
                .font(.acimReading)
                .lineLimit(3)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            CitationLabel(raw: entry.citation)
        }
        .padding(Metric.card)
        .widgetURL(URL(string: "acimdailyminute://today")!)
        .containerBackground(Color.acimInk, for: .widget)
    }
}
