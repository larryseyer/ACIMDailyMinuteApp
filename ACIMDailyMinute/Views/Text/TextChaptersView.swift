import SwiftUI

/// The Text's table of contents: the Preface, then Chapters 1 through 31.
///
/// Searching — titles and words alike — is the Read tab's one search field;
/// this is only the contents page.
struct TextChaptersView: View {
    @Environment(AudioManager.self) private var audio

    private let corpus = CorpusService.shared

    var body: some View {
        List {
            if corpus.textChapters.isEmpty {
                ContentUnavailableView {
                    Label("The Text is unavailable", systemImage: "book.closed")
                } description: {
                    Text("The bundled Text could not be read from this build.")
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            } else {
                ForEach(corpus.textChapters) { chapter in
                    NavigationLink(value: TextChapterRef(chapter: chapter.number)) {
                        chapterRow(chapter)
                    }
                }
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
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
}
