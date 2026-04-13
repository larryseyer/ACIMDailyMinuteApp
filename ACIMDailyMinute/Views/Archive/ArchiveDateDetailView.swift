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

    @Query private var readings: [ArchivedReading]

    init(dateString: String) {
        self.dateString = dateString
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
                            ArchivedReadingCard(reading: reading)
                        }
                    }
                    .padding(16)
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
            "No readings for this date",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Nothing was archived on \(dateString). Pull to refresh on the Archive tab to top up today's feeds.")
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
        ArchiveDateDetailView(dateString: "2026-04-10")
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [ArchivedReading.self, Bookmark.self], inMemory: true)
}
