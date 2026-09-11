import SwiftUI

/// Text spine: the Preface, then Chapters 1 through 31.
struct CourseTextSpine: View {
    @State private var searchText: String = ""

    private let corpus = CorpusService.shared

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let chapters = visibleChapters
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                CourseSpineMasthead(
                    title: CourseShelf.text.bookName,
                    sub: "31 chapters"
                )
                #if !os(tvOS)
                CourseSearchField(text: $searchText, prompt: "Search chapters")
                    .padding(.top, 14)
                #endif
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                if chapters.isEmpty {
                    ContentUnavailableView {
                        Label(
                            corpus.textChapters.isEmpty ? "The Text is unavailable" : "No matching chapters",
                            systemImage: "book.closed"
                        )
                    } description: {
                        Text(
                            corpus.textChapters.isEmpty
                            ? "The bundled Text could not be read from this build."
                            : "Nothing in the Text matches that search."
                        )
                    }
                    #if !os(tvOS)
                    .listRowSeparator(.hidden)
                    #endif
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(chapters) { chapter in
                        NavigationLink(value: TextChapterRef(chapter: chapter.number)) {
                            chapterRow(chapter)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 13))
                        .listRowBackground(Color.clear)
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                    }
                }
            }
            .listStyle(.plain)
            .readableContentWidth()
            .acimInkListBackground()
        }
        .acimInkBackground()
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var visibleChapters: [CorpusTextChapter] {
        let all = corpus.textChapters
        guard !trimmedQuery.isEmpty else { return all }
        return all.filter {
            $0.displayName.localizedStandardContains(trimmedQuery)
                || ($0.subtitle?.localizedStandardContains(trimmedQuery) ?? false)
        }
    }

    private func chapterRow(_ chapter: CorpusTextChapter) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Text(chapter.number == 0 ? "" : "\(chapter.number)")
                .font(.acimRowNumber)
                .foregroundStyle(Color.acimGold)
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.displayName)
                    .font(.acimRowTitle)
                    .foregroundStyle(.primary)
                if let subtitle = chapter.subtitle {
                    Text(subtitle)
                        .font(.acimRowSub)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(chapter.sections.count == 1 ? "1 section" : "\(chapter.sections.count) sections")
                    .font(.acimRowSub)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            CourseSpineGlyphs(hasAudio: false, hasVideo: false)
        }
        .padding(.vertical, Metric.row)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}
