import SwiftUI
import SwiftData

/// Where a Manual reference points.
struct ManualSegmentRef: Hashable {
    let segmentId: Int
    var spotlight: ReadingSpotlight? = nil
}

/// One passage of the Manual for Teachers, read.
///
/// The Manual is bundled as 105 word-count cuts with no titles and no
/// addresses, so this screen has no table of contents behind it and no
/// Previous or Next: it exists so a search hit or a saved mark in the Manual
/// has somewhere to open. Annotations key on `manual:<segmentId>`, which is
/// why giving the Manual a real structure later cannot move anything made here.
struct ManualSegmentView: View {
    let segmentId: Int
    var spotlight: ReadingSpotlight? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private let corpus = CorpusService.shared

    private var itemKey: String { ReadingKey.manual(segmentId).rawValue }

    private var isBookmarked: Bool {
        bookmarks.contains { $0.itemKey == itemKey }
    }

    var body: some View {
        Group {
            if let reading = corpus.manualSegment(id: segmentId) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Manual for Teachers")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        AnnotatableReadingText(
                            raw: reading.body,
                            key: .manual(segmentId),
                            design: .serif,
                            lineSpacing: 3,
                            spotlight: spotlight
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableContentWidth()
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
                }
            } else {
                ContentUnavailableView {
                    Label("Passage unavailable", systemImage: "book.closed")
                } description: {
                    Text("This passage is not in the bundled Manual.")
                }
            }
        }
        .navigationTitle("Manual")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "manual", in: modelContext)
    }
}
