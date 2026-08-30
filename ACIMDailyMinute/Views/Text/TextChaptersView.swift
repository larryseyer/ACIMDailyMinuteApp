import SwiftUI

/// The Text's table of contents: the Preface, then Chapters 1 through 31.
///
/// Searching matches chapter and section titles and flattens to sections, so a
/// titled section is one search away from the top rather than two taps down.
/// Searching the *words* of the Text is separate work; this searches the
/// contents page, exactly as the Workbook shelf searches lesson titles.
struct TextChaptersView: View {
    @Environment(AudioManager.self) private var audio
    @State private var searchText: String = ""

    private let corpus = CorpusService.shared

    var body: some View {
        List {
            if corpus.textChapters.isEmpty {
                ContentUnavailableView {
                    Label("The Text is unavailable", systemImage: "book.closed")
                } description: {
                    Text("The bundled Text could not be read from this build.")
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if query.isEmpty {
                ForEach(corpus.textChapters) { chapter in
                    NavigationLink(value: TextChapterRef(chapter: chapter.number)) {
                        chapterRow(chapter)
                    }
                }
            } else if matches.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(matches, id: \.self) { ref in
                    NavigationLink(value: ref) { matchRow(ref) }
                }
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
        .searchable(text: $searchText, prompt: "Search chapters and sections")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matches: [TextSectionRef] {
        let text = query
        guard !text.isEmpty else { return [] }
        return corpus.textSections
            .filter {
                $0.sectionTitle.localizedStandardContains(text)
                    || $0.chapterTitle.localizedStandardContains(text)
            }
            .map { TextSectionRef(chapter: $0.chapterNumber, section: $0.sectionNumber) }
    }

    private func chapterRow(_ chapter: CorpusTextChapter) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(chapter.displayName)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(.primary)
            if let subtitle = chapter.subtitle {
                Text(subtitle)
                    .font(.acimCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(chapter.sections.count == 1 ? "1 section" : "\(chapter.sections.count) sections")
                .font(.acimCaption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func matchRow(_ ref: TextSectionRef) -> some View {
        if let section = corpus.textSection(chapter: ref.chapter, section: ref.section) {
            VStack(alignment: .leading, spacing: 3) {
                Text(section.sectionTitle)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(section.chapterNumber == 0
                     ? section.chapterTitle
                     : "Chapter \(section.chapterNumber)")
                    .font(.acimCaption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }
}
