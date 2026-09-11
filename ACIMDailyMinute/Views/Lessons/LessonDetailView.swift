import SwiftUI
import SwiftData

/// Detail screen for a single workbook lesson (1–365), landed on via
/// `.navigationDestination(for: Int.self)` declared in `CourseView`.
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

    @Environment(\.modelContext) private var modelContext
    @Query private var lessonMatches: [DailyLesson]
    @Query private var archiveMatches: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    /// Everything recorded, for the anchor `LessonSchedule` counts weekdays
    /// from — the same candidates `CourseWorkbookSpine` hands it, so the date this
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

    init(lessonNumber: Int, spotlight: ReadingSpotlight? = nil, presentsVideo: Bool = false) {
        self.lessonNumber = lessonNumber
        self.spotlight = spotlight
        // Watch is a tap on the medium band. The flag is kept so existing
        // LessonRef call sites still compile.
        _ = presentsVideo
        _lessonMatches = Query(
            filter: #Predicate<DailyLesson> { $0.lessonNumber == lessonNumber }
        )
        _archiveMatches = Query(
            filter: #Predicate<ArchivedReading> {
                $0.channel == "daily-lesson" && $0.lessonNumber == lessonNumber
            }
        )
    }

    @AppStorage(WorkbookCompletion.defaultsKey) private var completedLessonsData: Data = Data()

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
        // The nav bar names the BOOK; the running head names the place.
        // Saying "Lesson 84" in both put the same phrase twice within 40 points.
        .navigationTitle("Workbook")
        #if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    WorkbookCompletion.toggle(lessonNumber)
                } label: {
                    Image(systemName: WorkbookCompletion.isDone(lessonNumber, in: WorkbookCompletion.entries)
                          ? "checkmark.circle.fill"
                          : "circle")
                }
                .accessibilityLabel(
                    WorkbookCompletion.isDone(lessonNumber, in: WorkbookCompletion.entries)
                    ? "Mark lesson as not done"
                    : "Mark lesson as done"
                )
            }
        }
        #endif
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleBookmark() {
        BookmarkStore.toggle(key: itemKey, channel: "daily-lesson", in: modelContext)
    }
}




private func lessonParent(_ number: Int) -> String {
    WorkbookBodiesCatalog.reviewTitle(for: number) ?? "Workbook"
}

private func lessonCitation(_ number: Int) -> String? {
    CitationResolver.stem(for: .lesson(number))
}

private struct LessonTitleBlock: View {
    let number: Int
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(number == 0 ? "Introduction" : "Lesson \(number)")
                .font(.acimDisplayTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !line.isEmpty {
                Text(line)
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)
    }
}

// MARK: - Full state

private struct FullLessonView: View {
    let lesson: DailyLesson
    var spotlight: ReadingSpotlight? = nil
    let isBookmarked: Bool
    let toggleBookmark: () -> Void

    var body: some View {
        ScrollView {
            ReadingScaffold(
                parent: lessonParent(lesson.lessonNumber),
                citation: lessonCitation(lesson.lessonNumber),
                footer: ReadingFooter(measure: ReadingTime.describe(wordCount: lesson.wordCount))
            ) {
            } trailing: {
            } titleBlock: {
                LessonTitleBlock(number: lesson.lessonNumber, line: lesson.lessonTitle)
            } body: {
                AnnotatableReadingText(
                    raw: lesson.text,
                    key: .lesson(lesson.lessonNumber),
                    design: .serif,
                    lineSpacing: Metric.readingPushedGap,
                    basePointSize: 18,
                    spotlight: spotlight,
                    recordsPosition: true
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Metric.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableContentWidth()
        }
        .readingMediumBand(
            title: "Lesson \(lesson.lessonNumber)",
            lessonNumber: lesson.lessonNumber,
            surfaceAudioURL: lesson.audioURL,
            surfaceYouTubeID: lesson.youtubeID,
            composeItem: .lesson(lesson),
            artworkText: lesson.text,
            shareText: ShareTextBuilder.lessonShareText(lesson)
        )
        #if !os(tvOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareButton(text: ShareTextBuilder.lessonShareText(lesson))
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #endif
    }
}

// MARK: - Metadata-only state

private struct MetadataOnlyLessonView: View {
    let lessonNumber: Int
    let archive: ArchivedReading
    var spotlight: ReadingSpotlight? = nil
    let isBookmarked: Bool
    let toggleBookmark: () -> Void

    private var title: String {
        WorkbookCatalog.title(for: lessonNumber) ?? (archive.text.isEmpty ? "Lesson \(lessonNumber)" : archive.text)
    }

    /// The bundled body, when there is one. A lesson the feed has not published
    /// still has all 365 bodies behind it.
    private var bundledBody: String? {
        WorkbookBodiesCatalog.body(for: lessonNumber)
    }

    var body: some View {
        ScrollView {
            ReadingScaffold(
                parent: lessonParent(lessonNumber),
                citation: lessonCitation(lessonNumber),
                footer: ReadingFooter(
                    measure: bundledBody.flatMap {
                        ReadingTime.describe(wordCount: ReadingTime.wordCount(of: $0))
                    }
                )
            ) {
            } trailing: {
            } titleBlock: {
                LessonTitleBlock(number: lessonNumber, line: title)
            } body: {
                if let bundledBody {
                    AnnotatableReadingText(
                        raw: bundledBody,
                        key: .lesson(lessonNumber),
                        design: .serif,
                        lineSpacing: Metric.readingPushedGap,
                        basePointSize: 18,
                        spotlight: spotlight,
                        recordsPosition: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Metric.gutter)
            .readableContentWidth()
        }
        .readingMediumBand(
            title: "Lesson \(lessonNumber)",
            lessonNumber: lessonNumber,
            surfaceAudioURL: archive.audioURL,
            surfaceYouTubeID: archive.youtubeID,
            composeItem: .archived(archive),
            artworkText: bundledBody ?? archive.text
        )
        #if !os(tvOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #endif
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
                parent: lessonParent(lessonNumber),
                citation: lessonCitation(lessonNumber),
                footer: ReadingFooter(
                    measure: bundledBody.flatMap {
                        ReadingTime.describe(wordCount: ReadingTime.wordCount(of: $0))
                    }
                )
            ) {
            } trailing: {
            } titleBlock: {
                LessonTitleBlock(number: lessonNumber, line: title)
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
                        .background(Color.acimRaised, in: RoundedRectangle(cornerRadius: Metric.card))
                    }
                    if let bundledBody {
                        AnnotatableReadingText(
                            raw: bundledBody,
                            key: .lesson(lessonNumber),
                            design: .serif,
                            lineSpacing: Metric.readingPushedGap,
                            basePointSize: 18,
                            spotlight: spotlight,
                            recordsPosition: true
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Metric.gutter)
            .readableContentWidth()
        }
        .readingMediumBand(
            title: lessonNumber == 0 ? "Introduction" : "Lesson \(lessonNumber)",
            lessonNumber: lessonNumber,
            surfaceAudioURL: lessonNumber == 0 ? introAudioURL : nil,
            composeItem: .workbookLesson(lessonNumber, audioURL: lessonNumber == 0 ? introAudioURL : nil)
        )
        #if !os(tvOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SaveButton(isSaved: isBookmarked, action: toggleBookmark)
            }
        }
        #endif
    }
}
