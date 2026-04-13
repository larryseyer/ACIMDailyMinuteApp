import SwiftUI
import SwiftData

struct StoryDetailView: View {
    let story: Story
    let sources: [Source]
    let correction: Correction?

    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @Query(sort: \Story.publishedAt, order: .reverse) private var allStories: [Story]

    @State private var showWatchTerms = false

    private var isBookmarked: Bool {
        bookmarks.contains { $0.storyId == story.id }
    }

    private var parsedBadges: [SourceBadge] {
        parseSourceDisplay(story.sourceDisplay)
    }

    private var relatedStories: [Story] {
        let myBadgeNames = Set(parsedBadges.map(\.name))
        return allStories.filter { other in
            guard other.id != story.id,
                  Calendar.current.isDate(other.publishedAt, inSameDayAs: story.publishedAt)
            else { return false }
            let otherNames = Set(parseSourceDisplay(other.sourceDisplay).map(\.name))
            return !myBadgeNames.isDisjoint(with: otherNames)
        }
    }

    private var shareText: String {
        ShareTextBuilder.shareText(
            fact: story.fact,
            sourceDisplay: story.sourceDisplay,
            sources: sources
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                factSection
                sourceSection
                if correction != nil {
                    correctionSection
                }
                if !relatedStories.isEmpty {
                    relatedSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Story")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .bottomBar) {
                toolbarContent
            }
            #else
            ToolbarItemGroup {
                toolbarContent
            }
            #endif
        }
        .sheet(isPresented: $showWatchTerms) {
            watchTermsSheet
        }
    }

    // MARK: - Fact Section

    private var factSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if correction != nil {
                Label("Correction", systemImage: "exclamationmark.triangle")
                    .font(.acimCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }

            Text(story.fact)
                .font(.acimBody)
                .fixedSize(horizontal: false, vertical: true)

            Text(relativeTime)
                .font(.acimCaption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Sources Section

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sources")
                .font(.acimHeadline)
                .foregroundStyle(.secondary)

            ForEach(parsedBadges, id: \.name) { badge in
                let matched = sources.first { $0.name == badge.name }
                SourceCard(badge: badge, source: matched, startExpanded: true)
            }
        }
    }

    // MARK: - Correction Section

    @ViewBuilder
    private var correctionSection: some View {
        if let correction {
            VStack(alignment: .leading, spacing: 10) {
                Text("Correction History")
                    .font(.acimHeadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(correction.originalFact)
                        .font(.acimBody)
                        .strikethrough()
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.down")
                        .foregroundStyle(.red.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(correction.correctedFact)
                        .font(.acimBody)

                    if !correction.reason.isEmpty {
                        Text(correction.reason)
                            .font(.acimCaption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }

                    if !correction.correctingSources.isEmpty {
                        HStack(spacing: 4) {
                            Text("Corrected by:")
                                .font(.acimCaption2)
                                .foregroundStyle(.tertiary)
                            Text(correction.correctingSources.joined(separator: ", "))
                                .font(.acimCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(formattedDate(correction.correctedAt))
                        .font(.acimCaption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(white: 0.13).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Related Stories Section

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More from Today")
                .font(.acimHeadline)
                .foregroundStyle(.secondary)

            ForEach(relatedStories, id: \.storyHash) { related in
                NavigationLink(value: related) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(related.fact)
                            .font(.acimSubheadline)
                            .lineLimit(2)
                            .foregroundStyle(.primary)

                        let badges = parseSourceDisplay(related.sourceDisplay)
                        FlowLayout(spacing: 4) {
                            ForEach(badges, id: \.name) { badge in
                                Text(badge.name)
                                    .font(.acimCaption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(white: 0.17).opacity(0.6))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.11).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Toolbar Actions

    private var toolbarContent: some View {
        HStack {
            ShareLink(
                item: shareText,
                preview: SharePreview("ACIM Daily Minute")
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Spacer()

            Button {
                toggleBookmark()
            } label: {
                Label(
                    isBookmarked ? "Bookmarked" : "Bookmark",
                    systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                )
            }

            Spacer()

            Button {
                showWatchTerms = true
            } label: {
                Label("Watch", systemImage: "bell.badge")
            }
        }
    }

    // MARK: - Watch Terms Sheet

    private var watchTermsSheet: some View {
        NavigationStack {
            WatchTermsPickerView(fact: story.fact)
                .navigationTitle("Watch Terms")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showWatchTerms = false }
                    }
                }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: story.publishedAt, relativeTo: Date())
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func toggleBookmark() {
        if let existing = bookmarks.first(where: { $0.storyId == story.id }) {
            modelContext.delete(existing)
        } else {
            let bookmark = Bookmark()
            bookmark.storyId = story.id
            bookmark.createdAt = Date()
            modelContext.insert(bookmark)
        }
    }
}

// MARK: - Watch Terms Picker

struct WatchTermsPickerView: View {
    let fact: String

    @State private var watchedTerms: [String] = WatchedTermsStorage.terms

    private var candidates: [String] {
        TermExtractor.candidates(from: fact)
    }

    private var atLimit: Bool {
        watchedTerms.count >= WatchedTermsStorage.maxTerms
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tap a term to add it to your watched list. You'll be notified when matching stories appear.")
                .font(.acimCaption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            if atLimit {
                Label(
                    "Watched terms full (\(WatchedTermsStorage.maxTerms)/\(WatchedTermsStorage.maxTerms)). Manage in Settings.",
                    systemImage: "exclamationmark.circle"
                )
                .font(.acimCaption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
            }

            FlowLayout(spacing: 8) {
                ForEach(candidates, id: \.self) { term in
                    let isWatched = watchedTerms.contains { $0.lowercased() == term.lowercased() }
                    Button {
                        addTerm(term)
                    } label: {
                        Text(term)
                            .font(.acimSubheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isWatched ? Color.green.opacity(0.2) : Color(white: 0.17).opacity(0.6))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isWatched ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                    .disabled(isWatched || atLimit)
                    .buttonStyle(.plain)
                    .opacity(isWatched ? 0.6 : (atLimit ? 0.4 : 1.0))
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 12)
    }

    private func addTerm(_ term: String) {
        guard !atLimit else { return }
        guard !watchedTerms.contains(where: { $0.lowercased() == term.lowercased() }) else { return }
        watchedTerms.append(term)
        WatchedTermsStorage.terms = watchedTerms
        WatchedTermsStorage.notifiedHashes = []
    }
}
