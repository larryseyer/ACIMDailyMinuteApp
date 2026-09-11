import SwiftUI

/// The sections of one chapter of the Text.
struct TextChapterView: View {
    let chapter: Int

    @Environment(AudioManager.self) private var audio

    private let corpus = CorpusService.shared

    var body: some View {
        List {
            if let found = corpus.textChapter(chapter) {
                if let subtitle = found.subtitle {
                    Text(subtitle)
                        .font(.acimCaption)
                        .foregroundStyle(.secondary)
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .listRowBackground(Color.clear)
                }
                ForEach(found.sections, id: \.sectionNumber) { section in
                    NavigationLink(
                        value: TextSectionRef(chapter: chapter, section: section.sectionNumber)
                    ) {
                        sectionRow(section)
                    }
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
        // ⛔ A Text chapter has no audio. Leaving a Workbook session up would
        // keep the previous lesson in the mini player under this page.
        .onAppear { audio.dismissForTextReading() }
    }

    private func sectionRow(_ section: CorpusTextSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(section.sectionTitle)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let readTime = ReadingTime.describe(wordCount: section.wordCount) {
                Text(readTime)
                    .font(.acimCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
