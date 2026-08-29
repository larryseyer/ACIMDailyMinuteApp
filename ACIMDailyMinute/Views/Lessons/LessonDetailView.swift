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

    @Query private var lessonMatches: [DailyLesson]
    @Query private var archiveMatches: [ArchivedReading]

    init(lessonNumber: Int) {
        self.lessonNumber = lessonNumber
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

    private var lessonVideoURL: String {
        "https://www.youtube.com/embed/videoseries?list=\(YouTubePlaylists.dailyLesson)&index=\(lessonNumber)"
    }

    var body: some View {
        Group {
            if let lesson = lessonMatches.first {
                FullLessonView(lesson: lesson)
            } else if let archive = archiveMatches.first {
                MetadataOnlyLessonView(lessonNumber: lessonNumber, archive: archive)
            } else {
                AbsentLessonView(lessonNumber: lessonNumber)
            }
        }
        .navigationTitle("Lesson \(lessonNumber)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingVideo) {
            LessonVideoCover(videoURL: lessonVideoURL)
        }
        .onAppear {
            guard !hasAutoPresentedVideo else { return }
            hasAutoPresentedVideo = true
            isShowingVideo = true
        }
        #endif
    }
}

#if os(iOS)

// MARK: - Full-screen landscape video

/// Full-bleed autoplaying player. Locks to landscape on iPhone for the time it
/// is on screen; iPad keeps its own orientation (see `OrientationController`).
private struct LessonVideoCover: View {
    let videoURL: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()

            YouTubePlayerView(videoURL: videoURL, autoplay: true)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding(20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close video")
        }
        .statusBarHidden()
        .onAppear { OrientationController.lockLandscape() }
        .onDisappear { OrientationController.unlock() }
    }
}

#endif

// MARK: - Full state

private struct FullLessonView: View {
    let lesson: DailyLesson

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioManager.self) private var audio
    @Query private var bookmarks: [Bookmark]

    private var itemKey: String { "lesson:\(lesson.lessonNumber)" }

    private var isBookmarked: Bool {
        bookmarks.contains(where: { $0.itemKey == itemKey })
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lesson.publishedAt, relativeTo: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text(lesson.lessonTitle)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                ReadingTextView(raw: lesson.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                wordCountChip
                actionRow
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableContentWidth()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Lesson \(lesson.lessonNumber)")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer()
            Text(relativeDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var wordCountChip: some View {
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

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button {
                toggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            }
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")

            ShareLink(item: ShareTextBuilder.lessonShareText(lesson)) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share")

            Spacer()

            if let audioURL = lesson.audioURL, !audioURL.isEmpty {
                Button {
                    audio.play(url: audioURL, title: "Lesson \(lesson.lessonNumber)")
                } label: {
                    Label("Listen", systemImage: "play.fill")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Listen to Lesson")
            }
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .padding(.top, 4)
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

// MARK: - Metadata-only state

private struct MetadataOnlyLessonView: View {
    let lessonNumber: Int
    let archive: ArchivedReading

    @Environment(AudioManager.self) private var audio

    private var title: String {
        WorkbookCatalog.title(for: lessonNumber) ?? (archive.text.isEmpty ? "Lesson \(lessonNumber)" : archive.text)
    }

    private var embedURL: String {
        "https://www.youtube.com/embed/videoseries?list=\(YouTubePlaylists.dailyLesson)&index=\(lessonNumber)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let body = WorkbookBodiesCatalog.body(for: lessonNumber) {
                    Text(body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else if lessonNumber > 0 {
                    YouTubePlayerView(videoURL: embedURL)
                        .aspectRatio(16.0/9.0, contentMode: .fit)
                }

                if let audioURL = archive.audioURL, !audioURL.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            audio.play(url: audioURL, title: "Lesson \(lessonNumber)")
                        } label: {
                            Label("Listen", systemImage: "play.fill")
                                .font(.callout.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Listen to Lesson")
                    }
                    .padding(.top, 4)
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

    private var embedURL: String {
        "https://www.youtube.com/embed/videoseries?list=\(YouTubePlaylists.dailyLesson)&index=\(lessonNumber)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if lessonNumber == 0 {
                    if let audioURL = introAudioURL, !audioURL.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                audio.play(url: audioURL, title: "Introduction")
                            } label: {
                                Label("Listen", systemImage: "play.fill")
                                    .font(.callout.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Listen to Introduction")
                        }
                        .padding(.top, 4)
                    }
                } else if let body = WorkbookBodiesCatalog.body(for: lessonNumber) {
                    Text(body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    YouTubePlayerView(videoURL: embedURL)
                        .aspectRatio(16.0/9.0, contentMode: .fit)
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
