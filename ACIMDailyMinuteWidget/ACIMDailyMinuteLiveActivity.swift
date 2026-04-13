#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

struct ACIMDailyMinuteLiveActivity: Widget {
    private static let brandGold = Color(red: 212/255, green: 175/255, blue: 55/255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ACIMActivityAttributes.self) { context in
            // Lock Screen / Banner presentation
            lockScreenView(context: context)
                .activityBackgroundTint(Color(white: 0.1))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    Text("ACIM DAILY MINUTE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Self.brandGold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.storyCount) new fact\(context.state.storyCount == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(white: 0.88))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.latestFact)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.88))
                            .lineLimit(2)

                        HStack {
                            Spacer()
                            Link(destination: URL(string: "acimdailyminute://stories")!) {
                                Text("Read Now \u{25B8}")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Self.brandGold)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            } compactTrailing: {
                Text("\(context.state.storyCount) new")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.88))
            } minimal: {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<ACIMActivityAttributes>) -> some View {
        if context.state.storyCount == 0 {
            // Dismissal state
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Self.brandGold)
                Text("Caught up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.88))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            HStack(spacing: 12) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(context.state.storyCount) new verified fact\(context.state.storyCount == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.88))

                    Text(context.state.latestFact)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.53))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
}
#endif
