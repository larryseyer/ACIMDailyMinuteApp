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
                    ReadingScaffold(
                        eyebrow: "Manual",
                        footer: ReadingFooter(
                            measure: ReadingTime.describe(
                                wordCount: ReadingTime.wordCount(of: reading.body)
                            )
                        )
                    ) {
                    } trailing: {
                        ShareButton(text: ShareTextBuilder.manualShareText(body: reading.body))
                        SaveButton(isSaved: isBookmarked, action: toggleBookmark)
                    } titleBlock: {
                    } body: {
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
        // The nav bar names the BOOK, which is why the literal title line this
        // screen used to print is gone. Piece E gives the eyebrow a real
        // question number once the Manual has a structure.
        .navigationTitle("Manual for Teachers")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "manual", in: modelContext)
    }
}
