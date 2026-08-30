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
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \Highlight.createdAt, order: .reverse) private var highlights: [Highlight]
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var segment: Segment = .saved

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Shelf", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
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
            .navigationTitle("Saved")
            .navigationDestination(for: SavedDestination.self) { destination in
                switch destination {
                case .lesson(let number):
                    LessonDetailView(lessonNumber: number)
                case .archiveDate(let dateString):
                    ArchiveDateDetailView(dateString: dateString)
                }
            }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton { modelContext.delete(bookmark) }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            deleteButton { modelContext.delete(bookmark) }
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

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            action()
            try? modelContext.save()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

/// Where a saved row leads: back to the reading it was saved from. Hashable so
/// it can ride the `NavigationStack` path.
enum SavedDestination: Hashable {
    case lesson(Int)
    case archiveDate(String)
}

#Preview {
    SavedView()
        .preferredColorScheme(.dark)
}
