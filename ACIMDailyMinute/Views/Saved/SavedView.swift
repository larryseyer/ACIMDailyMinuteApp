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
                        Text("Tap the bookmark icon on any Daily Minute, Lesson, or Archive entry to save it here.")
                    }
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            BookmarkRow(bookmark: bookmark)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .readableContentWidth()
                }
            }
            .navigationTitle("Saved")
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(bookmarks[idx])
        }
        try? modelContext.save()
    }
}

#Preview {
    SavedView()
        .preferredColorScheme(.dark)
}
