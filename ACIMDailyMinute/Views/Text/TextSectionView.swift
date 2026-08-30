import SwiftUI
import SwiftData

/// One section of the Text, read.
///
/// The body goes through `AnnotatableReadingText`, which brings selection,
/// highlighting, notes and export with it, and measures every offset against
/// `ReadingText.displayString`. The section's `body` is already display form as
/// exported, so what is stored, what is drawn and what an offset counts are all
/// the same string.
struct TextSectionView: View {
    let chapter: Int
    let section: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private let corpus = CorpusService.shared

    private var itemKey: String { "text:\(chapter).\(section)" }

    private var isBookmarked: Bool {
        bookmarks.contains { $0.itemKey == itemKey }
    }

    var body: some View {
        Group {
            if let reading = corpus.textSection(chapter: chapter, section: section) {
                content(reading)
            } else {
                ContentUnavailableView {
                    Label("Section unavailable", systemImage: "book.closed")
                } description: {
                    Text("This section is not in the bundled Text.")
                }
            }
        }
        .navigationTitle(chapter == 0 ? "Preface" : "Chapter \(chapter)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func content(_ reading: CorpusTextSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text(reading.chapterTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if let stem = CitationResolver.stem(
                        for: .textSection(chapter: chapter, section: section)
                    ) {
                        Text(stem)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Citation \(stem)")
                    }
                }

                Text(reading.sectionTitle)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                AnnotatableReadingText(
                    raw: reading.body,
                    key: .textSection(chapter: chapter, section: section),
                    design: .serif,
                    lineSpacing: 3
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

                HStack {
                    ShareLink(item: ShareTextBuilder.textSectionShareText(reading)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                    Spacer()
                }
                .font(.title3)
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
                .padding(.top, 4)

                neighbours
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableContentWidth()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
    }

    /// Previous and next cross chapter boundaries. Without them the Text is a
    /// reference work; with them it is a book that can be read straight through.
    @ViewBuilder
    private var neighbours: some View {
        let previous = corpus.sectionBefore(chapter: chapter, section: section)
        let next = corpus.sectionAfter(chapter: chapter, section: section)

        if previous != nil || next != nil {
            VStack(alignment: .leading, spacing: 8) {
                Divider().opacity(0.4)
                if let previous {
                    neighbourLink(previous, label: "Previous", systemImage: "chevron.left")
                }
                if let next {
                    neighbourLink(next, label: "Next", systemImage: "chevron.right")
                }
            }
            .padding(.top, 8)
        }
    }

    private func neighbourLink(
        _ target: CorpusTextSection,
        label: String,
        systemImage: String
    ) -> some View {
        NavigationLink(
            value: TextSectionRef(chapter: target.chapterNumber, section: target.sectionNumber)
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.acimCaption2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.acimCaption2)
                        .foregroundStyle(.secondary)
                    Text(target.sectionTitle)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleBookmark() {
        if let existing = bookmarks.first(where: { $0.itemKey == itemKey }) {
            modelContext.delete(existing)
        } else {
            let bookmark = Bookmark()
            bookmark.itemKey = itemKey
            bookmark.channel = "text"
            bookmark.createdAt = Date()
            modelContext.insert(bookmark)
        }
        try? modelContext.save()
    }
}
