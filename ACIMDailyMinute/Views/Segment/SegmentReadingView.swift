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

    @Environment(AudioManager.self) private var audio

    private let corpus = CorpusService.shared

    var body: some View {
        Group {
            if let segment = corpus.segment(id: segmentId) {
                ScrollView {
                    ReadingScaffold(
                        // What the app already calls this reading everywhere
                        // else — `ReadingKeyNaming` writes "Daily Minute — Text
                        // (T-5.3)" into every export — and the same eyebrow the
                        // Today card carries, so arriving here from a note is
                        // arriving at the same reading.
                        eyebrow: "Daily Minute",
                        footer: ReadingFooter(
                            citation: segment.citation,
                            bookName: segment.bookName,
                            // ⛔ The one pushed screen whose address names
                            // somewhere else. Elsewhere a pushed reading's
                            // address names the passage already on screen and
                            // a link there teaches the reader links are broken.
                            // Here it names where the passage begins in the
                            // book, with the pages around it — note, then
                            // passage, then the book.
                            opensReading: true,
                            measure: ReadingTime.describe(
                                wordCount: ReadingTime.wordCount(of: segment.body)
                            )
                        )
                    ) {
                    } trailing: {
                        ShareButton(text: ShareTextBuilder.segmentShareText(segment))
                    } titleBlock: {
                    } body: {
                        AnnotatableReadingText(
                            raw: segment.body,
                            key: .segment(segmentId),
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
                    Text("This passage is not in the bundled Course.")
                }
            }
        }
        // The nav bar names the BOOK and the eyebrow names the place, so no
        // screen says the same phrase twice.
        .navigationTitle(corpus.segment(id: segmentId)?.bookName ?? "A Course in Miracles")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
