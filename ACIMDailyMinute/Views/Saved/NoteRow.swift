import SwiftUI
import SwiftData

/// One thing the reader wrote, in the Saved tab.
struct NoteRow: View {
    let note: Note

    /// The passage this note hangs on, where it hangs on one. A note with a
    /// `highlightID` is a thought about a passage and a note without one is a
    /// thought about the whole reading; both are ordinary, and only the first
    /// has somewhere narrower than the top of the reading to open.
    @Query private var anchors: [Highlight]

    private let key: ReadingKey?

    init(note: Note) {
        self.note = note
        self.key = ReadingKey(rawValue: note.readingKey)
        // A fresh UUID matches no row, which is how a standalone note asks for
        // nothing. A predicate on an optional would fetch every highlight in
        // the store for each row of the list instead.
        let wanted = note.highlightID ?? UUID()
        _anchors = Query(filter: #Predicate<Highlight> { $0.id == wanted })
    }

    /// Where in the reading to open. `AnchorResolver` repairs it on arrival, so
    /// it still finds its words after a spacing repair has moved the display.
    private var spotlight: ReadingSpotlight? {
        guard note.highlightID != nil,
              let anchor = anchors.first,
              anchor.length > 0,
              !anchor.quote.isEmpty
        else { return nil }
        return ReadingSpotlight(
            startOffset: anchor.startOffset,
            length: anchor.length,
            quote: anchor.quote
        )
    }

    var body: some View {
        if let destination = key?.savedDestination(spotlight: spotlight) {
            NavigationLink(value: destination) { rowContent }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(Color.acimGold)
                .font(.title3)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(key?.displayName() ?? "Reading")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(note.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(note.body)
                    .font(.acimBody)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
