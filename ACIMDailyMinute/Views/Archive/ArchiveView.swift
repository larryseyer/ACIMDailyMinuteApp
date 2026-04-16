import SwiftUI
import SwiftData

/// Root of the Archive tab.
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

    @Query(sort: \ArchivedReading.dateString, order: .reverse)
    private var allReadings: [ArchivedReading]

    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var selectedDate: Date = Self.today()
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Archive")
                .searchable(text: $searchText, prompt: "Search the archive")
                .refreshable {
                    if connectivity.isConnected {
                        await refresh()
                    }
                }
                .navigationDestination(for: String.self) { dateString in
                    ArchiveDateDetailView(dateString: dateString)
                }
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") {
                            withAnimation {
                                selectedDate = Self.today()
                            }
                        }
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        Button("Today") {
                            withAnimation {
                                selectedDate = Self.today()
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
    }

    // MARK: - Calendar mode

    private var calendarMode: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                calendar
                    .frame(maxWidth: .infinity)

                selectedDateRow
            }
            .padding(16)
            .readableContentWidth()
        }
    }

    @ViewBuilder
    private var calendar: some View {
        #if os(iOS)
        DatePicker(
            "",
            selection: $selectedDate,
            in: earliestDate...Self.today(),
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        #else
        MacCalendarView(selection: $selectedDate)
        #endif
    }

    private var selectedDateRow: some View {
        let dateString = Self.dateString(from: selectedDate)
        let hasRows = allReadings.contains { $0.dateString == dateString }

        return Button {
            path.append(dateString)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.longDateString(from: selectedDate))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(hasRows ? "Open readings" : "No readings archived on this date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(white: 0.11).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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

        FetchCooldown.reset(FetchCooldownKey.dailyMinute, FetchCooldownKey.dailyLesson)
        let service = DataService(modelContainer: modelContext.container)
        do {
            async let minuteDTO = service.fetchDailyMinute()
            async let lessonDTO = service.fetchDailyLesson()
            let (m, l) = try await (minuteDTO, lessonDTO)
            if let m { try DataService.persistMinute(m, in: modelContext) }
            if let l { try DataService.persistLesson(l, in: modelContext) }
        } catch {
            // Offline or transient error — fall through silently; cached rows
            // remain visible. No separate error UX in this phase (matches the
            // Today-tab behavior).
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
            : "Lesson \(reading.lessonNumber ?? 0)"
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
