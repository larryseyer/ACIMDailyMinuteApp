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

    @Environment(\.modelContext) private var modelContext
    @Query private var lessonMatches: [DailyLesson]
    @Query private var archiveMatches: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    /// A lesson bookmark is keyed by number alone, so saving does not depend on
    /// which of the three states rendered. It used to live inside
    /// `FullLessonView`, which meant a lesson with no published body — most of
    /// them, while `Workbook365Bodies.json` is still a placeholder — had no way
    /// to be saved at all, even though the Lessons list would happily show a
    /// bookmark indicator for one.
    private var itemKey: String { "lesson:\(lessonNumber)" }

    private var isBookmarked: Bool {
        bookmarks.contains(where: { $0.itemKey == itemKey })
    }

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
                FullLessonView(lesson: lesson)
            } else if let archive = archiveMatches.first {
                MetadataOnlyLessonView(lessonNumber: lessonNumber, archive: archive)
            } else {
                AbsentLessonView(lessonNumber: lessonNumber)
            }
        }
        .navigationTitle("Lesson \(lessonNumber)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingVideo) {
            if let videoURL = lessonVideoURL {
                FullScreenVideoCover(videoURL: videoURL)
            }
        }
        .onAppear {
            guard !hasAutoPresentedVideo, lessonVideoURL != nil else { return }
            hasAutoPresentedVideo = true
            isShowingVideo = true
        }
        #endif
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




// MARK: - Full state

private struct FullLessonView: View {
    let lesson: DailyLesson

    @Environment(AudioManager.self) private var audio

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
}

// MARK: - Metadata-only state

private struct MetadataOnlyLessonView: View {
    let lessonNumber: Int
    let archive: ArchivedReading

    @Environment(AudioManager.self) private var audio

    private var title: String {
        WorkbookCatalog.title(for: lessonNumber) ?? (archive.text.isEmpty ? "Lesson \(lessonNumber)" : archive.text)
    }

    private var embedURL: String? {
        guard let videoID = archive.youtubeID, !videoID.isEmpty else { return nil }
        return "https://www.youtube.com/embed/\(videoID)"
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
                } else if lessonNumber > 0, let embedURL {
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
