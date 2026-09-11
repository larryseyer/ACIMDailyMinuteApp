import SwiftUI

struct ListenTextChapterRef: Hashable {
    let chapter: Int
}

/// Sections of one Text chapter, as Listen rows.
///
/// Play is omitted until that section has its own enclosure. Daily Minute
/// cuts of a passage in this chapter stay on the Minute shelf.
struct ListenTextChapterView: View {
    let chapter: Int
    let played: [String: Date]
    var isPlaying: Bool
    let isActive: (ListenLibrary.Row) -> Bool
    let onPlay: (ListenLibrary.Row) -> Void

    private let corpus = CorpusService.shared

    var body: some View {
        List {
            if let found = corpus.textChapter(chapter) {
                ForEach(rows(found), id: \.id) { row in
                    ListenPlayableRow(
                        row: row,
                        isActive: isActive(row),
                        isPlaying: isPlaying,
                        playedAt: played[row.episodeID],
                        unrecordedCaption: ListenLibrary.unrecordedCaption(availableOnFormatted: nil),
                        onTap: { onPlay(row) }
                    )
                    #if !os(tvOS)
                    .listRowSeparator(.visible)
                    #endif
                    .listRowBackground(Color.clear)
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
        .acimInkListBackground()
        .navigationTitle(corpus.textChapter(chapter)?.displayName ?? "Chapter \(chapter)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func rows(_ found: CorpusTextChapter) -> [ListenLibrary.Row] {
        ListenLibrary.textSectionRows(
            chapter: chapter,
            sections: found.sections.map { (number: $0.sectionNumber, title: $0.sectionTitle) },
            audioBySection: [:],
            episodeIDBySection: [:]
        )
    }
}
