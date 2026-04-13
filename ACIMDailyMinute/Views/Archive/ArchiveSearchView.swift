import SwiftUI
import SwiftData

/// Full-text search across every cached `ArchivedStory` row.
///
/// Search is backed directly by SwiftData via a `@Query` with a dynamic
/// predicate on `searchableText.localizedStandardContains(query)` — no
/// external index, no raw-text re-parsing, no cache invalidation to worry
/// about. As new rows are ingested (e.g., by the background prefetch),
/// they become searchable the moment they're persisted.
struct ArchiveSearchView: View {
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            if searchText.isEmpty {
                emptyPromptView
            } else {
                FilteredArchiveStoryList(query: searchText)
            }
        }
        .navigationTitle("Search Archive")
        #if os(iOS)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search archive"
        )
        #else
        .searchable(text: $searchText, prompt: "Search archive")
        #endif
        .navigationDestination(for: String.self) { dateString in
            ArchiveDayDetailView(dateString: dateString)
        }
    }

    private var emptyPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Search across all archived stories")
                .font(.acimSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A small private view whose sole job is to own the dynamic `@Query`.
///
/// Wrapping the query in its own view lets us re-initialize it with a new
/// predicate whenever `query` changes — SwiftUI reconstructs the view, the
/// initializer runs, and `@Query` picks up the new filter. This is the
/// idiomatic SwiftData pattern for search-as-you-type.
private struct FilteredArchiveStoryList: View {
    @Query private var stories: [ArchivedStory]
    private let query: String

    init(query: String) {
        self.query = query
        _stories = Query(
            filter: #Predicate<ArchivedStory> { story in
                story.searchableText.localizedStandardContains(query)
            },
            sort: [
                SortDescriptor(\.dateString, order: .reverse),
                SortDescriptor(\.timestamp, order: .reverse)
            ]
        )
    }

    var body: some View {
        if stories.isEmpty {
            noResultsView
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(stories, id: \.lineHash) { story in
                        NavigationLink(value: story.dateString) {
                            resultCard(story)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.acimTitle)
                .foregroundStyle(.secondary)
            Text("No results for \"\(query)\"")
                .font(.acimSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resultCard(_ story: ArchivedStory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(story.factText)
                .font(.acimBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Text(story.dateString)
                    .font(.acimCaption)
                    .foregroundStyle(.secondary)
                if !story.sources.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(story.sources.joined(separator: ", "))
                        .font(.acimCaption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Shows all stories for a given archived date (used when navigating from search results)
struct ArchiveDayDetailView: View {
    let dateString: String
    @Environment(\.modelContext) private var modelContext
    @State private var stories: [ArchivedStory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading archive...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.acimTitle)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.acimSubheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !stories.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(stories, id: \.lineHash) { story in
                            storyCard(story)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(dateString)
        .task {
            await loadDay()
        }
    }

    private func loadDay() async {
        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            stories = try await service.fetchDay(dateString: dateString)
        } catch {
            errorMessage = "Archive not available for \(dateString)"
        }
        isLoading = false
    }

    private func storyCard(_ story: ArchivedStory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(story.factText)
                .font(.acimBody)
                .fixedSize(horizontal: false, vertical: true)

            if !story.sources.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(zip(story.sources, story.ratings).enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 4) {
                            Text(pair.0)
                                .font(.acimCaption)
                                .foregroundStyle(.primary.opacity(0.8))
                            if let ratingValue = pair.1.components(separatedBy: " ").first {
                                Text(ratingValue)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.17).opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
            }

            HStack {
                if let timestamp = story.timestamp {
                    Text(timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if story.isCorrected {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Corrected")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange.opacity(0.8))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
