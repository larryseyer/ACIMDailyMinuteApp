import WidgetKit
import SwiftUI

struct ACIMDailyMinuteWidget: Widget {
    let kind: String = "ACIMDailyMinuteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ACIMDailyMinuteTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ACIM Daily Minute")
        .description("Today's daily minute at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetStoryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

@main
struct ACIMDailyMinuteWidgetBundle: WidgetBundle {
    var body: some Widget {
        ACIMDailyMinuteWidget()
        #if os(iOS)
        ACIMDailyMinuteLiveActivity()
        #endif
    }
}
