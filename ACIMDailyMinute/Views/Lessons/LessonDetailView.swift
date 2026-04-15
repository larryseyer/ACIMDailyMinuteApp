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
/// 3. **Absent** — neither row exists. Offer a Refresh button that fetches
///    today's lesson; only populates this entry when `lessonNumber` *is* today.
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
        #endif
    }
}

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
                Text(lesson.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                wordCountChip
                actionRow
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        archive.text.isEmpty ? "Lesson \(lessonNumber)" : archive.text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Lesson \(lessonNumber)")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !archive.dateString.isEmpty {
                        Text(archive.dateString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Full text available once today's lesson fetches this entry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)

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
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Absent state

private struct AbsentLessonView: View {
    let lessonNumber: Int

    @Environment(\.modelContext) private var modelContext
    @State private var isRefreshing = false
    @State private var refreshError: String?

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Lesson \(lessonNumber) not yet cached",
                systemImage: "book.closed",
                description: Text("Open this lesson when it's the Daily Lesson, or tap Refresh to pull the latest entry.")
            )

            Button {
                refresh()
            } label: {
                if isRefreshing {
                    ProgressView()
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)

            if let refreshError {
                Text(refreshError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(20)
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshError = nil
        let container = modelContext.container
        let lessonNumber = self.lessonNumber

        Task { @MainActor in
            defer { isRefreshing = false }
            do {
                let service = DataService(modelContainer: container)
                guard let dto = try await service.fetchDailyLesson() else {
                    refreshError = "Refresh is cooling down. Try again in a moment."
                    return
                }
                try DataService.persistLesson(dto, in: modelContext)
                if dto.lesson_id != lessonNumber {
                    refreshError = "Today's lesson is \(dto.lesson_id). Lesson \(lessonNumber) isn't available yet."
                }
            } catch {
                refreshError = "Could not refresh: \(error.localizedDescription)"
            }
        }
    }
}
