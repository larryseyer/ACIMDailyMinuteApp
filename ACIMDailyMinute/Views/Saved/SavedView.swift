import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \Story.publishedAt, order: .reverse) private var stories: [Story]
    @Query private var corrections: [Correction]
    @Query private var sources: [Source]

    private var savedStories: [Story] {
        let bookmarkIds = Set(bookmarks.map(\.storyId))
        return stories.filter { bookmarkIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if savedStories.isEmpty {
                    emptyView
                } else {
                    savedList
                }
            }
            .navigationDestination(for: Story.self) { story in
                let correction = corrections.first { $0.storyId == story.id }
                StoryDetailView(story: story, sources: sources, correction: correction)
            }
            .navigationTitle("Saved")
        }
    }

    // MARK: - Saved List

    private var savedList: some View {
        List {
            ForEach(savedStories, id: \.storyHash) { story in
                let correction = corrections.first { $0.storyId == story.id }
                NavigationLink(value: story) {
                    StoryCard(story: story, sources: sources, correction: correction)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        removeBookmark(for: story)
                    } label: {
                        Label("Remove", systemImage: "bookmark.slash")
                    }

                    ShareLink(
                        item: ShareTextBuilder.shareText(
                            fact: story.fact,
                            sourceDisplay: story.sourceDisplay,
                            sources: sources
                        ),
                        preview: SharePreview("ACIM Daily Minute")
                    ) {
                        Label("Share Story", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Saved Stories")
                .font(.title3)
                .fontWeight(.medium)
            Text("Bookmark stories to save them here for later")
                .font(.acimSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func removeBookmark(for story: Story) {
        if let bookmark = bookmarks.first(where: { $0.storyId == story.id }) {
            modelContext.delete(bookmark)
        }
    }
}

#Preview {
    SavedView()
        .preferredColorScheme(.dark)
}
