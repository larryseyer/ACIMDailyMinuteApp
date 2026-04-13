import SwiftUI
import SwiftData

private struct StoryMatch: Identifiable {
    let story: Story
    let term: String
    var id: String { story.storyHash }
}

struct WatchedView: View {
    @Query(sort: \Story.publishedAt, order: .reverse) private var stories: [Story]
    @Query private var corrections: [Correction]
    @Query private var sources: [Source]
    @AppStorage("watchedTabBadge") private var badgeCount = 0
    @State private var showSettings = false

    private var matchingStories: [StoryMatch] {
        let terms = WatchedTermsStorage.terms
        guard !terms.isEmpty else { return [] }
        let lowercasedTerms = terms.map { $0.lowercased() }

        return stories.compactMap { story in
            let lowFact = story.fact.lowercased()
            guard let term = lowercasedTerms.first(where: { lowFact.contains($0) })
            else { return nil }
            return StoryMatch(story: story, term: term)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if WatchedTermsStorage.terms.isEmpty {
                    noTermsView
                } else if matchingStories.isEmpty {
                    noMatchesView
                } else {
                    matchList
                }
            }
            .navigationDestination(for: Story.self) { story in
                let correction = corrections.first { $0.storyId == story.id }
                StoryDetailView(story: story, sources: sources, correction: correction)
            }
            .navigationTitle("Watched")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    WatchedTermsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showSettings = false }
                            }
                        }
                }
            }
        }
        .onAppear { badgeCount = 0 }
    }

    // MARK: - Match List

    private var matchList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(matchingStories) { match in
                    matchRow(for: match)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func matchRow(for match: StoryMatch) -> some View {
        let correction = corrections.first { $0.storyId == match.story.id }
        NavigationLink(value: match.story) {
            VStack(alignment: .leading, spacing: 8) {
                StoryCard(story: match.story, sources: sources, correction: correction)
                termBadge(match.term)
            }
        }
        .buttonStyle(.plain)
    }

    private func termBadge(_ term: String) -> some View {
        Text(term.lowercased())
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
            .padding(.horizontal, 16)
    }

    // MARK: - Empty States

    private var noTermsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Watched Terms")
                .font(.title3)
                .fontWeight(.medium)
            Text("Set up watched terms to track stories that matter to you")
                .font(.acimSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Watched Terms") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noMatchesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Matches Right Now")
                .font(.title3)
                .fontWeight(.medium)
            Text("No stories match your watched terms right now")
                .font(.acimSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    WatchedView()
        .preferredColorScheme(.dark)
}
