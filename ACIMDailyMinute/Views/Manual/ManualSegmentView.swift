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
                        ShareButton(text: ShareTextBuilder.manualShareText(
                            body: reading.body,
                            citation: reading.citation
                        ))
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
            } else {
                ContentUnavailableView {
                    Label("Passage unavailable", systemImage: "book.closed")
                } description: {
                    Text("This passage is not in the bundled Manual.")
                }
            }
        }
        // The nav bar names the BOOK. A cut still has no question title of
        // its own; `ManualSectionView` is the structured reading.
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
                    eyebrow: "Manual",
                    footer: ReadingFooter(
                        citation: reading.stem,
                        measure: ReadingTime.describe(wordCount: reading.wordCount)
                    )
                ) {
                } trailing: {
                    ShareButton(text: ShareTextBuilder.manualSectionShareText(reading))
                    SaveButton(isSaved: isBookmarked, action: toggleBookmark)
                } titleBlock: {
                    Text(reading.title)
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } body: {
                    AnnotatableReadingText(
                        raw: reading.body,
                        key: .manualSection(number),
                        design: .serif,
                        lineSpacing: 3,
                        spotlight: spotlight,
                        recordsPosition: true
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
    }

    @ViewBuilder
    private var neighbours: some View {
        let previous = corpus.manualSectionBefore(number)
        let next = corpus.manualSectionAfter(number)
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
        BookmarkStore.toggle(key: itemKey, channel: "manual", in: modelContext)
    }
}
