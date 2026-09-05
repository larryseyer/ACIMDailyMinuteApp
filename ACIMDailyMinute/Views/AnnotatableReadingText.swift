import SwiftUI
import SwiftData

/// A reading the reader can mark and write about.
///
/// Everything the six reading surfaces need in order to offer annotation, in one
/// place: the reading's positional key, its stored highlights and notes kept
/// live, the re-anchoring pass, and the menu that turns a selection into a mark.
/// The alternative is the same wiring copied six times, where the seventh
/// surface gets it subtly wrong.
struct AnnotatableReadingText: View {
    let raw: String
    let key: ReadingKey
    var design: SelectableReadingText.Design = .serif
    var lineSpacing: CGFloat = 0
    /// Passed straight through: a reading opened from a search hit re-anchors
    /// and paints it, every other caller leaves it nil.
    var spotlight: ReadingSpotlight? = nil
    /// Whether leaving this reading moves its book's ribbon.
    ///
    /// ⛔ True on the three reading SCREENS and false everywhere else, and that
    /// is a decision rather than an oversight. A Today card sits inside another
    /// scroll view alongside a second card, so the character at the top of its
    /// text view is not where the reader is — it is wherever that card happens
    /// to have been pushed to. **A new reading screen owes this line**; a new
    /// card owes nothing.
    var recordsPosition: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var storedHighlights: [Highlight]
    @Query private var storedNotes: [Note]
    @State private var draft: NoteDraft?
    /// Read once, when this reading is first built. Re-reading it while the
    /// reader is here would scroll them back to where they came in.
    @State private var resume: ReadingPosition?
    @State private var reporter = SelectableReadingText.PositionReporter()

    init(
        raw: String,
        key: ReadingKey,
        design: SelectableReadingText.Design = .serif,
        lineSpacing: CGFloat = 0,
        spotlight: ReadingSpotlight? = nil,
        recordsPosition: Bool = false
    ) {
        self.raw = raw
        self.key = key
        self.design = design
        self.lineSpacing = lineSpacing
        self.spotlight = spotlight
        self.recordsPosition = recordsPosition
        _resume = State(
            initialValue: recordsPosition ? ReadingPositionStore.position(matching: key) : nil
        )
        let rawKey = key.rawValue
        _storedHighlights = Query(
            filter: #Predicate<Highlight> { $0.readingKey == rawKey },
            sort: \Highlight.startOffset
        )
        _storedNotes = Query(
            filter: #Predicate<Note> { $0.readingKey == rawKey },
            sort: \Note.createdAt
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SelectableReadingText(
                raw: raw,
                design: design,
                lineSpacing: lineSpacing,
                highlights: storedHighlights,
                menuActions: menuActions,
                spotlight: spotlight,
                resume: resume,
                positionReporter: recordsPosition ? reporter : nil
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(storedNotes) { note in
                noteRow(note)
            }

            HStack(spacing: 16) {
                Button {
                    draft = NoteDraft(existing: nil, highlightID: nil, quote: nil)
                } label: {
                    Label("Add note", systemImage: "square.and.pencil")
                        .font(.acimCaption)
                }
                .buttonStyle(.plain)

                #if !os(tvOS)
                if !storedHighlights.isEmpty || !storedNotes.isEmpty {
                    ShareLink(item: exportText) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.acimCaption)
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }
            .foregroundStyle(.secondary)
        }
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
        // Where the reader stopped is asked for when they stop: leaving the
        // reading, and putting the app down. Watching the scroll instead would
        // mean a delegate on a scroll view this app does not own and a write on
        // every frame of a drag.
        .onDisappear { recordPosition() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            recordPosition()
        }
        #if !os(tvOS)
        .sheet(item: $draft) { draft in
            NoteEditorView(
                readingName: key.displayName(),
                quote: draft.quote,
                existing: draft.existing?.body ?? ""
            ) { text in
                if let note = draft.existing {
                    AnnotationStore.update(note, body: text, in: modelContext)
                } else {
                    AnnotationStore.addNote(
                        readingKey: key,
                        body: text,
                        highlightID: draft.highlightID,
                        in: modelContext
                    )
                }
            }
        }
        #endif
    }

    /// Moves this book's ribbon to where the reader is.
    ///
    /// ⛔ A reporter that cannot answer records the reading at its top rather
    /// than recording nothing. The text view may not be inside its scroller yet,
    /// or the reading may never have been laid out — neither is a reason to lose
    /// the reader's book. **The reading is the durable part; the offset is the
    /// refinement**, and the worst this can do is what the app did before there
    /// was a ribbon at all.
    ///
    /// `ReadingPosition.make` returns nil for a reading no ribbon can name, so
    /// a Daily Minute card that ever reached this line still could not set one.
    private func recordPosition() {
        guard recordsPosition else { return }
        let offset = reporter.currentOffset() ?? 0
        guard let position = ReadingPosition.make(
            key: key,
            startOffset: offset,
            in: ReadingText.displayString(from: raw),
            at: Date()
        ) else { return }
        ReadingPositionStore.record(position)
    }

    /// This reading's marks and notes, as text. Nothing can re-send a reader
    /// what they wrote, so getting it out has to be possible from where they
    /// wrote it, not only from the Saved tab.
    private var exportText: String {
        let converted = AnnotationExport.entries(
            highlights: Array(storedHighlights), notes: Array(storedNotes)
        )
        return AnnotationExport.plainText(
            highlights: converted.highlights,
            standaloneNotesByReading: converted.standalone
        )
    }

    private var menuActions: [SelectableReadingText.MenuAction] {
        [
            SelectableReadingText.MenuAction(
                id: "highlight", title: "Highlight", systemImage: "highlighter"
            ) { range, quote in
                AnnotationStore.addHighlight(
                    readingKey: key, range: range, quote: quote, in: modelContext
                )
            },
            SelectableReadingText.MenuAction(
                id: "note", title: "Note", systemImage: "square.and.pencil"
            ) { range, quote in
                // A passage note marks the passage too, so reopening the reading
                // shows what the note is about without having to read the note.
                let highlight = AnnotationStore.addHighlight(
                    readingKey: key, range: range, quote: quote, in: modelContext
                )
                draft = NoteDraft(existing: nil, highlightID: highlight?.id, quote: quote)
            }
        ]
    }

    private func noteRow(_ note: Note) -> some View {
        Button {
            draft = NoteDraft(
                existing: note,
                highlightID: note.highlightID,
                quote: quote(forHighlight: note.highlightID)
            )
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.acimCaption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                Text(note.body)
                    .font(.acimCallout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.acimChip)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func quote(forHighlight id: UUID?) -> String? {
        guard let id else { return nil }
        return storedHighlights.first { $0.id == id }?.quote
    }
}

/// What the note sheet is currently editing: an existing note, or a new one that
/// may or may not be attached to a passage.
private struct NoteDraft: Identifiable {
    let id = UUID()
    let existing: Note?
    let highlightID: UUID?
    let quote: String?
}
