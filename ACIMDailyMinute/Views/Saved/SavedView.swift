import SwiftUI
import SwiftData

struct SavedView: View {
    /// Saved, Highlights and Notes are three views of one shelf, so they share a
    /// tab. A sixth tab would collapse into the iOS "More" list and bury Saved
    /// underneath a disclosure row.
    private enum Segment: String, CaseIterable, Identifiable {
        case saved = "Saved"
        case highlights = "Highlights"
        case notes = "Notes"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \Highlight.createdAt, order: .reverse) private var highlights: [Highlight]
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var segment: Segment = .saved
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Shelf", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                Group {
                    switch segment {
                    case .saved: savedList
                    case .highlights: highlightList
                    case .notes: noteList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // ⛔ The mini player floats over this screen, so the last row owes
            // it room. Thirteen surfaces reserved it and this one did not, which
            // covered the bottom entry whenever audio was playing.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
            .navigationTitle("Saved")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // There is no server and no account, so this is the only way
                    // a reader's own words ever leave the app. It is offered on
                    // every segment because it exports all of them.
                    if !highlights.isEmpty || !notes.isEmpty {
                        ShareLink(item: exportText) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
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
                case .segment(let ref):
                    SegmentReadingView(segmentId: ref.segmentId, spotlight: ref.spotlight)
                }
            }
            .readingDestinations(path: $path)
        }
    }

    @ViewBuilder
    private var savedList: some View {
        if bookmarks.isEmpty {
            ContentUnavailableView {
                Label("No Bookmarks", systemImage: "bookmark")
            } description: {
                Text("Tap Save on any Daily Minute, Lesson, or Archive entry to keep it here.")
            }
        } else {
            List {
                ForEach(bookmarks) { bookmark in
                    BookmarkRow(bookmark: bookmark)
                        // Both edges delete. `.onDelete` only ever produces a
                        // trailing swipe, and a saved item is the kind of thing
                        // people flick away in either direction.
                        // Through `BookmarkStore`, not `modelContext.delete`:
                        // `itemKey` no longer carries a unique index, so a
                        // passage can be held by more than one row and only the
                        // store removes all of them.
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton { BookmarkStore.remove(key: bookmark.itemKey, in: modelContext) }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            deleteButton { BookmarkStore.remove(key: bookmark.itemKey, in: modelContext) }
                        }
                }
            }
            .listStyle(.plain)
            .readableContentWidth()
        }
    }

    @ViewBuilder
    private var highlightList: some View {
        if highlights.isEmpty {
            ContentUnavailableView {
                Label("No Highlights", systemImage: "highlighter")
            } description: {
                Text("Select any passage while you are reading and choose Highlight to keep it here.")
            }
        } else {
            List {
                ForEach(highlights) { highlight in
                    HighlightRow(highlight: highlight)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton { AnnotationStore.delete(highlight, in: modelContext) }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            deleteButton { AnnotationStore.delete(highlight, in: modelContext) }
                        }
                }
            }
            .listStyle(.plain)
            .readableContentWidth()
        }
    }

    @ViewBuilder
    private var noteList: some View {
        if notes.isEmpty {
            ContentUnavailableView {
                Label("No Notes", systemImage: "square.and.pencil")
            } description: {
                Text("Tap Add note under any reading to write something down and keep it here.")
            }
        } else {
            List {
                ForEach(notes) { note in
                    NoteRow(note: note)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton { AnnotationStore.delete(note, in: modelContext) }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            deleteButton { AnnotationStore.delete(note, in: modelContext) }
                        }
                }
            }
            .listStyle(.plain)
            .readableContentWidth()
        }
    }

    private var exportText: String {
        let converted = AnnotationExport.entries(highlights: highlights, notes: notes)
        return AnnotationExport.plainText(
            highlights: converted.highlights,
            standaloneNotesByReading: converted.standalone
        )
    }

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            action()
            try? modelContext.save()
        } label: {
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
            // 0 and 500 are the two Part Introductions, which have their own
            // screen because they have no lesson number to be titled with.
            if n == 0 || n == 500 {
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
        }
    }
}

#Preview {
    SavedView()
        .preferredColorScheme(.dark)
}
