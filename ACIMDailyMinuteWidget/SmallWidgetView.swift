import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        Text(String(entry.minuteText.prefix(60)))
            .font(.callout)
            .lineLimit(4)
            .padding(12)
    }
}
