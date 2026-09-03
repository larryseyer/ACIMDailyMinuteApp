import SwiftUI

/// What a reading's footer says: the address on the leading edge, the measure
/// on the trailing edge.
///
/// A value rather than two more view slots, so the one rule that is easy to get
/// wrong — an address is tappable only where it names somewhere else — lives
/// here instead of at ten call sites.
struct ReadingFooter {
    /// The address, where the reading has one.
    var citation: String? = nil
    /// What to say when there is no address. The Manual has none; an archived
    /// row has only its book.
    var bookName: String? = nil
    /// True only on the Today cards, whose footer names a passage elsewhere in
    /// the Course and opens it.
    ///
    /// ⛔ False on every pushed reading screen. There the address names the
    /// passage already on screen, and a link that goes where the reader
    /// already is teaches them the link is broken.
    var opensReading: Bool = false
    /// The trailing measure: a read time, or the Archive's own date, which is
    /// that tab's index rather than a publication stamp.
    var measure: String? = nil

    static let none = ReadingFooter()

    var isEmpty: Bool { citation == nil && bookName == nil && measure == nil }
}

/// The shape of every reading in this app.
///
/// ⛔ **This view owns the ORDER of the bands and nothing inside one.** A
/// surface's renderer, font and wording stay its own; where a band sits is
/// this view's business. That line is what keeps a layout change from becoming
/// a rewrite of what the readings say.
///
/// Four bands, always:
///
///   1. header      — the eyebrow on its own line, then the controls
///   2. title block — optional; a parent title above a title, or neither
///   3. body        — the reading
///   4. footer      — the address, and the measure
///
/// It exists because the app drew a reading in ten places and none of them
/// stated the order, so each drifted to whatever was locally sensible: Save
/// ended up in the nav toolbar on four screens and in the header on three,
/// Share moved below the body or vanished, and the play control was
/// hand-rolled three times at a different size. A surface that passes slots
/// cannot make those choices, which is the point.
///
/// Container chrome — a card's padding and background, a screen's `ScrollView`
/// and readable width — stays with the surface. This view lays out bands.
struct ReadingScaffold<Leading: View, Trailing: View, TitleBlock: View, ReadingBody: View>: View {
    private let eyebrow: String
    private let footer: ReadingFooter
    private let leading: Leading
    private let trailing: Trailing
    private let titleBlock: TitleBlock
    private let readingBody: ReadingBody

    init(
        eyebrow: String,
        footer: ReadingFooter = .none,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder titleBlock: () -> TitleBlock,
        @ViewBuilder body: () -> ReadingBody
    ) {
        self.eyebrow = eyebrow
        self.footer = footer
        self.leading = leading()
        self.trailing = trailing()
        self.titleBlock = titleBlock()
        self.readingBody = body()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeaderRow(eyebrow) {
                leading
            } trailing: {
                trailing
            }

            titleBlock

            readingBody

            if !footer.isEmpty { footerBand }
        }
    }

    private var footerBand: some View {
        HStack(spacing: 8) {
            if footer.opensReading, let bookName = footer.bookName {
                CitationButton(citation: footer.citation, bookName: bookName)
            } else if let address = footer.citation ?? footer.bookName {
                Text(address)
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let measure = footer.measure {
                Text(measure)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
