import SwiftUI

/// The ribbon, at the head of the shelf whose book it marks.
///
/// One row per book rather than one for the app: the Workbook shelf shows where
/// the reader is in the Workbook and the Text shelf where they are in the Text,
/// so neither can erase the other and neither has to say which book it means.
///
/// ⛔ Nothing appears when there is no ribbon. A row reading "you have not read
/// anything yet" tells the reader something they already know, in the place the
/// book itself should be.
struct ContinueReadingRow: View {
    let book: ReadingPosition.Book

    /// Bound to the store's own key so the row is redrawn when a ribbon moves.
    /// Coming back from a reading is exactly when this has changed, and a
    /// `List` will not re-read `UserDefaults` on its own to find out.
    @AppStorage(ReadingPositionStore.defaultsKey) private var stored: Data = Data()

    private var position: ReadingPosition? {
        ReadingPosition.decode(stored)[book.rawValue]
    }

    private var key: ReadingKey? {
        position.flatMap { ReadingKey(rawValue: $0.readingKey) }
    }

    /// ⛔ `presentsVideo` is false: following the ribbon is a request to *read*,
    /// exactly as following a cross-reference is, and a video would take the
    /// screen the reader came back to the book for.
    ///
    /// A ribbon can name nothing but a Text section or a Workbook lesson —
    /// `ReadingPosition.book(for:)` refuses to make any other — so the remaining
    /// cases draw nothing rather than guessing at a destination.
    /// ⛔ `.buttonStyle(.plain)` on every branch. This row sits above the shelf
    /// rather than inside it, and a `NavigationLink` outside a `List` draws the
    /// platform's own button chrome — on macOS a filled, rounded well with a
    /// divider down it, which reads as a control rather than as a place in a
    /// book. `TextSectionView`'s Previous and Next answer this the same way.
    @ViewBuilder
    var body: some View {
        switch key {
        case .textSection(let chapter, let section):
            NavigationLink(value: TextSectionRef(chapter: chapter, section: section)) { label }
                .buttonStyle(.plain)
        case .lesson(let number) where number == 0 || number == 500:
            NavigationLink(value: IntroductionRef(lessonNumber: number)) { label }
                .buttonStyle(.plain)
        case .lesson(let number):
            NavigationLink(value: LessonRef(lessonNumber: number, presentsVideo: false)) { label }
                .buttonStyle(.plain)
        case .segment, .manual, .minuteDate, nil:
            EmptyView()
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Continue reading")
                .font(.acimCaption2)
                .foregroundStyle(.secondary)
            Text(key?.displayName() ?? "")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // ⛔ A rule, not a `Divider`. A `Divider` takes its orientation from the
        // layout around it, and an overlay's is a `ZStack`, where it draws
        // itself vertically — straight down the middle of the row.
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.primary.opacity(0.12))
        }
    }
}
