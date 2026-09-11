import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.dateText(entry.date))
                .font(.acimMasthead)
                .foregroundStyle(.primary)
                .lineSpacing(Metric.mastheadGap)
            Rectangle()
                .fill(Color.acimRule)
                .frame(height: 1)
                .padding(.top, 14)
            Text(entry.minuteText)
                .font(.acimReading)
                .lineSpacing(Metric.readingGap)
                .lineLimit(8)
                .truncationMode(.tail)
                .padding(.top, Metric.block)
            CitationLabel(raw: entry.citation)
                .padding(.top, Metric.row)
            Spacer(minLength: 0)
            if let next = entry.nextPracticeText {
                HStack(alignment: .firstTextBaseline) {
                    Text("Next practice")
                        .font(.acimCardTitle)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(next)
                        .font(.acimChipText)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.acimRaised)
                        .clipShape(Capsule())
                }
                .padding(.top, Metric.block)
            }
        }
        .padding(Metric.card)
        .widgetURL(URL(string: "acimdailyminute://today")!)
        .containerBackground(Color.acimInk, for: .widget)
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: date)
    }
}
