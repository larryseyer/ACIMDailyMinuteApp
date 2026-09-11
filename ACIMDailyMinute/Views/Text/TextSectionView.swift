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
        .navigationTitle("Text")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // ⛔ A Text section has no audio. Leaving a Workbook session up would
        // keep the previous lesson in the mini player under this page.
        .onAppear { audio.dismissForTextReading() }
    }

    private func content(_ reading: CorpusTextSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReadingScaffold(
                    parent: chapter == 0 ? "Preface" : reading.chapterTitle,
                    citation: CitationResolver.stem(
                        for: .textSection(chapter: chapter, section: section)
                    ),
                    footer: ReadingFooter(
                        measure: ReadingTime.describe(wordCount: reading.wordCount)
                    )
                ) {
                } trailing: {
                } titleBlock: {
                    Text(reading.sectionTitle)
                        .font(.acimDisplayTitle)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 24)
                } body: {
                    AnnotatableReadingText(
                        raw: reading.body,
                        key: .textSection(chapter: chapter, section: section),
                        design: .serif,
                        lineSpacing: Metric.readingPushedGap,
                        basePointSize: 18,
                        spotlight: spotlight,
                        recordsPosition: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }

                neighbours
            }
            .padding(Metric.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableContentWidth()
        }
        .readingMediumBand(
            title: reading.sectionTitle,
            composeItem: .textSection(chapter: chapter, section: section),
            artworkText: reading.body,
            shareText: ShareTextBuilder.textSectionShareText(reading),
            bookmarkKey: itemKey,
            bookmarkChannel: "text"
        )
        #if !os(tvOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareButton(text: ShareTextBuilder.textSectionShareText(reading))
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #endif
    }

    /// Previous and next cross chapter boundaries. Without them the Text is a
    /// reference work; with them it is a book that can be read straight through.
    @ViewBuilder
    private var neighbours: some View {
        let previous = corpus.sectionBefore(chapter: chapter, section: section)
        let next = corpus.sectionAfter(chapter: chapter, section: section)

        if previous != nil || next != nil {
            VStack(alignment: .leading, spacing: 8) {
                Color.acimHairline.frame(height: 1)
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
                        .font(.acimRowTitle)
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
