import SwiftUI
import SwiftData

/// Renders a single `ArchivedReading` row inside the Archive tab's per-date detail.
///
/// Dispatches on `reading.channel`:
///   * `"daily-minute"` — renders the passage body in Georgia 18, italic source
///     reference, word count chip.
///   * `"daily-lesson"` — renders "Lesson N" + the title (stored in
///     `reading.text` per `ArchiveService.persistInlineLessons`). Archive lesson
///     entries don't ship a body, so there's no passage Text block.
///
/// Bookmark `itemKey` differs between channels:
///   * Minute: `"minute:\(reading.lineHash)"` — note this does **not** alias
///     with Today-tab bookmarks (which key off `DailyMinute.segmentHash`); the
///     two hash schemes differ and the same passage saved from both tabs lands
///     as two rows. Reconciliation is Phase 3.8 (Saved tab) scope.
///   * Lesson: `"lesson:\(reading.lessonNumber ?? 0)"` — aliases cleanly with
///     Today/Lessons bookmarks since lesson number is stable.
struct ArchivedReadingCard: View {
    let reading: ArchivedReading

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private var isMinute: Bool { reading.channel == "daily-minute" }

    private var itemKey: String {
        isMinute
            ? "minute:\(reading.lineHash)"
            : "lesson:\(reading.lessonNumber ?? 0)"
    }

    private var isBookmarked: Bool {
        bookmarks.contains(where: { $0.itemKey == itemKey })
    }

    private var headerLabel: String {
        if isMinute { return "Daily Minute" }
        if let n = reading.lessonNumber { return "Lesson \(n)" }
        return "Lesson"
    }

    private var listenTitle: String {
        if isMinute { return "Daily Minute" }
        if let n = reading.lessonNumber { return "Lesson \(n)" }
        return "Lesson"
    }

    private var shareText: String {
        isMinute
            ? ShareTextBuilder.archivedMinuteShareText(reading)
            : ShareTextBuilder.archivedLessonShareText(reading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isMinute {
                Text(reading.text)
                    .font(.custom("Georgia", size: 18))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                footerMinute
            } else {
                Text(reading.text.isEmpty ? headerLabel : reading.text)
                    .font(.custom("Georgia", size: 20).weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actionRow
        }
        .padding(16)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(headerLabel)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer()
            if !reading.dateString.isEmpty {
                Text(reading.dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footerMinute: some View {
        HStack(spacing: 8) {
            if !reading.sourceReference.isEmpty {
                Text(reading.sourceReference)
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button {
                toggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            }
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share")

            Spacer()

            if let audioURL = reading.audioURL, !audioURL.isEmpty {
                Button {
                    audio.play(url: audioURL, title: listenTitle)
                } label: {
                    Label("Listen", systemImage: "play.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Listen")
            }
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
    }

    private func toggleBookmark() {
        if let existing = bookmarks.first(where: { $0.itemKey == itemKey }) {
            modelContext.delete(existing)
        } else {
            let bookmark = Bookmark()
            bookmark.itemKey = itemKey
            bookmark.channel = reading.channel
            bookmark.createdAt = Date()
            modelContext.insert(bookmark)
        }
        try? modelContext.save()
    }
}
