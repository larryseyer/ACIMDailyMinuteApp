import SwiftUI
import SwiftData

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Story.publishedAt, order: .reverse) private var stories: [Story]
    @State private var isLoading = false

    private var todaysStories: [Story] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return stories.filter { $0.publishedAt >= startOfDay }
    }

    var body: some View {
        NavigationStack {
            if todaysStories.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Stories Yet",
                    systemImage: "newspaper",
                    description: Text("Pull down to refresh, or check back later.")
                )
            } else if todaysStories.isEmpty && isLoading {
                ProgressView("Fetching facts...")
            } else {
                List(todaysStories, id: \.id) { story in
                    WatchStoryRow(story: story)
                }
                .navigationTitle("ACIM Daily Minute")
                .refreshable { await fetchStories() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("\(todaysStories.count)")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.831, green: 0.686, blue: 0.216))
                    }
                }
            }
        }
        .task { await fetchStories() }
    }

    private func fetchStories() async {
        let dataService = WatchDataService(modelContainer: modelContext.container)
        isLoading = true
        defer { isLoading = false }
        do {
            try await dataService.fetchStories()
        } catch {
            // Silently fail — the empty state is informative enough
        }
    }
}
