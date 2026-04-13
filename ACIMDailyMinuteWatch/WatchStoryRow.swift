import SwiftUI

struct WatchStoryRow: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.fact)
                .font(.caption)
                .lineLimit(3)
            Text(story.sourceDisplay)
                .font(.caption2)
                .foregroundStyle(Color(red: 0.831, green: 0.686, blue: 0.216))
        }
        .padding(.vertical, 2)
    }
}
