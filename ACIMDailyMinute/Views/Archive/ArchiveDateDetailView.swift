import SwiftUI
import SwiftData

/// One calendar day's Video tab.
///
/// Landed on via `.navigationDestination(for: String.self)` from `ArchiveView`;
/// the destination value is `dateString` in `"YYYY-MM-DD"` form.
///
/// ⛔ **On iPhone, iPad, and Mac this tab plays YouTube.** The reading and the
/// MP3 live on Read and Listen. A day that opens as `ArchivedReadingCard` is
/// the old Archive tab wearing a Video label. The television has no WebKit:
/// it still builds the picture from the MP3.
struct ArchiveDateDetailView: View {
    let dateString: String
    /// Decided by `ArchiveView`, which already holds every archived date; a
    /// day with nothing to show is told when its reading will exist.
    let availability: MinuteSchedule.Availability
    /// Every day that has a reading, as the feed's own `yyyy-MM-dd`. An empty
    /// day uses this to list the nearest days before it that do; a day that
    /// already has a reading never asks.
    let archived: Set<String>

    @Query private var readings: [ArchivedReading]
    @Query private var minutes: [DailyMinute]
    @Query private var lessons: [DailyLesson]
    @Query private var podcasts: [CachedPodcastEpisode]
    #if os(tvOS)
    @Environment(\.openPlayer) private var openPlayer
    #endif

    init(
        dateString: String,
        availability: MinuteSchedule.Availability,
        archived: Set<String> = []
    ) {
        self.dateString = dateString
        self.availability = availability
        self.archived = archived
        _readings = Query(
            filter: #Predicate<ArchivedReading> { $0.dateString == dateString },
            sort: [SortDescriptor(\ArchivedReading.channel, order: .reverse)]
        )
    }

    var body: some View {
        Group {
            if readings.isEmpty {
                empty
            } else {
                #if os(tvOS)
                tvList
                #else
                videoList
                #endif
            }
        }
        .navigationTitle(formattedTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    #if os(tvOS)
    private var tvList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(readings) { reading in
                    Button { openPlayer(.archived(reading)) } label: {
                        ArchivedReadingCard(reading: reading)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(20)
            .readableContentWidth()
        }
    }
    #endif

    #if os(iOS) || os(macOS)
    private var videoList: some View {
        let items = videoItems
        return Group {
            if items.isEmpty {
                noVideo
            } else {
                VideoDayStack(items: items)
            }
        }
    }

    private var noVideo: some View {
        ContentUnavailableView(
            "No video for this day",
            systemImage: "play.slash",
            description: Text("Pull to refresh on the Video tab.")
        )
    }

    private var videoItems: [VideoDayItem] {
        readings.compactMap { reading in
            guard let id = youtubeID(for: reading) else { return nil }
            return VideoDayItem(
                id: reading.lineHash,
                title: title(for: reading),
                videoID: id
            )
        }
    }

    private func title(for reading: ArchivedReading) -> String {
        if reading.channel == "daily-minute" { return "Daily Minute" }
        if let n = reading.lessonNumber { return "Lesson \(n)" }
        return "Lesson"
    }

    /// Archive row, then today's stored minute/lesson, then the podcast
    /// `<link>`. Minute archive JSON ships no `youtube_id`; the podcast
    /// feed does.
    private func youtubeID(for reading: ArchivedReading) -> String? {
        if let id = YouTubeID.resolve(reading.youtubeID) { return id }
        if reading.channel == "daily-minute" {
            if let id = YouTubeID.resolve(
                minutes.first(where: { $0.date == reading.dateString })?.youtubeID
            ) { return id }
            let day = reading.dateString
            return podcasts.compactMap { episode -> String? in
                guard episode.channel == "minute" else { return nil }
                guard LessonSchedule.formatted(episode.publishedAt) == day else { return nil }
                return YouTubeID.resolve(episode.youtubeURL)
            }.first
        }
        if let number = reading.lessonNumber {
            if let id = YouTubeID.resolve(
                lessons.first(where: { $0.lessonNumber == number })?.youtubeID
            ) { return id }
            return podcasts.compactMap { episode -> String? in
                guard episode.channel == "lesson" else { return nil }
                guard LessonNarration.number(fromTitle: episode.title) == number else { return nil }
                return YouTubeID.resolve(episode.youtubeURL)
            }.first
        }
        return nil
    }
    #endif

    private var empty: some View {
        ContentUnavailableView(
            "No reading for this day",
            systemImage: "calendar.badge.exclamationmark",
            description: Text(availability.sentence ?? "Pull to refresh on the Video tab.")
        )
        .safeAreaInset(edge: .bottom) {
            if !nearbyDates.isEmpty {
                nearbyList
            }
        }
    }

    /// The nearest archived days strictly before this one. Empty when this
    /// day is the first publication, or before it, or the archive itself is
    /// empty — the sentence then stands alone, which is the truth.
    private var nearbyDates: [String] {
        guard let day = LessonSchedule.day(from: dateString) else { return [] }
        return MinuteSchedule.nearestArchivedDays(before: day, archived: archived)
    }

    private var nearbyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Earlier readings")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ForEach(nearbyDates, id: \.self) { neighbor in
                NavigationLink(value: neighbor) {
                    HStack {
                        Text(formatted(neighbor))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.acimCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                #if os(tvOS)
                .buttonStyle(.card)
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
        .padding(20)
        .readableContentWidth()
    }

    /// `"Thursday, April 10, 2026"` when the `dateString` parses, else the raw
    /// `"YYYY-MM-DD"` (never empty). Parsing matches `DataService.parseISODate`
    /// — UTC, `"yyyy-MM-dd"` — so the formatter stays symmetric with ingestion.
    private var formattedTitle: String { formatted(dateString) }

    private func formatted(_ value: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: value) else { return value }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#if os(iOS) || os(macOS)
private struct VideoDayItem: Identifiable {
    let id: String
    let title: String
    let videoID: String
    var playerURL: String { "https://www.youtube.com/embed/\(videoID)" }
}

private struct VideoDayStack: View {
    let items: [VideoDayItem]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                        LiteYouTubeCard(
                            videoID: item.videoID,
                            playerURL: item.playerURL,
                            accessibilityTitle: item.title
                        )
                    }
                }
            }
            .padding(20)
            .readableContentWidth()
        }
    }
}
#endif

#Preview {
    NavigationStack {
        ArchiveDateDetailView(dateString: "2026-04-10", availability: .unknown)
    }
    .preferredColorScheme(.dark)
    .modelContainer(
        for: [ArchivedReading.self, Bookmark.self, DailyMinute.self, DailyLesson.self, CachedPodcastEpisode.self],
        inMemory: true
    )
}
