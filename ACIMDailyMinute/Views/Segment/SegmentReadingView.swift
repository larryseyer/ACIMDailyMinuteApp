import SwiftUI
import SwiftData

/// Where a saved mark on a Daily Minute points.
struct SegmentReadingRef: Hashable {
    let segmentId: Int
    var spotlight: ReadingSpotlight? = nil
}

/// One bundled passage of the Course — the cut a Daily Minute is made from —
/// read on its own words.
///
/// It exists because an annotation made on the Today card keys on
/// `segment:<id>`, and the only destination that key had was the archive day
/// the minute ran on: a day that needs a `SegmentMedia` row to be known at all,
/// and that most segments do not have. A note the reader could not follow is
/// the annotation feature dead-ending at its most-used path. The passage itself
/// is bundled, answers with no network and no media row, and will still answer
/// after every feed here has ended — so this screen asks the corpus and nothing
/// else.
///
/// ⛔ **No Save.** A minute saved from Today keys `minute:<segmentHash>` and one
/// saved from the Archive keys `minute:<lineHash>`; a third address for one
/// passage is the duplicate-row bug this project keeps rediscovering. Sharing
/// creates no identity, so Share stays.
struct SegmentReadingView: View {
    let segmentId: Int
    var spotlight: ReadingSpotlight? = nil

    private let corpus = CorpusService.shared

    var body: some View {
        Group {
            if let segment = corpus.segment(id: segmentId) {
                ScrollView {
                    ReadingScaffold(
                        parent: segment.bookName,
                        citation: segment.citation,
                        opensReading: true,
                        footer: ReadingFooter(
                            measure: ReadingTime.describe(
                                wordCount: ReadingTime.wordCount(of: segment.body)
                            )
                        )
                    ) {
                    } trailing: {
                    } titleBlock: {
                    } body: {
                        AnnotatableReadingText(
                            raw: segment.body,
                            key: .segment(segmentId),
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
                    title: "Daily Minute",
                    segmentId: segmentId,
                    composeItem: .segment(segment),
                    artworkText: segment.body,
                    shareText: ShareTextBuilder.segmentShareText(segment)
                )
                #if !os(tvOS)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ShareButton(text: ShareTextBuilder.segmentShareText(segment))
                    }
                }
                #endif
            } else {
                ContentUnavailableView {
                    Label("Passage unavailable", systemImage: "book.closed")
                } description: {
                    Text("This passage is not in the bundled Course.")
                }
            }
        }
        .navigationTitle(corpus.segment(id: segmentId)?.bookName ?? "A Course in Miracles")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
