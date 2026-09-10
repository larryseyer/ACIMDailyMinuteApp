import SwiftUI
import SwiftData

/// Renders every `ArchivedReading` row for a single calendar date.
///
/// Landed on via `.navigationDestination(for: String.self)` from `ArchiveView`;
/// the destination value is `dateString` in `"YYYY-MM-DD"` form. The view seeds
/// its own parameterized `@Query` in `init` — same pattern as `LessonDetailView`
/// — so SwiftData updates reach the render path without relying on an upstream
/// fetch.
///
/// Sort: `channel` descending so `"daily-minute"` sorts before `"daily-lesson"`
/// (`m` > `l`), which matches the Today-tab reading order.
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
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(readings) { reading in
                            #if os(tvOS)
                            Button { openPlayer(.archived(reading)) } label: {
                                ArchivedReadingCard(reading: reading)
                            }
                            .buttonStyle(.card)
                            #else
                            ArchivedReadingCard(reading: reading)
                            #endif
                        }
                    }
                    .padding(20)
                    .readableContentWidth()
                }
            }
        }
        .navigationTitle(formattedTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var empty: some View {
        ContentUnavailableView(
            "No reading for this day",
            systemImage: "calendar.badge.exclamationmark",
            description: Text(availability.sentence ?? "Pull to refresh on the Archive tab.")
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

#Preview {
    NavigationStack {
        ArchiveDateDetailView(dateString: "2026-04-10", availability: .unknown)
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [ArchivedReading.self, Bookmark.self], inMemory: true)
}
