import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: WidgetStoryEntry

    var body: some View {
        Text(String(entry.minuteText.prefix(120)))
            .font(.subheadline)
            .lineLimit(5)
            .padding(12)
    }
}
