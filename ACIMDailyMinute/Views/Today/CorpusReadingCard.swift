import SwiftUI

/// A reading drawn from the bundled corpus, shown when the feed cannot answer.
///
/// Deliberately thinner than `DailyMinuteCard`: no save, no share, no audio.
/// Those all key off a published reading's identity, and this passage has none —
/// it was never published, is never persisted, and must not be mistaken for the
/// publisher's choice for today. It says where it came from and nothing more.
struct CorpusReadingCard: View {
    let segment: CorpusSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("From A Course in Miracles")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            AnnotatableReadingText(
                raw: segment.body,
                key: .segment(segment.segmentId),
                design: .serif
            )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(segment.sourcePDF)
                .font(.footnote.italic())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
