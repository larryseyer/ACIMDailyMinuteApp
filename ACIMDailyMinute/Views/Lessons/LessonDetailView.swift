import SwiftUI
import SwiftData

/// Detail screen for a single workbook lesson (1–365), landed on via
/// `.navigationDestination(for: Int.self)` declared in `LessonsView`.
///
/// Three render states, resolved locally (no network on initial render):
/// 1. **Full** — a `DailyLesson` row exists for this `lessonNumber`. Full body,
///    bookmark, share, audio.
/// 2. **Metadata-only** — no `DailyLesson`, but an `ArchivedReading` where
///    `channel == "daily-lesson"` does. The lesson *title* is stored in
///    `archive.text` (archive entries ship `{lesson_id, title, date, audio_url}`
///    — no body), per `ArchiveService.persistInlineLessons`.
/// 3. **Absent** — neither row exists. Shows a YouTube playlist embed for
///    the lesson so the user can watch it directly.
struct LessonDetailView: View {
    let lessonNumber: Int
    var spotlight: ReadingSpotlight? = nil
    /// Choosing a lesson from a list is a request to watch it; following a
    /// reference or a search hit into it is a request to read it.
    var presentsVideo: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Query private var lessonMatches: [DailyLesson]
    @Query private var archiveMatches: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    /// Everything recorded, for the anchor `LessonSchedule` counts weekdays
    /// from — the same candidates `LessonsView` hands it, so the date this
    /// screen prints is the date the row printed.
    @Query(sort: \DailyLesson.lessonNumber) private var allLessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    ) private var allArchivedLessons: [ArchivedReading]

    /// The day this lesson's recording is due, or `nil` once it has been
    /// recorded — or when nothing dated has been seen yet, in which case the
    /// screen says nothing rather than guessing.
    private var availableOn: Date? {
        guard let anchor = LessonSchedule.anchor(
            from: allLessons.map { ($0.lessonNumber, $0.publishedAt) }
                + allArchivedLessons.map { ($0.lessonNumber ?? 0, $0.timestamp) }
        ) else { return nil }
        return LessonSchedule.availabilityDate(
            for: lessonNumber, latestRecorded: anchor.number, latestDate: anchor.date
        )
    }

    /// A lesson bookmark is keyed by number alone, so saving does not depend on
    /// which of the three states rendered. It used to live inside
    /// `FullLessonView`, which meant a lesson the feed has not published yet had
    /// no way to be saved at all, even though the Lessons list would happily
    /// show a bookmark indicator for one.
    private var itemKey: String { "lesson:\(lessonNumber)" }

    private var isBookmarked: Bool {
        bookmarks.contains(where: { $0.itemKey == itemKey })
    }

    init(lessonNumber: Int, spotlight: ReadingSpotlight? = nil, presentsVideo: Bool = true) {
        self.lessonNumber = lessonNumber
        self.spotlight = spotlight
        self.presentsVideo = presentsVideo
        _lessonMatches = Query(
            filter: #Predicate<DailyLesson> { $0.lessonNumber == lessonNumber }
        )
        _archiveMatches = Query(
            filter: #Predicate<ArchivedReading> {
                $0.channel == "daily-lesson" && $0.lessonNumber == lessonNumber
            }
        )
    }

    /// Choosing a lesson *is* the request to watch it, so the video opens
    /// full screen and playing rather than making the reader find and tap a
    /// play button and then a fullscreen button. Dismissing it lands on the
    /// lesson text, which is still here underneath.
    @State private var hasAutoPresentedVideo = false
    @State private var isShowingVideo = false

    /// This lesson's own video, or `nil` when we don't know it.
    ///
    /// Never falls back to a playlist position: YouTube ignores `index` on a
    /// `videoseries` embed and plays the newest upload, so lesson 27 opened
    /// lesson 81. Showing the wrong lesson is worse than showing none.
    private var lessonVideoURL: String? {
        // Scans every match rather than trusting `.first`: duplicate archive
        // rows from the old title-hash identity may still be on disk until the
        // next successful fetch collapses them, and only one carries the video.
        let candidates = lessonMatches.compactMap(\.youtubeID) + archiveMatches.compactMap(\.youtubeID)
        guard let videoID = candidates.first(where: { !$0.isEmpty }) else { return nil }
        return "https://www.youtube.com/embed/\(videoID)"
    }

    var body: some View {
        Group {
            if let lesson = lessonMatches.first {
                FullLessonView(
                    lesson: lesson,
                    spotlight: spotlight,
                    isBookmarked: isBookmarked,
                    toggleBookmark: toggleBookmark
                )
            } else if let archive = archiveMatches.first {
                MetadataOnlyLessonView(
                    lessonNumber: lessonNumber,
                    archive: archive,
                    spotlight: spotlight,
                    isBookmarked: isBookmarked,
                    toggleBookmark: toggleBookmark
                )
            } else {
                AbsentLessonView(
                    lessonNumber: lessonNumber,
                    availableOn: availableOn,
                    spotlight: spotlight,
                    isBookmarked: isBookmarked,
                    toggleBookmark: toggleBookmark
                )
            }
        }
        // The nav bar names the BOOK; the scaffold's eyebrow names the place.
        // Saying "Lesson 84" in both put the same phrase twice within 40 points.
        .navigationTitle("Workbook")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingVideo) {
            if let videoURL = lessonVideoURL {
                FullScreenVideoCover(videoURL: videoURL)
            }
        }
        .onAppear {
            // Choosing a lesson from the list is a request to watch it; choosing
            // a sentence from a search is a request to read it.
            guard presentsVideo, !hasAutoPresentedVideo, spotlight == nil, lessonVideoURL != nil else { return }
            hasAutoPresentedVideo = true
            isShowingVideo = true
        }
        #endif
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "daily-lesson", in: modelContext)
    }
}




// MARK: - Full state

private struct FullLessonView: View {
    let lesson: DailyLesson
    var spotlight: ReadingSpotlight? = nil
    let isBookmarked: Bool
    let toggleBookmark: () -> Void

    @Environment(AudioManager.self) private var audio

    var body: some View {
        ScrollView {
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
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } body: {
                AnnotatableReadingText(
                    raw: lesson.text,
                    key: .lesson(lesson.lessonNumber),
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
    }
}

// MARK: - Metadata-only state

private struct MetadataOnlyLessonView: View {
    let lessonNumber: Int
    let archive: ArchivedReading
    var spotlight: ReadingSpotlight? = nil
    let isBookmarked: Bool
    let toggleBookmark: () -> Void

    @Environment(AudioManager.self) private var audio

    private var title: String {
        WorkbookCatalog.title(for: lessonNumber) ?? (archive.text.isEmpty ? "Lesson \(lessonNumber)" : archive.text)
    }

    private var embedURL: String? {
        guard let videoID = archive.youtubeID, !videoID.isEmpty else { return nil }
        return "https://www.youtube.com/embed/\(videoID)"
    }

    /// The bundled body, when there is one. A lesson the feed has not published
    /// still has all 365 bodies behind it.
    private var bundledBody: String? {
        WorkbookBodiesCatalog.body(for: lessonNumber)
    }

    var body: some View {
        ScrollView {
            ReadingScaffold(
                eyebrow: "Lesson \(lessonNumber)",
                footer: ReadingFooter(
                    measure: bundledBody.flatMap {
                        ReadingTime.describe(wordCount: ReadingTime.wordCount(of: $0))
                    }
                )
            ) {
                if let audioURL = archive.audioURL, !audioURL.isEmpty {
                    ListenButton(title: "Lesson \(lessonNumber)") {
                        audio.play(url: audioURL, title: "Lesson \(lessonNumber)")
                    }
                }
            } trailing: {
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            } titleBlock: {
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } body: {
                if let bundledBody {
                    AnnotatableReadingText(
                        raw: bundledBody,
                        key: .lesson(lessonNumber),
                        design: .standard,
                        spotlight: spotlight,
                        recordsPosition: true
                    )
                } else if lessonNumber > 0, let embedURL {
                    // ⛔ The video stand-in is iOS only — tvOS has no WebKit. The
                    // fence is INSIDE the branch, not around it: a `#if` between
                    // `}` and `else` severs the if-else chain and the compiler
                    // reports only "expected expression". All 365 lesson bodies
                    // are bundled, so this branch is a fallback a reader is not
                    // expected to reach.
                    #if os(iOS)
                    YouTubePlayerView(videoURL: embedURL)
                        .aspectRatio(16.0/9.0, contentMode: .fit)
                    #endif
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .readableContentWidth()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
    }
}

// MARK: - Absent state (bundled body text with YouTube playlist fallback)

private struct AbsentLessonView: View {
    let lessonNumber: Int
    /// Set when the recording is still to come. The text below is bundled and
    /// readable regardless; this line is what answers the tap on a dimmed row.
    let availableOn: Date?
    var spotlight: ReadingSpotlight? = nil
    let isBookmarked: Bool
    let toggleBookmark: () -> Void

    @Query(filter: #Predicate<CachedPodcastEpisode> { $0.channel == "lesson" })
    private var cachedLessons: [CachedPodcastEpisode]

    @Environment(AudioManager.self) private var audio

    private var introAudioURL: String? {
        cachedLessons.first(where: {
            $0.title.trimmingCharacters(in: .whitespaces) == "Introduction"
        })?.audioURL
    }

    private var title: String {
        WorkbookCatalog.title(for: lessonNumber) ?? "Lesson \(lessonNumber)"
    }

    private var bundledBody: String? {
        lessonNumber == 0 ? nil : WorkbookBodiesCatalog.body(for: lessonNumber)
    }

    var body: some View {
        ScrollView {
            ReadingScaffold(
                eyebrow: "Lesson \(lessonNumber)",
                footer: ReadingFooter(
                    measure: bundledBody.flatMap {
                        ReadingTime.describe(wordCount: ReadingTime.wordCount(of: $0))
                    }
                )
            ) {
                if lessonNumber == 0, let audioURL = introAudioURL, !audioURL.isEmpty {
                    ListenButton(title: "Introduction") {
                        audio.play(url: audioURL, title: "Introduction")
                    }
                }
            } trailing: {
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            } titleBlock: {
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } body: {
                VStack(alignment: .leading, spacing: 16) {
                    if let availableOn {
                        Label(
                            "Not recorded yet. Audio and video available \(LessonSchedule.formatted(availableOn)).",
                            systemImage: "clock"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let bundledBody {
                        AnnotatableReadingText(
                            raw: bundledBody,
                            key: .lesson(lessonNumber),
                            design: .standard,
                            spotlight: spotlight,
                            recordsPosition: true
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .readableContentWidth()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
    }
}
