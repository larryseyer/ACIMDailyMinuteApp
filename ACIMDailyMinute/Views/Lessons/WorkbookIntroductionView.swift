import SwiftUI
import SwiftData

/// Where an introduction reference points.
struct IntroductionRef: Hashable {
    let lessonNumber: Int
    var spotlight: ReadingSpotlight? = nil
}

/// A Workbook introduction outside the 1-365 spine.
///
/// Separate from `LessonDetailView` on purpose: that screen resolves three
/// states against the feed and names itself "Lesson N", and neither is right for
/// a reading that has no number and was never published as a daily lesson. The
/// annotation key is still `.lesson(id)`, which already stores.
struct WorkbookIntroductionView: View {
    let lessonNumber: Int
    var spotlight: ReadingSpotlight? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]

    private var itemKey: String { "lesson:\(lessonNumber)" }

    private var isBookmarked: Bool {
        bookmarks.contains { $0.itemKey == itemKey }
    }

    private var reading: WorkbookIntroduction? {
        WorkbookBodiesCatalog.introduction(for: lessonNumber)
    }

    var body: some View {
        Group {
            if let reading {
                ScrollView {
                    ReadingScaffold(
                        parent: "Workbook",
                        citation: reading.citationStem,
                        footer: ReadingFooter(
                            measure: ReadingTime.describe(
                                wordCount: ReadingTime.wordCount(of: reading.body)
                            )
                        )
                    ) {
                    } trailing: {
                    } titleBlock: {
                        Text(reading.title)
                            .font(.acimDisplayTitle)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 24)
                    } body: {
                        AnnotatableReadingText(
                            raw: reading.body,
                            key: .lesson(lessonNumber),
                            design: .serif,
                            lineSpacing: Metric.readingPushedGap,
                            basePointSize: 18,
                            spotlight: spotlight,
                            recordsPosition: true
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Metric.gutter)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableContentWidth()
                }
                .readingMediumBand(
                    title: reading.title,
                    lessonNumber: lessonNumber,
                    composeItem: .workbookLesson(lessonNumber),
                    artworkText: reading.body,
                    shareText: ShareTextBuilder.introductionShareText(
                        title: reading.title, body: reading.body
                    )
                )
                #if !os(tvOS)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        ShareButton(text: ShareTextBuilder.introductionShareText(
                            title: reading.title, body: reading.body
                        ))
                        SaveButton(isSaved: isBookmarked, action: toggleBookmark)
                    }
                }
                #endif
            } else {
                ContentUnavailableView {
                    Label("Introduction unavailable", systemImage: "book.closed")
                } description: {
                    Text("This introduction is not in the bundled Workbook.")
                }
            }
        }
        .navigationTitle("Workbook")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "daily-lesson", in: modelContext)
    }
}
