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
            header
            AnnotatableReadingText(raw: minute.text, key: readingKey, design: .serif)
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
        CardHeaderRow("Daily Minute") {
            SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            ShareLink(item: ShareTextBuilder.minuteShareText(minute)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share")
            if let audioURL = minute.audioURL, !audioURL.isEmpty {
                ListenButton(title: "Daily Minute") {
                    audio.play(url: audioURL, title: "Daily Minute")
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            // The full address, not the stem: this footer names a passage, and
            // the share text and the plain-text export name the same passage
            // the same way. Its offline twin, `CorpusReadingCard`, is the same
            // card in the same place, so the two cannot disagree about how
            // precisely a Daily Minute is addressed.
            if let segment = CorpusService.shared.segment(id: minute.segmentId) {
                Text(segment.citation ?? segment.bookName)
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(minute.wordCount) words")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .foregroundStyle(.secondary)
        }
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "daily-minute", in: modelContext)
    }
}
