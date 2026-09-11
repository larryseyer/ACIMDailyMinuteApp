import SwiftUI
import SwiftData

/// Root of the Video tab.
///
/// Two top-level modes, switched by the `.searchable` query:
///   * **Calendar mode** (empty query) — graphical `DatePicker` on iOS /
///     `MacCalendarView` on macOS, plus a tappable row that pushes the selected
///     date's `ArchiveDateDetailView`.
///   * **Search mode** (non-empty query) — `ArchiveSearchResultsList` filters
///     every `ArchivedReading` in memory; tapping a result pushes the same
///     detail view for that row's `dateString`.
///
/// Pull-to-refresh in both modes resets the daily-Minute and daily-Lesson
/// cooldowns and re-fetches, which tops up the inline archive as a side
/// effect (the provider embeds the rolling archive inside each daily JSON
/// payload; `ArchiveService` has no standalone page endpoint).
///
/// Search uses `localizedStandardContains` on `ArchivedReading.searchableText`
/// — a denormalized `String` column populated at persist time. Not FTS5;
/// SwiftData doesn't expose SQLite virtual tables. Archive size is bounded
/// (rolling window × channels × months), so in-memory filtering is adequate
/// and matches the pattern used elsewhere in the app.
struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectivityManager.self) private var connectivity
    @Environment(AudioManager.self) private var audio

    @Query(sort: \ArchivedReading.dateString, order: .reverse)
    private var allReadings: [ArchivedReading]

    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var archiveCalendar = ArchiveCalendarState.starting(now: Date())
    @State private var isRefreshing = false
    #if os(tvOS)
    @Environment(\.openPlayer) private var openPlayer
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            content
                // ⛔ The mini player floats over this screen, so the last row
                // owes it room. Thirteen surfaces reserved it and this one did
                // not, which covered the bottom entry whenever audio was playing.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
                }
                .navigationTitle("Video")
                #if !os(tvOS)
                // Same as the Read tab: on tvOS `.searchable` takes over the
                // screen rather than waiting to be opened.
                .searchable(text: $searchText, prompt: "Search past readings")
                #endif
                #if !os(tvOS)
                .refreshable {
                    if connectivity.isConnected {
                        await refresh()
                    }
                }
                .task {
                    await refreshPodcasts(force: false)
                }
                #endif
                .navigationDestination(for: String.self) { dateString in
                    ArchiveDateDetailView(
                        dateString: dateString,
                        availability: availability(of: dateString),
                        archived: datesWithReadings
                    )
                }
                .navigationDestination(for: SegmentReadingRef.self) { ref in
                    SegmentReadingView(segmentId: ref.segmentId, spotlight: ref.spotlight)
                }
                .readingDestinations(path: $path)
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") {
                            withAnimation {
                                archiveCalendar.revealToday(now: Date())
                            }
                        }
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        Button("Today") {
                            withAnimation {
                                archiveCalendar.revealToday(now: Date())
                            }
                        }
                    }
                    #endif
                }
                .onReceive(NotificationCenter.default.publisher(for: .deepLinkArchive)) { note in
                    guard let date = note.object as? Date else { return }
                    path.append(Self.dateString(from: date))
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if allReadings.isEmpty {
            emptyArchive
        } else if trimmed.isEmpty {
            calendarMode
        } else {
            ArchiveSearchResultsList(
                query: trimmed,
                readings: allReadings,
                path: $path
            )
        }
    }

    // MARK: - Empty (no rows at all)

    private var emptyArchive: some View {
        ContentUnavailableView(
            "No archive yet",
            systemImage: "archivebox",
            description: Text("The archive builds up as you open the app each day. Pull to refresh to top it up.")
        )
        .safeAreaInset(edge: .bottom) {
            fallOpenRow
                .padding(20)
                .readableContentWidth()
        }
    }

    // MARK: - Calendar mode

    private var calendarMode: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                calendar
                    .frame(maxWidth: .infinity)

                selectedDateRow
                fallOpenRow
            }
            .padding(20)
            .readableContentWidth()
        }
    }

    private var calendar: some View {
        ArchiveCalendarView(
            selection: $archiveCalendar.selection,
            visibleMonth: $archiveCalendar.visibleMonth,
            availableDateStrings: datesWithReadings
        )
    }

    /// Every date that has at least one archived reading, as `yyyy-MM-dd`.
    private var datesWithReadings: Set<String> {
        Set(allReadings.map(\.dateString).filter { !$0.isEmpty })
    }

    /// When the reading for a day exists or will. A day with no rows is told
    /// when, not just that — the same sentence `ArchiveDateDetailView` shows
    /// once the reader taps through.
    private func availability(of dateString: String) -> MinuteSchedule.Availability {
        guard let day = LessonSchedule.day(from: dateString) else { return .unknown }
        return MinuteSchedule.availability(of: day, archived: datesWithReadings, today: Self.today())
    }

    private var selectedDateRow: some View {
        let dateString = Self.dateString(from: archiveCalendar.selection)
        let sentence = availability(of: dateString).sentence

        return Button {
            path.append(dateString)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.longDateString(from: archiveCalendar.selection))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(sentence ?? {
                        #if os(tvOS)
                        "Open readings"
                        #else
                        "Open video"
                        #endif
                    }())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.acimCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// A physical book falling open: a published Daily Minute if any have
    /// been fetched, otherwise a bundled Text passage so the gesture still
    /// has a page.
    private var fallOpenRow: some View {
        Button(action: fallOpen) {
            HStack {
                Text("Let it fall open")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "book")
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

    private var publishedMinuteDates: [String] {
        var seen = Set<String>()
        var dates: [String] = []
        for reading in allReadings where reading.channel == "daily-minute" {
            let key = reading.dateString
            if !key.isEmpty, seen.insert(key).inserted {
                dates.append(key)
            }
        }
        return dates
    }

    private var textSegmentIDs: [Int] {
        CorpusService.shared.allSegmentIDs.filter {
            CorpusService.shared.segment(id: $0)?.bookName == "Text"
        }
    }

    private func fallOpen() {
        let opening = FallOpen.opening(
            publishedDates: publishedMinuteDates,
            segmentIDs: textSegmentIDs,
            pickIndex: { Int.random(in: 0..<$0) }
        )
        switch opening {
        case .publishedMinute(let dateString):
            #if os(tvOS)
            if let reading = allReadings.first(where: {
                $0.dateString == dateString && $0.channel == "daily-minute"
            }) {
                openPlayer(.archived(reading))
                return
            }
            #endif
            path.append(dateString)
        case .bundledSegment(let id):
            #if os(tvOS)
            if let segment = CorpusService.shared.segment(id: id) {
                openPlayer(.segment(segment))
            }
            #else
            path.append(SegmentReadingRef(segmentId: id))
            #endif
        case nil:
            break
        }
    }

    // MARK: - Earliest-date bound

    /// Lower bound for the iOS DatePicker. Falls back to "one year ago" so the
    /// picker is never empty or inverted (`earliest > today`) on first install.
    private var earliestDate: Date {
        let parser = Self.dateParser
        let candidate = allReadings
            .compactMap { $0.timestamp ?? parser.date(from: $0.dateString) }
            .min()

        let fallback = Calendar(identifier: .gregorian)
            .date(byAdding: .year, value: -1, to: Self.today()) ?? Self.today()

        guard let candidate else { return fallback }
        return min(candidate, Self.today())
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Only reachable from `.refreshable`, so the user is explicitly asking
        // for fresh data: always force past the cooldown and the HTTP cache.
        let service = DataService(modelContainer: modelContext.container)
        do {
            async let minuteDTO = service.fetchDailyMinute(force: true)
            async let lessonDTO = service.fetchDailyLesson(force: true)
            let (m, l) = try await (minuteDTO, lessonDTO)
            if let m { try DataService.persistMinute(m, in: modelContext) }
            if let l { try DataService.persistLesson(l, in: modelContext) }
        } catch {
            // Offline or transient error — fall through silently; cached rows
            // remain visible. No separate error UX in this phase (matches the
            // Today-tab behavior).
        }
        await refreshPodcasts(force: true)
    }

    /// Historical Daily Minute JSON has no `youtube_id`. The podcast feed's
    /// `<link>` does. The Video tab plays those, so it cannot wait for the
    /// Listen tab to have been opened first.
    private func refreshPodcasts(force: Bool) async {
        let service = PodcastService()
        do {
            async let minutes = service.fetchMinuteEpisodes(force: force)
            async let lessons = service.fetchLessonEpisodes(force: force)
            let (m, l) = try await (minutes, lessons)
            try PodcastService.persist(m, channel: "minute", in: modelContext)
            try PodcastService.persist(l, channel: "lesson", in: modelContext)
        } catch {
            // Cached episodes, if any, still resolve a video.
        }
    }

    // MARK: - Date helpers

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    /// Midnight-UTC Date for today, matching ingestion timezone (see
    /// `DataService.parseISODate`).
    static func today() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.startOfDay(for: Date())
    }

    /// `Date → "yyyy-MM-dd"` in UTC, symmetric with `DataService.parseISODate`.
    static func dateString(from date: Date) -> String {
        dateParser.string(from: date)
    }

    /// `Date → "Thursday, April 10, 2026"` in the user's locale.
    static func longDateString(from date: Date) -> String {
        longFormatter.string(from: date)
    }
}

// MARK: - Search results

/// In-memory filter + sort over the archive, extracted out of `ArchiveView`
/// so `@Query` re-evaluation stays independent of `searchText` keystrokes.
/// Mirrors the pattern used by `FilteredLessonsList` in the Lessons tab.
private struct ArchiveSearchResultsList: View {
    let query: String
    let readings: [ArchivedReading]
    @Binding var path: NavigationPath

    var body: some View {
        let results = filtered()

        Group {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(results) { reading in
                        Button {
                            path.append(reading.dateString)
                        } label: {
                            row(for: reading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .readableContentWidth()
            }
        }
    }

    /// Filter contract (locked for Phase 3.7):
    ///   * Trimmed query matching `^\d{4}-\d{2}-\d{2}$` → exact `dateString` match.
    ///   * Otherwise → `searchableText.localizedStandardContains(query)`.
    /// Sort: `dateString` DESC (already pre-sorted by `@Query`), then `channel`
    /// DESC inside a date so `"daily-minute"` appears before `"daily-lesson"`.
    private func filtered() -> [ArchivedReading] {
        let matches: [ArchivedReading]
        if isIsoDate(query) {
            matches = readings.filter { $0.dateString == query }
        } else {
            matches = readings.filter {
                $0.searchableText.localizedStandardContains(query)
            }
        }

        return matches.sorted { lhs, rhs in
            if lhs.dateString != rhs.dateString {
                return lhs.dateString > rhs.dateString
            }
            return lhs.channel > rhs.channel
        }
    }

    private func isIsoDate(_ s: String) -> Bool {
        guard s.count == 10 else { return false }
        let parts = s.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 else {
            return false
        }
        return parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    @ViewBuilder
    private func row(for reading: ArchivedReading) -> some View {
        let label = reading.channel == "daily-minute"
            ? "Daily Minute"
            : (reading.lessonNumber.flatMap { $0 > 0 ? "Lesson \($0)" : nil } ?? "Lesson")
        let snippet = snippet(for: reading)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(reading.dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(snippet)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }

    /// First ~120 chars of whichever field reads best: `text` for minutes,
    /// the title (`text`) for lessons. Collapses internal whitespace so
    /// multi-line passages render cleanly as a snippet.
    private func snippet(for reading: ArchivedReading) -> String {
        let collapsed = reading.text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 120 else { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 120)
        return trimmed[..<idx] + "…"
    }
}

#Preview {
    ArchiveView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [ArchivedReading.self, Bookmark.self], inMemory: true)
}
