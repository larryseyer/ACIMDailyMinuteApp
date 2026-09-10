import Foundation

/// When the Daily Minute for a given day will exist.
///
/// The publisher's rule, as the feed shows it: the minute for a day is
/// published on that day by the 02:00 run, and a day the run missed is filled
/// in afterwards by the same run — **one missed day per night, oldest first**.
/// So a future day is available on itself, and a past day with no reading is
/// available a known number of nights from now: its place in the line of
/// missed days.
///
/// Pure Foundation, no `Date()`: `today` is handed in, so
/// `tools/verify_schedules.sh` can ask the same question on the same day twice.
enum MinuteSchedule {
    enum Availability: Equatable {
        /// The day has a reading.
        case archived
        /// A day that has not come yet, or today before the run — the reading
        /// arrives on that day.
        case publishesOn(Date)
        /// A past day the run missed; the nightly catch-up reaches it on this
        /// date.
        case expectedOn(Date)
        /// A day before the first one ever published.
        case beforeTheArchive(Date)
        /// Nothing has been archived at all, so nothing can be said.
        case unknown

        /// What the reader is told. `nil` when there is a reading to show
        /// instead.
        var sentence: String? {
            switch self {
            case .archived:
                return nil
            case .publishesOn(let day):
                return "The Daily Minute for this day will be available on \(LessonSchedule.formatted(day))."
            case .expectedOn(let day):
                return "No reading was published on this day. Missed days are filled in one a night; "
                    + "expect this one on \(LessonSchedule.formatted(day))."
            case .beforeTheArchive(let first):
                return "The Daily Minute began on \(LessonSchedule.formatted(first)). There is nothing before it."
            case .unknown:
                return "No readings archived on this date."
            }
        }
    }

    /// `archived` holds every day that has a reading, as the feed's own
    /// `yyyy-MM-dd`. Matching on the string rather than on instants keeps this
    /// clear of every start-of-day trap; the walk below is done in the
    /// publisher's calendar, UTC, the same one those strings were parsed in.
    static func availability(
        of date: Date,
        archived: Set<String>,
        today: Date,
        calendar: Calendar = LessonSchedule.publicationCalendar
    ) -> Availability {
        let day = calendar.startOfDay(for: date)
        let todayDay = calendar.startOfDay(for: today)

        if archived.contains(LessonSchedule.formatted(day)) { return .archived }
        if day >= todayDay { return .publishesOn(day) }

        let archivedDays = archived.compactMap { LessonSchedule.day(from: $0) }.map { calendar.startOfDay(for: $0) }
        guard let first = archivedDays.min() else { return .unknown }
        guard day >= first else { return .beforeTheArchive(first) }

        // This day's place in the line of missed days, counted from the first
        // published day up to yesterday. The run clears one per night, so the
        // oldest missed day lands tomorrow and this one `rank` nights from now.
        var rank = 0
        var cursor = first
        while cursor < todayDay {
            if !archived.contains(LessonSchedule.formatted(cursor)) {
                rank += 1
                if cursor == day { break }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        let expected = calendar.date(byAdding: .day, value: rank, to: todayDay) ?? todayDay
        return .expectedOn(expected)
    }

    /// The nearest archived days strictly before `date`, newest first.
    ///
    /// An empty Archive cell used to open onto a sentence and nowhere to go.
    /// The days that do hold a reading are almost always one or two cells
    /// away; this names them so the empty day can list them. Matching on the
    /// feed's own `yyyy-MM-dd` strings, not on instants, keeps it clear of
    /// every start-of-day trap the availability walk already documents.
    static func nearestArchivedDays(
        before date: Date,
        archived: Set<String>,
        count: Int = 3
    ) -> [String] {
        guard count > 0 else { return [] }
        let key = LessonSchedule.formatted(date)
        return archived
            .filter { !$0.isEmpty && $0 < key }
            .sorted(by: >)
            .prefix(count)
            .map { $0 }
    }
}

/// A physical book falling open: a published Daily Minute, or a bundled
/// passage when none have been fetched yet.
enum FallOpen {
    enum Opening: Equatable {
        case publishedMinute(dateString: String)
        case bundledSegment(id: Int)
    }

    static func opening(
        publishedDates: [String],
        segmentIDs: [Int],
        pickIndex: (Int) -> Int
    ) -> Opening? {
        let dates = publishedDates.filter { !$0.isEmpty }
        if !dates.isEmpty {
            let index = pickIndex(dates.count)
            guard dates.indices.contains(index) else { return nil }
            return .publishedMinute(dateString: dates[index])
        }
        if !segmentIDs.isEmpty {
            let index = pickIndex(segmentIDs.count)
            guard segmentIDs.indices.contains(index) else { return nil }
            return .bundledSegment(id: segmentIDs[index])
        }
        return nil
    }
}
