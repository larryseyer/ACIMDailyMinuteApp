import SwiftUI
import SwiftData

/// Where an introduction reference points.
struct IntroductionRef: Hashable {
    let lessonNumber: Int
    var spotlight: ReadingSpotlight? = nil
}

/// One of the Workbook's two Part Introductions.
///
/// Separate from `LessonDetailView` on purpose: that screen resolves three
/// states against the feed and names itself "Lesson N", and neither is right for
/// a reading that has no number and was never published as a daily lesson. The
/// annotation key is still `.lesson(0)` / `.lesson(500)`, which already stores.
struct WorkbookIntroductionView: View {
    let lessonNumber: Int
    var spotlight: ReadingSpotlight? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private var itemKey: String { "lesson:\(lessonNumber)" }

    private var isBookmarked: Bool {
        bookmarks.contains { $0.itemKey == itemKey }
    }

    private var reading: (title: String, body: String)? {
        WorkbookBodiesCatalog.introduction(for: lessonNumber)
    }

    var body: some View {
        Group {
            if let reading {
                ScrollView {
                    ReadingScaffold(
                        eyebrow: "Introduction",
                        footer: ReadingFooter(
                            measure: ReadingTime.describe(
                                wordCount: ReadingTime.wordCount(of: reading.body)
                            )
                        )
                    ) {
                    } trailing: {
                        ShareButton(text: ShareTextBuilder.introductionShareText(
                            title: reading.title, body: reading.body
                        ))
                        SaveButton(isSaved: isBookmarked, action: toggleBookmark)
                    } titleBlock: {
                        Text(reading.title)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    } body: {
                        AnnotatableReadingText(
                            raw: reading.body,
                            key: .lesson(lessonNumber),
                            design: .serif,
                            lineSpacing: 3,
                            spotlight: spotlight,
                            recordsPosition: true
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableContentWidth()
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
                }
            } else {
                ContentUnavailableView {
                    Label("Introduction unavailable", systemImage: "book.closed")
                } description: {
                    Text("This introduction is not in the bundled Workbook.")
                }
            }
        }
        // The nav bar names the BOOK; the eyebrow names the place.
        .navigationTitle("Workbook")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "daily-lesson", in: modelContext)
    }
}
