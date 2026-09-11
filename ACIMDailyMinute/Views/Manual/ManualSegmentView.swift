import SwiftUI
import SwiftData

/// Where a Manual reference points.
struct ManualSegmentRef: Hashable {
    let segmentId: Int
    var spotlight: ReadingSpotlight? = nil
}

/// A question of the Manual — or the Introduction, or one of the two closings.
struct ManualSectionRef: Hashable {
    let number: Int
    var spotlight: ReadingSpotlight? = nil
}

/// One passage of the Manual for Teachers, read.
///
/// Kept so a search hit or a saved mark on an old `manual:<segmentId>` key
/// still opens. The running head uses the structured section when one
/// contains this cut, so the two Manual screens do not look like different
/// books. The body and its annotations stay keyed on `.manual(segmentId)`.
struct ManualSegmentView: View {
    let segmentId: Int
    var spotlight: ReadingSpotlight? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]

    private let corpus = CorpusService.shared

    private var itemKey: String { ReadingKey.manual(segmentId).rawValue }

    private var isBookmarked: Bool {
        bookmarks.contains { $0.itemKey == itemKey }
    }

    var body: some View {
        Group {
            if let reading = corpus.manualSegment(id: segmentId) {
                let section = corpus.manualSection(containingSegmentId: segmentId)
                ScrollView {
                    ReadingScaffold(
                        parent: "Manual",
                        citation: section?.stem ?? reading.citation,
                        footer: ReadingFooter(
                            measure: ReadingTime.describe(
                                wordCount: ReadingTime.wordCount(of: reading.body)
                            )
                        )
                    ) {
                    } trailing: {
                    } titleBlock: {
                        if let section {
                            Text(section.title)
                                .font(.acimDisplayTitle)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 24)
                        }
                    } body: {
                        AnnotatableReadingText(
                            raw: reading.body,
                            key: .manual(segmentId),
                            design: .serif,
                            lineSpacing: Metric.readingPushedGap,
                            basePointSize: 18,
                            spotlight: spotlight
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Metric.gutter)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableContentWidth()
                }
                .readingMediumBand(
                    title: section?.title ?? "Manual",
                    composeItem: .manual(segmentId),
                    artworkText: reading.body,
                    shareText: ShareTextBuilder.manualShareText(
                        body: reading.body,
                        citation: reading.citation
                    ),
                    bookmarkKey: itemKey,
                    bookmarkChannel: "manual"
                )
                #if !os(tvOS)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        ShareButton(text: ShareTextBuilder.manualShareText(
                            body: reading.body,
                            citation: reading.citation
                        ))
                        SaveButton(isSaved: isBookmarked, action: toggleBookmark)
                    }
                }
                #endif
            } else {
                ContentUnavailableView {
                    Label("Passage unavailable", systemImage: "book.closed")
                } description: {
                    Text("This passage is not in the bundled Manual.")
                }
            }
        }
        .navigationTitle("Manual for Teachers")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "manual", in: modelContext)
    }
}

/// One question of the Manual for Teachers, read.
///
/// Previous and Next walk the 31 readings in book order. Annotations key on
/// `manual-q:<n>`, so a highlight made here cannot collide with one stored
/// against a Daily Minute cut of the same words.
struct ManualSectionView: View {
    let number: Int
    var spotlight: ReadingSpotlight? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private let corpus = CorpusService.shared

    private var itemKey: String { ReadingKey.manualSection(number).rawValue }

    private var isBookmarked: Bool {
        bookmarks.contains { $0.itemKey == itemKey }
    }

    var body: some View {
        Group {
            if let reading = corpus.manualSection(number) {
                content(reading)
            } else {
                ContentUnavailableView {
                    Label("Passage unavailable", systemImage: "book.closed")
                } description: {
                    Text("This reading is not in the bundled Manual.")
                }
            }
        }
        .navigationTitle("Manual for Teachers")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { audio.dismissForTextReading() }
    }

    private func content(_ reading: CorpusManualSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReadingScaffold(
                    parent: "Manual",
                    citation: reading.stem,
                    footer: ReadingFooter(
                        measure: ReadingTime.describe(wordCount: reading.wordCount)
                    )
                ) {
                } trailing: {
                } titleBlock: {
                    Text(reading.title)
                        .font(.acimDisplayTitle)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 24)
                } body: {
                    AnnotatableReadingText(
                        raw: reading.body,
                        key: .manualSection(number),
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
            title: reading.title,
            composeItem: .manualSection(number: number),
            artworkText: reading.body,
            shareText: ShareTextBuilder.manualSectionShareText(reading),
            bookmarkKey: itemKey,
            bookmarkChannel: "manual"
        )
        #if !os(tvOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareButton(text: ShareTextBuilder.manualSectionShareText(reading))
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #endif
    }

    @ViewBuilder
    private var neighbours: some View {
        let previous = corpus.manualSectionBefore(number)
        let next = corpus.manualSectionAfter(number)
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
        _ target: CorpusManualSection,
        label: String,
        systemImage: String
    ) -> some View {
        NavigationLink(value: ManualSectionRef(number: target.number)) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.acimCaption2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.acimCaption2)
                        .foregroundStyle(.secondary)
                    Text(target.title)
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
        BookmarkStore.toggle(key: itemKey, channel: "manual", in: modelContext)
    }
}
