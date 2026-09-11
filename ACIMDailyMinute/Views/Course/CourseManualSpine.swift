import SwiftUI

/// Manual spine: Introduction through the closings, one row a section.
struct CourseManualSpine: View {
    @State private var searchText: String = ""

    private let corpus = CorpusService.shared

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let sections = visibleSections
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                CourseSpineMasthead(
                    title: CourseShelf.manual.bookName,
                    sub: "31 sections"
                )
                #if !os(tvOS)
                CourseSearchField(text: $searchText, prompt: "Search the Manual")
                    .padding(.top, 14)
                #endif
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                if sections.isEmpty {
                    ContentUnavailableView {
                        Label(
                            corpus.manualSections.isEmpty ? "The Manual is unavailable" : "No matching sections",
                            systemImage: "book.closed"
                        )
                    } description: {
                        Text(
                            corpus.manualSections.isEmpty
                            ? "The bundled Manual could not be read from this build."
                            : "Nothing in the Manual matches that search."
                        )
                    }
                    #if !os(tvOS)
                    .listRowSeparator(.hidden)
                    #endif
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sections) { section in
                        NavigationLink(value: ManualSectionRef(number: section.number)) {
                            sectionRow(section)
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

    private var visibleSections: [CorpusManualSection] {
        let all = corpus.manualSections
        guard !trimmedQuery.isEmpty else { return all }
        return all.filter {
            $0.title.localizedStandardContains(trimmedQuery)
                || $0.stem.localizedStandardContains(trimmedQuery)
        }
    }

    private func sectionRow(_ section: CorpusManualSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Text(section.number == 0 ? "" : "\(section.number)")
                .font(.acimRowNumber)
                .foregroundStyle(Color.acimGold)
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.acimRowTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(section.stem)
                    .font(.acimRowSub)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            CourseSpineGlyphs(hasAudio: false, hasVideo: false)
        }
        .padding(.vertical, Metric.row)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}
