import SwiftUI
import SwiftData

/// The feed-driven play control on a reading of a published segment or lesson.
///
/// Surfaces pass a key (`segment:<id>` / `lesson:<n>`) and, when they already
/// hold URLs, those as a fallback. The index wins when it has a value, so a
/// Course reading of a Daily Minute passage plays the same file the Today
/// card does, without each surface assembling its own Listen button.
///
/// ⛔ **Tap is audio.** Video takes the screen and is the most perishable
/// tier, so it lives on a long-press / context menu. No audio means no
/// control: absence is the normal state, and a Watch-only leading button
/// would be a second control the scaffold does not have a slot for.
struct ReadingPlayControl: View {
    let title: String
    private let segmentId: Int
    private let lessonNumber: Int
    var surfaceAudioURL: String? = nil
    var surfaceYouTubeID: String? = nil

    @Environment(AudioManager.self) private var audio
    @Query private var segmentRows: [SegmentMedia]
    @Query private var lessonRows: [DailyLesson]
    @Query private var archiveRows: [ArchivedReading]
    @Query private var podcasts: [CachedPodcastEpisode]
    @State private var isShowingVideo = false

    init(
        title: String,
        segmentId: Int = 0,
        lessonNumber: Int = 0,
        surfaceAudioURL: String? = nil,
        surfaceYouTubeID: String? = nil
    ) {
        self.title = title
        self.segmentId = segmentId
        self.lessonNumber = lessonNumber
        self.surfaceAudioURL = surfaceAudioURL
        self.surfaceYouTubeID = surfaceYouTubeID
        _segmentRows = Query(
            filter: #Predicate<SegmentMedia> { $0.segmentId == segmentId }
        )
        _lessonRows = Query(
            filter: #Predicate<DailyLesson> { $0.lessonNumber == lessonNumber }
        )
        _archiveRows = Query(
            filter: #Predicate<ArchivedReading> {
                $0.channel == "daily-lesson" && $0.lessonNumber == lessonNumber
            }
        )
        _podcasts = Query(
            filter: #Predicate<CachedPodcastEpisode> { $0.channel == "lesson" }
        )
    }

    private var hit: MediaOverlay.Hit? {
        let index = indexHit
        return MediaOverlay.Hit.resolve(
            indexAudio: index.audio,
            indexVideo: index.video,
            surfaceAudio: surfaceAudioURL,
            surfaceVideo: surfaceYouTubeID
        )
    }

    private var indexHit: (audio: String?, video: String?) {
        if segmentId > 0, let row = segmentRows.first {
            return (
                row.audioURL.isEmpty ? nil : row.audioURL,
                row.youtubeID.isEmpty ? nil : row.youtubeID
            )
        }
        if lessonNumber > 0 || (lessonNumber == 0 && title == "Introduction") {
            let daily = lessonRows.first
            let archived = archiveRows.first
            let podcast = LessonNarration.podcastURL(
                forLesson: lessonNumber,
                episodes: podcasts.map { (id: $0.id, title: $0.title, audioURL: $0.audioURL) }
            )
            let audio = LessonNarration.url(
                daily: daily?.audioURL,
                archived: archived?.audioURL,
                podcast: podcast
            )
            let video = firstNonEmpty(daily?.youtubeID, archived?.youtubeID)
            return (audio, video)
        }
        return (nil, nil)
    }

    private var videoURL: String? {
        guard let id = hit?.youtubeID, !id.isEmpty else { return nil }
        if id.contains("http") { return id }
        return "https://www.youtube.com/embed/\(id)"
    }

    var body: some View {
        #if os(tvOS)
        EmptyView()
        #else
        content
        #endif
    }

    #if !os(tvOS)
    @ViewBuilder
    private var content: some View {
        if let hit, hit.showsListen {
            ListenButton(
                title: title,
                isActive: audio.isActive(url: hit.audioURL),
                isPlaying: audio.isPlaying
            ) {
                audio.playOrToggle(url: hit.audioURL, title: title)
            }
            .contextMenu {
                if hit.showsWatch {
                    Button("Watch video") { isShowingVideo = true }
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $isShowingVideo) {
                if let videoURL {
                    FullScreenVideoCover(videoURL: videoURL)
                }
            }
            #elseif os(macOS)
            .sheet(isPresented: $isShowingVideo) {
                if let videoURL {
                    YouTubePlayerView(videoURL: videoURL, autoplay: true)
                        .frame(minWidth: 720, minHeight: 405)
                }
            }
            #endif
        }
    }
    #endif

    private func firstNonEmpty(_ a: String?, _ b: String?) -> String? {
        if let a, !a.isEmpty { return a }
        if let b, !b.isEmpty { return b }
        return nil
    }
}
