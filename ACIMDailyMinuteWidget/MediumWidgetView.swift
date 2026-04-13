import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: WidgetStoryEntry

    private let brandGold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let ratingGreen = Color(red: 0.27, green: 0.67, blue: 0.6)

    var body: some View {
        if entry.stories.isEmpty {
            emptyView
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("ACIM DAILY MINUTE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(brandGold)
                    Spacer()
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.53))
                }

                Spacer().frame(height: 6)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.stories.enumerated()), id: \.element.id) { index, story in
                        if index > 0 {
                            Divider()
                                .background(Color(white: 0.2))
                        }

                        Link(destination: URL(string: "acimdailyminute://story/\(story.id)")!) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.fact)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(white: 0.88))
                                    .lineLimit(1)

                                HStack(spacing: 0) {
                                    ForEach(Array(story.sourceRatings.enumerated()), id: \.offset) { i, rating in
                                        if i > 0 {
                                            Text(" · ")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Color(white: 0.53))
                                        }
                                        Text(rating.name)
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color(white: 0.53))
                                        Text(" \(String(format: "%.1f", rating.accuracy))")
                                            .font(.system(size: 9))
                                            .foregroundStyle(ratingGreen)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("ACIM DAILY MINUTE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(brandGold)
            Text("Open ACIM Daily Minute to load stories")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.53))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
