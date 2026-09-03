import SwiftUI
import SwiftData

/// One marked passage in the Saved tab.
///
/// The reader's own date is shown; when the reading was published is not, and
/// never is.
struct HighlightRow: View {
    let highlight: Highlight

    @Query private var media: [SegmentMedia]

    private let key: ReadingKey?

    init(highlight: Highlight) {
        self.highlight = highlight
        self.key = ReadingKey(rawValue: highlight.readingKey)
        _media = Query(filter: #Predicate<SegmentMedia> { $0.segmentId > 0 })
    }

    var body: some View {
        if let destination = key?.savedDestination(media: media) {
            NavigationLink(value: destination) { rowContent }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "highlighter")
                .foregroundStyle(Color.acimGold)
                .font(.title3)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(key?.displayName() ?? "Reading")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(highlight.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(highlight.quote)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if highlight.isOrphaned {
                    // The words are still the reader's. Only their place is lost.
                    Label(
                        "Passage not found in the current text",
                        systemImage: "questionmark.circle"
                    )
                    .font(.acimCaption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
