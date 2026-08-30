import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]

    var body: some View {
        NavigationStack {
            Group {
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
                                // Both edges delete. `.onDelete` only ever
                                // produces a trailing swipe, and a saved item is
                                // the kind of thing people flick away in either
                                // direction.
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    deleteButton(for: bookmark)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    deleteButton(for: bookmark)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .readableContentWidth()
                }
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

    private func deleteButton(for bookmark: Bookmark) -> some View {
        Button(role: .destructive) {
            modelContext.delete(bookmark)
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
