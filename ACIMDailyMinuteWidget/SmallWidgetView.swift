import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetStoryEntry

    private let brandGold = Color(red: 212/255, green: 175/255, blue: 55/255)

    var body: some View {
        if let story = entry.stories.first {
            VStack(alignment: .leading, spacing: 0) {
                Text("ACIM DAILY MINUTE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(brandGold)

                Spacer().frame(height: 8)

                Text(story.fact)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.88))
                    .lineLimit(4)
                    .frame(maxHeight: .infinity, alignment: .top)

                Text(story.sourceDisplay)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.53))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "acimdailyminute://stories"))
        } else {
            VStack(spacing: 8) {
                Text("ACIM DAILY MINUTE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(brandGold)
                Text("Open ACIM Daily Minute\nto load stories")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.53))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
