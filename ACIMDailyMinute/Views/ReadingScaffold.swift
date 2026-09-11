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
    ///
    /// SegmentReadingView is the one pushed exception: its address names
    /// where the cut begins in the book, so the running-head citation opens.
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
/// Four bands in the scroll, always:
///
///   1. header      — running head (parent + citation) and optional controls
///   2. title block — optional; a parent title above a title, or neither
///   3. body        — the reading
///   4. footer      — the address (Today cards) and the measure
///
/// The medium band is chrome, pinned by `readingMediumBand` on the screen,
/// not a fifth child of this stack — a band that scrolls away is not the
/// mockup.
///
/// Container chrome — a card's padding and background, a screen's `ScrollView`
/// and readable width — stays with the surface. This view lays out bands.
struct ReadingScaffold<Leading: View, Trailing: View, TitleBlock: View, ReadingBody: View>: View {
    private let parent: String
    private let citation: String?
    private let opensReading: Bool
    private let footer: ReadingFooter
    private let leading: Leading
    private let trailing: Trailing
    private let titleBlock: TitleBlock
    private let readingBody: ReadingBody

    @Environment(\.openReading) private var openReading

    init(
        parent: String = "",
        citation: String? = nil,
        opensReading: Bool = false,
        footer: ReadingFooter = .none,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder titleBlock: () -> TitleBlock,
        @ViewBuilder body: () -> ReadingBody
    ) {
        self.parent = parent
        self.citation = citation
        self.opensReading = opensReading
        self.footer = footer
        self.leading = leading()
        self.trailing = trailing()
        self.titleBlock = titleBlock()
        self.readingBody = body()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                CardHeaderRow(
                    parent: parent,
                    citation: citation,
                    onOpenCitation: citationAction
                ) {
                    leading
                } trailing: {
                    trailing
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                readingBody
            }
            .padding(.top, showsHeader ? 20 : 0)

            if !footer.isEmpty { footerBand }
        }
    }

    private var showsHeader: Bool {
        !parent.isEmpty
            || !(citation ?? "").isEmpty
            || Leading.self != EmptyView.self
            || Trailing.self != EmptyView.self
    }

    private var citationAction: (() -> Void)? {
        guard opensReading, let citation else { return nil }
        guard let parsed = Citation(rawValue: citation),
              let destination = CitationResolver.destination(for: parsed)
        else { return nil }
        return { openReading(destination) }
    }

    private var footerBand: some View {
        VStack(alignment: .leading, spacing: 13) {
            Rectangle()
                .fill(Color.acimHairline)
                .frame(height: 1)
            HStack(spacing: 8) {
                if footer.opensReading, let bookName = footer.bookName {
                    CitationButton(citation: footer.citation, bookName: bookName)
                } else if let citation = footer.citation {
                    CitationLabel(raw: citation)
                } else if let bookName = footer.bookName {
                    Text(bookName)
                        .font(.acimAddress)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let measure = footer.measure {
                    Text(measure)
                        .font(.acimChipText)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.acimRaised)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.top, 16)
    }
}
