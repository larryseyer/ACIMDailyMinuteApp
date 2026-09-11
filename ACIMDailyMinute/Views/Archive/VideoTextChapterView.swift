import SwiftUI

struct VideoTextChapterRef: Hashable {
    let chapter: Int
}

/// Sections of one Text chapter, as Video rows.
///
/// Daily Minute recordings of a passage in this chapter stay on the Minute
/// shelf. This list does not push `TextSectionView`.
struct VideoTextChapterView: View {
    let chapter: Int
    let onOpen: (VideoLibrary.Row) -> Void

    private let corpus = CorpusService.shared

    var body: some View {
        List {
            if let found = corpus.textChapter(chapter) {
                ForEach(rows(found), id: \.id) { row in
                    VideoPlayableRow(title: row.title, onTap: { onOpen(row) })
                    #if !os(tvOS)
                    .listRowSeparator(.visible)
                    #endif
                }
            } else {
                ContentUnavailableView {
                    Label("Chapter unavailable", systemImage: "book.closed")
                } description: {
                    Text("This chapter is not in the bundled Text.")
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
        .navigationTitle(corpus.textChapter(chapter)?.displayName ?? "Chapter \(chapter)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func rows(_ found: CorpusTextChapter) -> [VideoLibrary.Row] {
        VideoLibrary.textSectionRows(
            chapter: chapter,
            sections: found.sections.map { (number: $0.sectionNumber, title: $0.sectionTitle) },
            videoIDsBySection: [:]
        )
    }
}
