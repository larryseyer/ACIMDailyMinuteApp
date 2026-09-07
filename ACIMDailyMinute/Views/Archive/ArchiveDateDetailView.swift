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

    @Query private var readings: [ArchivedReading]
    #if os(tvOS)
    @State private var playerItem: TVPlayerItem?
    #endif

    init(dateString: String, availability: MinuteSchedule.Availability) {
        self.dateString = dateString
        self.availability = availability
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
                            Button { playerItem = .archived(reading) } label: {
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
        #if os(tvOS)
        .fullScreenCover(item: $playerItem) { item in
            TVPlayerView(item: item)
        }
        #endif
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
    }

    /// `"Thursday, April 10, 2026"` when the `dateString` parses, else the raw
    /// `"YYYY-MM-DD"` (never empty). Parsing matches `DataService.parseISODate`
    /// — UTC, `"yyyy-MM-dd"` — so the formatter stays symmetric with ingestion.
    private var formattedTitle: String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return dateString }

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
