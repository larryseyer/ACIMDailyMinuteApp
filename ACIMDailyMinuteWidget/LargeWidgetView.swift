import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.isBookmarked {
                HStack {
                    Spacer()
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
