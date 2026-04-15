#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

struct ACIMDailyMinuteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ACIMDailyMinuteAttributes.self) { context in
            let state = context.state
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "sun.max")
                    Text("ACIM Daily Minute")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    if let n = state.lessonNumber {
                        Text("Lesson \(n)")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                Text(state.minuteText)
                    .font(.subheadline)
                    .lineLimit(4)
            }
            .padding()
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max")
                        Text("ACIM")
                            .font(.caption2)
                    }
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
                    Text(context.state.minuteText)
                        .font(.callout)
                        .lineLimit(3)
                }
            } compactLeading: {
                Image(systemName: "sun.max")
            } compactTrailing: {
                if let n = context.state.lessonNumber {
                    Text("L\(n)")
                        .font(.caption)
                } else {
                    EmptyView()
                }
            } minimal: {
                Image(systemName: "sun.max")
            }
        }
    }
}
#endif
