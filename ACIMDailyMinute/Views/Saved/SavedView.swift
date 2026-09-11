import SwiftUI
import SwiftData

struct SavedView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case highlights = "Highlights"
        case notes = "Notes"
        case bookmarks = "Bookmarks"

        var id: String { rawValue }
    }

    private enum Item: Identifiable {
        case highlight(Highlight)
        case note(Note)
        case bookmark(Bookmark)

        var id: PersistentIdentifier {
            switch self {
            case .highlight(let highlight): highlight.persistentModelID
            case .note(let note): note.persistentModelID
            case .bookmark(let bookmark): bookmark.persistentModelID
            }
        }

        var createdAt: Date {
            switch self {
            case .highlight(let highlight): highlight.createdAt
            case .note(let note): note.createdAt
            case .bookmark(let bookmark): bookmark.createdAt
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \Highlight.createdAt, order: .reverse) private var highlights: [Highlight]
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var filter: Filter = .all
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                if items.isEmpty {
                    emptyState
                } else {
                    stream
                }
            }
            .acimInkBackground()
            // ⛔ The mini player floats over this screen, so the last row owes
            // it room. Thirteen surfaces reserved it and this one did not, which
            // covered the bottom entry whenever audio was playing.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // There is no server and no account, so this is the only way
                    // a reader's own words ever leave the app. It is offered on
                    // every filter because it exports all of them.
                    if !highlights.isEmpty || !notes.isEmpty {
                        #if !os(tvOS)
                        ShareLink(item: exportText) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        #endif
                    }
                }
            }
            .navigationDestination(for: SavedDestination.self) { destination in
                switch destination {
                case .lesson(let ref):
                    LessonDetailView(
                        lessonNumber: ref.lessonNumber,
                        spotlight: ref.spotlight,
                        presentsVideo: ref.presentsVideo
                    )
                case .archiveDate(let dateString):
                    // A saved minute was saved from an archived row, so its day
                    // has a reading to show and no sentence to explain.
                    ArchiveDateDetailView(dateString: dateString, availability: .archived)
                case .textSection(let ref):
                    TextSectionView(chapter: ref.chapter, section: ref.section, spotlight: ref.spotlight)
                case .introduction(let ref):
                    WorkbookIntroductionView(lessonNumber: ref.lessonNumber, spotlight: ref.spotlight)
                case .manual(let ref):
                    ManualSegmentView(segmentId: ref.segmentId, spotlight: ref.spotlight)
                case .manualSection(let ref):
                    ManualSectionView(number: ref.number, spotlight: ref.spotlight)
                case .segment(let ref):
                    SegmentReadingView(segmentId: ref.segmentId, spotlight: ref.spotlight)
                }
            }
            .readingDestinations(path: $path)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Saved")
                .font(.acimMasthead)
                .foregroundStyle(.primary)
                .lineSpacing(Metric.mastheadGap)
            chips
                .padding(.top, 10)
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        HStack(spacing: 7) {
            ForEach(Filter.allCases) { chip in
                Button {
                    filter = chip
                } label: {
                    Text(chip.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(filter == chip ? Color.acimOnGold : Color.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 13)
                        .background(
                            filter == chip ? Color.acimGold : Color.acimRaised,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == chip ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 14)
    }

    private var stream: some View {
        List {
            ForEach(items) { item in
                row(for: item)
                    #if !os(tvOS)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        deleteButton { delete(item) }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        deleteButton { delete(item) }
                    }
                    #endif
                    .listRowBackground(Color.clear)
                    #if !os(tvOS)
                    .listRowSeparator(.hidden)
                    #endif
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: Metric.gutter,
                        bottom: 0,
                        trailing: Metric.gutter
                    ))
            }
        }
        .listStyle(.plain)
        #if !os(tvOS)
        .environment(\.defaultMinListRowHeight, 0)
        #endif
        .readableContentWidth()
        .acimInkListBackground()
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptyImage)
        } description: {
            Text(emptyDescription)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        switch item {
        case .highlight(let highlight):
            HighlightRow(highlight: highlight)
        case .note(let note):
            NoteRow(note: note)
        case .bookmark(let bookmark):
            BookmarkRow(bookmark: bookmark)
        }
    }

    private var items: [Item] {
        let merged: [Item]
        switch filter {
        case .all:
            merged = highlights.map(Item.highlight)
                + notes.map(Item.note)
                + bookmarks.map(Item.bookmark)
        case .highlights:
            merged = highlights.map(Item.highlight)
        case .notes:
            merged = notes.map(Item.note)
        case .bookmarks:
            merged = bookmarks.map(Item.bookmark)
        }
        return merged.sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyTitle: String {
        switch filter {
        case .all: "No Saved Marks"
        case .highlights: "No Highlights"
        case .notes: "No Notes"
        case .bookmarks: "No Bookmarks"
        }
    }

    private var emptyImage: String {
        switch filter {
        case .all, .bookmarks: "bookmark"
        case .highlights: "highlighter"
        case .notes: "square.and.pencil"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all:
            "Highlight a passage, write a note, or tap Save on a reading to keep it here."
        case .highlights:
            "Select any passage while you are reading and choose Highlight to keep it here."
        case .notes:
            "Tap Add note under any reading to write something down and keep it here."
        case .bookmarks:
            "Tap Save on any reading to keep it here."
        }
    }

    private var exportText: String {
        let converted = AnnotationExport.entries(highlights: highlights, notes: notes)
        return AnnotationExport.plainText(
            highlights: converted.highlights,
            standaloneNotesByReading: converted.standalone
        )
    }

    private func delete(_ item: Item) {
        switch item {
        case .highlight(let highlight):
            AnnotationStore.delete(highlight, in: modelContext)
        case .note(let note):
            AnnotationStore.delete(note, in: modelContext)
        case .bookmark(let bookmark):
            // Through `BookmarkStore`, not `modelContext.delete`:
            // `itemKey` no longer carries a unique index, so a
            // passage can be held by more than one row and only the
            // store removes all of them.
            BookmarkStore.remove(key: bookmark.itemKey, in: modelContext)
        }
        try? modelContext.save()
    }

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label("Delete", systemImage: "trash")
        }
    }
}

/// Where a saved row leads: back to the reading it was saved from, and to the
/// passage inside it wherever the row knows one. Hashable so it can ride the
/// `NavigationStack` path.
///
/// Every case but `archiveDate` carries the same ref the search results and the
/// citation links push, which is what lets a spotlight travel: a note hanging on
/// a highlight already holds an offset, a length and a quote, and that is
/// exactly a `ReadingSpotlight`. An archive day is a day rather than a reading
/// and has no passage to point at.
enum SavedDestination: Hashable {
    case lesson(LessonRef)
    case archiveDate(String)
    case textSection(TextSectionRef)
    case introduction(IntroductionRef)
    case manual(ManualSegmentRef)
    case manualSection(ManualSectionRef)
    case segment(SegmentReadingRef)
}

extension ReadingKey {
    /// Where a row for this reading leads in the Saved tab, opened on
    /// `spotlight` where the row knows which passage the reader marked.
    ///
    /// A lesson opens that lesson and a Text section opens that section. A
    /// Manual passage and a **Daily Minute passage** each open their own words,
    /// gated on the segment being in the bundle exactly as a Text section is —
    /// so the destination needs no feed, no media row and no network, and still
    /// answers after every service this app uses has ended.
    ///
    /// ⛔ A minute is NOT routed through the archive day it ran on. That day is
    /// known only where a `SegmentMedia` row records it, most segments have no
    /// such row, and the result was a note the reader could tap and tap with
    /// nothing happening. `.minuteDate` is the one case that still names a day,
    /// because that key exists only for an archived minute whose segment is
    /// unknown — so its day is in the archive by construction.
    func savedDestination(spotlight: ReadingSpotlight? = nil) -> SavedDestination? {
        switch self {
        case .lesson(let n):
            // Introductions have their own screen because they have no lesson
            // number to be titled with.
            if WorkbookBodiesCatalog.isIntroduction(n) {
                return .introduction(IntroductionRef(lessonNumber: n, spotlight: spotlight))
            }
            guard (1...365).contains(n) else { return nil }
            // Following a mark is a request to read, so the video does not take
            // the screen — the same call a cross-reference makes.
            return .lesson(LessonRef(lessonNumber: n, spotlight: spotlight, presentsVideo: false))
        case .textSection(let chapter, let section):
            guard CorpusService.shared.textSection(chapter: chapter, section: section) != nil
            else { return nil }
            return .textSection(
                TextSectionRef(chapter: chapter, section: section, spotlight: spotlight)
            )
        case .segment(let id):
            guard CorpusService.shared.segment(id: id) != nil else { return nil }
            return .segment(SegmentReadingRef(segmentId: id, spotlight: spotlight))
        case .minuteDate(let date):
            return date.isEmpty ? nil : .archiveDate(date)
        case .manual(let id):
            guard CorpusService.shared.manualSegment(id: id) != nil else { return nil }
            return .manual(ManualSegmentRef(segmentId: id, spotlight: spotlight))
        case .manualSection(let n):
            guard CorpusService.shared.manualSection(n) != nil else { return nil }
            return .manualSection(ManualSectionRef(number: n, spotlight: spotlight))
        }
    }
}

/// Shared Saved-row chrome: gold rule, quote, optional italic note, citation
/// and the reader's own date. Highlight / note / bookmark rows feed this.
struct SavedMarkChrome: View {
    var quote: String?
    var paintsHighlight: Bool = false
    var note: String?
    var citationRaw: String?
    var dateText: String
    var isDimmed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasQuote {
                quoteBlock
            }
            if let note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 14.5, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, hasQuote ? 10 : 0)
                    .padding(.leading, hasQuote ? 15 : 13)
                    .overlay(alignment: .leading) {
                        if !hasQuote {
                            rule
                        }
                    }
            }
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                CitationLabel(raw: citationRaw, font: .acimAddressSmall)
                Text(dateText)
                    .font(.acimRowSub)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
            .padding(.top, 9)
            .padding(.leading, 15)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(isDimmed ? 0.5 : 1)
        .overlay(alignment: .bottom) {
            Color.acimHairline.frame(height: 1)
        }
    }

    private var hasQuote: Bool {
        if let quote, !quote.isEmpty { return true }
        return false
    }

    @ViewBuilder
    private var quoteBlock: some View {
        Group {
            if paintsHighlight, let quote {
                Text(marked(quote))
            } else if let quote {
                Text(quote)
            }
        }
        .font(.acimRowTitle)
        .foregroundStyle(.primary)
        .lineSpacing(8)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 13)
        .overlay(alignment: .leading) { rule }
    }

    private var rule: some View {
        Rectangle()
            .fill(Color.acimGold)
            .frame(width: Metric.quoteRule)
    }

    private func marked(_ quote: String) -> AttributedString {
        var text = AttributedString(quote)
        text.backgroundColor = Color.acimMark
        return text
    }
}

/// Kind + the reader's own date, never a publication date.
enum SavedMarkCopy {
    static func dateText(kind: String, at date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "\(kind) today"
        }
        return "\(kind) · \(compactString(from: date))"
    }

    private static func compactString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }
}

/// Display citation for a Saved mark. Rendered only; never fed back into a lookup.
enum SavedCitation {
    /// Paragraph address of a highlight, or the reading stem when the quote is gone.
    static func raw(for highlight: Highlight) -> String? {
        guard let key = ReadingKey(rawValue: highlight.readingKey) else { return nil }
        if highlight.isOrphaned {
            return CitationResolver.stem(for: key)
        }
        if case .segment = key {
            return CitationResolver.citation(
                for: key,
                characterOffset: highlight.startOffset
            )?.rawValue
        }
        guard let display = CitationResolver.displayString(for: key) else {
            return CitationResolver.stem(for: key)
        }
        let offset: Int
        switch AnchorResolver.resolve(
            startOffset: highlight.startOffset,
            length: highlight.length,
            quote: highlight.quote,
            in: display
        ) {
        case .exact(let range), .moved(let range):
            offset = range.lowerBound
        case .orphaned:
            return CitationResolver.stem(for: key)
        }
        return CitationResolver.citation(
            for: key,
            characterOffset: offset,
            displayString: display
        )?.rawValue
    }

    static func stem(for key: ReadingKey) -> String? {
        CitationResolver.stem(for: key)
    }
}

#Preview {
    SavedView()
        .preferredColorScheme(.dark)
}
