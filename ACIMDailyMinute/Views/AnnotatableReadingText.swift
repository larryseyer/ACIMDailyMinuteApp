import SwiftUI
import SwiftData

/// A reading the reader can mark.
///
/// Everything the six reading surfaces need in order to offer annotation, in one
/// place: the reading's positional key, its stored highlights kept live, the
/// re-anchoring pass, and the callback that turns a selection into a mark. The
/// alternative is the same six lines of wiring copied six times, where the
/// seventh surface gets it subtly wrong.
struct AnnotatableReadingText: View {
    let raw: String
    let key: ReadingKey
    var design: SelectableReadingText.Design = .serif
    var lineSpacing: CGFloat = 0

    @Environment(\.modelContext) private var modelContext
    @Query private var storedHighlights: [Highlight]

    init(
        raw: String,
        key: ReadingKey,
        design: SelectableReadingText.Design = .serif,
        lineSpacing: CGFloat = 0
    ) {
        self.raw = raw
        self.key = key
        self.design = design
        self.lineSpacing = lineSpacing
        let rawKey = key.rawValue
        _storedHighlights = Query(
            filter: #Predicate<Highlight> { $0.readingKey == rawKey },
            sort: \Highlight.startOffset
        )
    }

    var body: some View {
        SelectableReadingText(
            raw: raw,
            design: design,
            lineSpacing: lineSpacing,
            highlights: storedHighlights,
            onHighlight: { range, quote in
                AnnotationStore.addHighlight(
                    readingKey: key, range: range, quote: quote, in: modelContext
                )
            }
        )
        // Re-anchored when the reading appears rather than while its body is
        // being computed: correcting a drifted offset is a write, and a write
        // during view evaluation is how a redraw loop starts.
        .task(id: raw) {
            AnnotationStore.reanchor(
                key,
                displayString: ReadingText.displayString(from: raw),
                in: modelContext
            )
        }
    }
}
