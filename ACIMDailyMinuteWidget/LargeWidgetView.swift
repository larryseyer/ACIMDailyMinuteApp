import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        Text(String(entry.minuteText.prefix(300)))
            .font(.body)
            .lineLimit(12)
            .padding(16)
    }
}
