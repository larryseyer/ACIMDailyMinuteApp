import SwiftUI

/// A reading drawn from the bundled corpus, shown when the feed cannot answer.
///
/// Deliberately thinner than `DailyMinuteCard`: no save, no share, no audio.
/// Those all key off a published reading's identity, and this passage has none —
/// it was never published, is never persisted, and must not be mistaken for the
/// publisher's choice for today. It says where it came from and nothing more.
///
/// It names its book rather than the Course, because it stands in the slot
/// `DailyMinuteCard` would occupy and the two must not look like different
/// kinds of card. No read time: this passage carries no word count from a feed,
/// and every segment is cut to the same budget anyway.
struct CorpusReadingCard: View {
    let segment: CorpusSegment

    var body: some View {
        ReadingScaffold(
            eyebrow: segment.bookName,
            footer: ReadingFooter(
                citation: segment.citation,
                bookName: segment.bookName,
                opensReading: true
            )
        ) {
        } trailing: {
        } titleBlock: {
        } body: {
            AnnotatableReadingText(
                raw: segment.body,
                key: .segment(segment.segmentId),
                design: .serif
            )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
