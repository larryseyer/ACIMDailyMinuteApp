import SwiftUI
import SwiftData

/// One thing the reader wrote, in the Saved tab.
///
/// A note sits under the passage it belongs to. A note with a `highlightID` is
/// a thought about a passage; a note without one is a thought about the whole
/// reading. Both are ordinary, and only the first has a quote to sit under.
struct NoteRow: View {
    let note: Note

    /// The passage this note hangs on, where it hangs on one. A fresh UUID
    /// matches no row, which is how a standalone note asks for nothing. A
    /// predicate on an optional would fetch every highlight in the store for
    /// each row of the list instead.
    @Query private var anchors: [Highlight]

    private let key: ReadingKey?

    init(note: Note) {
        self.note = note
        self.key = ReadingKey(rawValue: note.readingKey)
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
                .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        SavedMarkChrome(
            quote: passage,
            note: note.body,
            citationRaw: citationRaw,
            dateText: SavedMarkCopy.dateText(kind: "Note", at: note.createdAt)
        )
    }

    private var passage: String? {
        guard note.highlightID != nil, let quote = anchors.first?.quote, !quote.isEmpty else {
            return nil
        }
        return quote
    }

    private var citationRaw: String? {
        if note.highlightID != nil, let anchor = anchors.first {
            return SavedCitation.raw(for: anchor)
        }
        guard let key else { return nil }
        return SavedCitation.stem(for: key)
    }
}
