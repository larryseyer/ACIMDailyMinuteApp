import SwiftUI
import SwiftData

/// A calendar day on the Course Minute spine.
///
/// Distinct from a bare `String` on purpose: Saved still routes
/// `yyyy-MM-dd` to `ArchiveDateDetailView`, and Course already routes
/// `Int` to a lesson.
struct MinuteDateRef: Hashable {
    let dateString: String
}

/// One day's Daily Minute, read.
///
/// `DailyMinuteCard` when this date is a stored minute from the feed;
/// `ArchivedReadingCard` for a past day the archive still holds. Never
/// a YouTube card — watching is the reading's job, not this spine's.
struct MinuteReadingView: View {
    let dateString: String
    let availability: MinuteSchedule.Availability
    let archived: Set<String>

    @Query private var minutes: [DailyMinute]
    @Query private var readings: [ArchivedReading]

    init(
        dateString: String,
        availability: MinuteSchedule.Availability,
        archived: Set<String> = []
    ) {
        self.dateString = dateString
        self.availability = availability
        self.archived = archived
        _minutes = Query(
            filter: #Predicate<DailyMinute> { $0.date == dateString }
        )
        _readings = Query(
            filter: #Predicate<ArchivedReading> {
                $0.dateString == dateString && $0.channel == "daily-minute"
            }
        )
    }

    var body: some View {
        Group {
            if let minute = minutes.first {
                readingScroll {
                    DailyMinuteCard(minute: minute)
                }
            } else if let reading = readings.first {
                readingScroll {
                    ArchivedReadingCard(reading: reading)
                }
            } else {
                empty
            }
        }
        .navigationTitle(formattedTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func readingScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .readableContentWidth()
        }
    }

    private var empty: some View {
        ContentUnavailableView(
            "No reading for this day",
            systemImage: "calendar.badge.exclamationmark",
            description: Text(availability.sentence ?? "No Daily Minute for this day.")
        )
        .safeAreaInset(edge: .bottom) {
            if !nearbyDates.isEmpty {
                nearbyList
            }
        }
    }

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
                NavigationLink(value: MinuteDateRef(dateString: neighbor)) {
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
