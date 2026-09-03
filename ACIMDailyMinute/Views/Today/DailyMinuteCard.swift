import SwiftUI
import SwiftData

struct DailyMinuteCard: View {
    let minute: DailyMinute

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private var itemKey: String { "minute:\(minute.segmentHash)" }

    /// Positional, so an annotation outlives the rolling archive window. The
    /// date is the fallback for a minute whose segment the feed did not name;
    /// `AnnotationStore.upgradeDateKeys` promotes it once that mapping lands.
    private var readingKey: ReadingKey {
        minute.segmentId > 0 ? .segment(minute.segmentId) : .minuteDate(minute.date)
    }

    private var isBookmarked: Bool {
        bookmarks.contains(where: { $0.itemKey == itemKey })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReadingScaffold(eyebrow: "Daily Minute", footer: footer) {
                if let audioURL = minute.audioURL, !audioURL.isEmpty {
                    ListenButton(title: "Daily Minute") {
                        audio.play(url: audioURL, title: "Daily Minute")
                    }
                }
            } trailing: {
                ShareButton(text: ShareTextBuilder.minuteShareText(minute))
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            } titleBlock: {
            } body: {
                AnnotatableReadingText(raw: minute.text, key: readingKey, design: .serif)
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
        .background(Color.acimCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// The full address, not the stem: this footer names a passage, and the
    /// share text and the plain-text export name the same passage the same way.
    /// Its offline twin, `CorpusReadingCard`, is the same card in the same
    /// place, so the two cannot disagree about how precisely a Daily Minute is
    /// addressed.
    private var footer: ReadingFooter {
        let segment = CorpusService.shared.segment(id: minute.segmentId)
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
