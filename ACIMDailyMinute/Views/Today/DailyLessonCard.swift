import SwiftUI
import SwiftData

struct DailyLessonCard: View {
    let lesson: DailyLesson

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private var itemKey: String { "lesson:\(lesson.lessonNumber)" }

    private var isBookmarked: Bool {
        bookmarks.contains(where: { $0.itemKey == itemKey })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReadingScaffold(
                eyebrow: "Lesson \(lesson.lessonNumber)",
                footer: ReadingFooter(measure: ReadingTime.describe(wordCount: lesson.wordCount))
            ) {
                if let audioURL = lesson.audioURL, !audioURL.isEmpty {
                    ListenButton(title: "Lesson \(lesson.lessonNumber)") {
                        audio.play(url: audioURL, title: "Lesson \(lesson.lessonNumber)")
                    }
                }
            } trailing: {
                ShareButton(text: ShareTextBuilder.lessonShareText(lesson))
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            } titleBlock: {
                Text(lesson.lessonTitle)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } body: {
                AnnotatableReadingText(
                    raw: lesson.text,
                    key: .lesson(lesson.lessonNumber),
                    design: .serif
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = audio.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "daily-lesson", in: modelContext)
    }
}
