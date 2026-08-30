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
            header
            Text(lesson.lessonTitle)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            ReadingTextView(raw: lesson.text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            footer
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

    private var header: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("Lesson \(lesson.lessonNumber)")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer()
            SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            ShareLink(item: ShareTextBuilder.lessonShareText(lesson)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share")
            if let audioURL = lesson.audioURL, !audioURL.isEmpty {
                Button {
                    audio.play(url: audioURL, title: "Lesson \(lesson.lessonNumber)")
                } label: {
                    Label("Listen", systemImage: "play.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Listen to Lesson")
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("\(lesson.wordCount) words")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .foregroundStyle(.secondary)
        }
    }

    private func toggleBookmark() {
        if let existing = bookmarks.first(where: { $0.itemKey == itemKey }) {
            modelContext.delete(existing)
        } else {
            let bookmark = Bookmark()
            bookmark.itemKey = itemKey
            bookmark.channel = "daily-lesson"
            bookmark.createdAt = Date()
            modelContext.insert(bookmark)
        }
        try? modelContext.save()
    }
}
