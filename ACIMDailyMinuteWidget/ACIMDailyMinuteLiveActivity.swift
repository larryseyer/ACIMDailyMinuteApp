#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

struct ACIMDailyMinuteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ACIMActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "sun.max")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACIM Daily Minute")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(context.state.latestText)
                        .font(.subheadline)
                        .lineLimit(2)
                }
            }
            .padding()
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sun.max")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let n = context.state.lessonNumber {
                        Text("Lesson \(n)")
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.latestText)
                        .font(.callout)
                        .lineLimit(3)
                }
            } compactLeading: {
                Image(systemName: "sun.max")
            } compactTrailing: {
                if let n = context.state.lessonNumber {
                    Text("L\(n)")
                        .font(.caption)
                }
            } minimal: {
                Image(systemName: "sun.max")
            }
        }
    }
}
#endif
