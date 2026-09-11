import SwiftUI
import SwiftData

/// Renders a single `ArchivedReading` row inside the Video tab's per-date detail.
///
/// Dispatches on `reading.channel`:
///   * `"daily-minute"` — the passage body through `AnnotatableReadingText`,
///     keyed by the day's `yyyy-MM-dd` so a highlight or note has somewhere
///     to live. Book name and date sit in the footer.
///   * `"daily-lesson"` — "Lesson N" and the title (stored in `reading.text`
///     per `ArchiveService.persistInlineLessons`). Archive lesson entries ship
///     no body, so the scaffold's body slot is empty and its footer follows the
///     title directly.
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
        ReadingScaffold(eyebrow: headerLabel, footer: footer) {
            ReadingPlayControl(
                title: listenTitle,
                lessonNumber: isMinute ? 0 : (reading.lessonNumber ?? 0),
                surfaceAudioURL: reading.audioURL,
                surfaceYouTubeID: reading.youtubeID
            )
        } trailing: {
            ShareButton(text: shareText)
            SaveButton(isSaved: isBookmarked, action: toggleBookmark)
        } titleBlock: {
            if !isMinute {
                Text(reading.text.isEmpty ? headerLabel : reading.text)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } body: {
            if isMinute {
                AnnotatableReadingText(
                    raw: reading.text,
                    key: .minuteDate(reading.dateString),
                    design: .serif
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.acimCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// An archived row carries no word count, so it shows no read time. Its
    /// date goes in the measure slot instead: on this tab a date is the index a
    /// reader navigates by, which is the one place the no-publication-dates
    /// rule does not apply.
    private var footer: ReadingFooter {
        ReadingFooter(
            bookName: isMinute && !reading.sourceReference.isEmpty
                ? CorpusSegment.bookName(forSourcePDF: reading.sourceReference)
                : nil,
            measure: reading.dateString.isEmpty ? nil : reading.dateString
        )
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: reading.channel, in: modelContext)
    }
}
