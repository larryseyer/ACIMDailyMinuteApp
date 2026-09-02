import SwiftUI

/// What the Read tab shows while a query is typed: the headings that match,
/// then every place the words occur, in book order, each with its address.
///
/// The scan runs on `CorpusSearchService`, off the main thread, and is
/// abandoned the moment the query changes; the first query also pays for
/// building the index, once.
struct ReadSearchResultsList: View {
    let query: String

    @Environment(AudioManager.self) private var audio
    @State private var results: SearchResults?
    @State private var index: SearchIndex?

    private let service = CorpusSearchService.shared

    private struct HitGroup: Identifiable {
        let record: Int
        let hits: [SearchHit]
        var id: Int { record }
    }

    var body: some View {
        let headings = service.headings(matching: query)
        List {
            if !headings.isEmpty {
                Section("Headings") {
                    ForEach(Array(headings.enumerated()), id: \.offset) { _, entry in
                        link(entry.key, spotlight: nil) { headingRow(entry) }
                    }
                }
            }
            if let results, let index {
                if results.hits.isEmpty && headings.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(groups(results.hits)) { group in
                        Section {
                            ForEach(group.hits, id: \.self) { hit in
                                link(service.entries[hit.record].key, spotlight: spotlight(for: hit, in: index)) {
                                    hitRow(hit, in: index)
                                }
                            }
                        } header: {
                            groupHeader(service.entries[group.record])
                        }
                    }
                    if results.truncated {
                        Text("Showing the first \(SearchIndex.hitCap) matches. Add a word to narrow it.")
                            .font(.acimCaption)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            } else if headings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
        .task(id: query) {
            // A pause after the last keystroke, so a reader typing a phrase
            // does not run one scan per letter.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let found = await service.search(query)
            guard !Task.isCancelled else { return }
            index = found.index
            results = found.results
        }
    }

    /// One `NavigationLink` per kind of reading, pushed as its own ref type so
    /// the Read tab's `navigationDestination(for:)` declarations match it.
    @ViewBuilder
    private func link<Label: View>(
        _ key: ReadingKey,
        spotlight: ReadingSpotlight?,
        @ViewBuilder label: () -> Label
    ) -> some View {
        switch key {
        case .textSection(let chapter, let section):
            NavigationLink(value: TextSectionRef(chapter: chapter, section: section, spotlight: spotlight), label: label)
        case .lesson(let n) where n == 0 || n == 500:
            NavigationLink(value: IntroductionRef(lessonNumber: n, spotlight: spotlight), label: label)
        case .lesson(let n):
            NavigationLink(value: LessonRef(lessonNumber: n, spotlight: spotlight), label: label)
        case .manual(let id):
            NavigationLink(value: ManualSegmentRef(segmentId: id, spotlight: spotlight), label: label)
        case .segment, .minuteDate:
            // Never indexed. Drawn inert rather than pushed somewhere wrong.
            label()
        }
    }

    private func spotlight(for hit: SearchHit, in index: SearchIndex) -> ReadingSpotlight {
        let display = index.records[hit.record].display
        let start = display.index(display.startIndex, offsetBy: hit.range.lowerBound)
        let end = display.index(start, offsetBy: hit.range.count)
        return ReadingSpotlight(
            startOffset: hit.range.lowerBound,
            length: hit.range.count,
            quote: String(display[start..<end])
        )
    }

    private func groups(_ hits: [SearchHit]) -> [HitGroup] {
        var groups: [HitGroup] = []
        var current: Int?
        var bucket: [SearchHit] = []
        for hit in hits {
            if hit.record != current {
                if let current { groups.append(HitGroup(record: current, hits: bucket)) }
                current = hit.record
                bucket = []
            }
            bucket.append(hit)
        }
        if let current { groups.append(HitGroup(record: current, hits: bucket)) }
        return groups
    }

    private func groupHeader(_ entry: SearchEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(.primary)
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.acimCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }

    private func headingRow(_ entry: SearchEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.primary)
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.acimCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func hitRow(_ hit: SearchHit, in index: SearchIndex) -> some View {
        let snippet = index.snippet(for: hit)
        let entry = service.entries[hit.record]
        let citation = CitationResolver.citation(
            for: entry.key,
            characterOffset: hit.range.lowerBound,
            displayString: index.records[hit.record].display
        )
        return VStack(alignment: .leading, spacing: 4) {
            (Text(flat(snippet.before))
                + Text(flat(snippet.match)).bold()
                + Text(flat(snippet.after)))
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(citation?.rawValue ?? "Manual for Teachers")
                .font(.acimCaption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// A snippet keeps the display string's paragraph breaks; a row is one line.
    private func flat(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }
}
