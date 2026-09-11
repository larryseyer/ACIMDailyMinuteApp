import SwiftUI
import SwiftData

struct DailyMinuteCard: View {
    let minute: DailyMinute
    /// True on a pushed Course reading of this day. Today keeps the action
    /// row; the page drops it for the medium band.
    var isPage: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    /// Same key the Archive card writes: `daily-minute|date`. A hash of the
    /// body made Today and Archive disagree about one passage.
    private var itemKey: String { "minute:\(ArchiveService.minuteLineHash(date: minute.date))" }

    /// Positional, so an annotation outlives the rolling archive window. The
    /// date is the fallback for a minute whose segment the feed did not name;
    /// `AnnotationStore.upgradeDateKeys` promotes it once that mapping lands.
    private var readingKey: ReadingKey {
        minute.segmentId > 0 ? .segment(minute.segmentId) : .minuteDate(minute.date)
    }

    private var isBookmarked: Bool {
        bookmarks.contains(where: { $0.itemKey == itemKey })
    }

    private var segment: CorpusSegment? {
        CorpusService.shared.segment(id: minute.segmentId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReadingScaffold(
                parent: isPage ? (segment?.bookName ?? "Daily Minute") : "",
                citation: isPage ? segment?.citation : nil,
                opensReading: isPage && segment != nil,
                footer: footer
            ) {
            } trailing: {
            } titleBlock: {
            } body: {
                AnnotatableReadingText(
                    raw: minute.text,
                    key: readingKey,
                    design: .serif,
                    lineSpacing: isPage ? Metric.readingPushedGap : Metric.readingGap,
                    basePointSize: isPage ? 18 : 19
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !isPage {
                TodayActionRow(
                    title: "Daily Minute",
                    segmentId: minute.segmentId,
                    surfaceAudioURL: minute.audioURL,
                    surfaceYouTubeID: minute.youtubeID,
                    shareText: ShareTextBuilder.minuteShareText(minute),
                    isSaved: isBookmarked,
                    onSave: toggleBookmark,
                    artworkText: minute.text,
                    subtitle: segment?.bookName ?? "",
                    bookmarkKey: itemKey,
                    bookmarkChannel: "daily-minute"
                )
            }
            if let error = audio.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if !os(tvOS)
        .toolbar {
            if isPage {
                ToolbarItemGroup(placement: .primaryAction) {
                    ShareButton(text: ShareTextBuilder.minuteShareText(minute))
                    SaveButton(isSaved: isBookmarked, action: toggleBookmark)
                }
            }
        }
        #endif
    }

    /// The full address, not the stem: this footer names a passage, and the
    /// share text and the plain-text export name the same passage the same way.
    /// Its offline twin, `CorpusReadingCard`, is the same card in the same
    /// place, so the two cannot disagree about how precisely a Daily Minute is
    /// addressed.
    private var footer: ReadingFooter {
        if isPage {
            return ReadingFooter(
                measure: ReadingTime.describe(wordCount: minute.wordCount)
            )
        }
        return ReadingFooter(
            citation: segment?.citation,
            bookName: segment?.bookName,
            opensReading: segment != nil,
            measure: ReadingTime.describe(wordCount: minute.wordCount)
        )
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "daily-minute", in: modelContext)
    }
}
