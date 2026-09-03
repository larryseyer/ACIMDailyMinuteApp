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
    var spotlight: ReadingSpotlight? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private let corpus = CorpusService.shared

    /// Built through `ReadingKey` rather than written out here, so one place
    /// decides what a Text address looks like. A bookmark and an annotation on
    /// the same section have to agree on their key, and two literals of the
    /// same shape agree only until one of them is edited.
    private var itemKey: String {
        ReadingKey.textSection(chapter: chapter, section: section).rawValue
    }

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
        // The nav bar names the BOOK; the eyebrow names the place inside it.
        .navigationTitle("Text")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func content(_ reading: CorpusTextSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReadingScaffold(
                    eyebrow: chapter == 0 ? "Preface" : "Chapter \(chapter)",
                    footer: ReadingFooter(
                        // Printed, never tappable: it names the passage the
                        // reader is already looking at.
                        citation: CitationResolver.stem(
                            for: .textSection(chapter: chapter, section: section)
                        ),
                        measure: ReadingTime.describe(wordCount: reading.wordCount)
                    )
                ) {
                } trailing: {
                    ShareButton(text: ShareTextBuilder.textSectionShareText(reading))
                    SaveButton(isSaved: isBookmarked, action: toggleBookmark)
                } titleBlock: {
                    VStack(alignment: .leading, spacing: 4) {
                        // The chapter's name cannot go in the eyebrow: they
                        // reach 35 characters and that band breaks its words
                        // rather than wrapping. Here it wraps freely.
                        if chapter != 0 {
                            Text(reading.chapterTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(reading.sectionTitle)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } body: {
                    AnnotatableReadingText(
                        raw: reading.body,
                        key: .textSection(chapter: chapter, section: section),
                        design: .serif,
                        lineSpacing: 3,
                        spotlight: spotlight
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }

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
        BookmarkStore.toggle(key: itemKey, channel: "text", in: modelContext)
    }
}
