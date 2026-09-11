import Foundation

/// The Archive calendar's selected day and visible month, as one value so
/// Today can write both. Pure Foundation, no `Date()`: `now` is handed in, so
/// `tools/verify_archive_calendar.sh` can ask the same afternoon twice.
struct ArchiveCalendarState: Equatable {
    var selection: Date
    var visibleMonth: Date

    /// The grid the Archive draws: Gregorian, Sunday-first, in the reader's
    /// zone. Publication keys stay UTC elsewhere; this type answers "which
    /// cell is today on the month the reader is looking at".
    static var grid: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }

    static func starting(now: Date, calendar: Calendar = grid) -> Self {
        let today = calendar.startOfDay(for: now)
        return Self(selection: today, visibleMonth: today)
    }

    /// The grid's `yyyy-MM-dd` for a cell, in that calendar's zone. Matching
    /// recorded days on this string is how the dots already work; selection
    /// uses the same key so a highlighted cell and a recorded cell cannot
    /// disagree about which day they are.
    static func dateString(from date: Date, calendar: Calendar = grid) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// True when `availableDateStrings` names this cell. An empty set is
    /// "nothing recorded", not "everything is selectable".
    static func isRecorded(
        _ date: Date,
        availableDateStrings: Set<String>,
        calendar: Calendar = grid
    ) -> Bool {
        availableDateStrings.contains(dateString(from: date, calendar: calendar))
    }

    /// The day the calendar may highlight.
    ///
    /// Prefers `preferred` when it is recorded. Otherwise the latest recorded
    /// day on or before it. Otherwise the latest recorded day at all. `nil`
    /// when nothing has been recorded — the grid can still draw, but no cell
    /// is a selection the reader can act on.
    static func selection(
        preferring preferred: Date,
        availableDateStrings: Set<String>,
        calendar: Calendar = grid
    ) -> Date? {
        guard !availableDateStrings.isEmpty else { return nil }
        if isRecorded(preferred, availableDateStrings: availableDateStrings, calendar: calendar) {
            return calendar.startOfDay(for: preferred)
        }
        let preferredKey = dateString(from: preferred, calendar: calendar)
        let earlier = availableDateStrings.filter { $0 <= preferredKey }.sorted()
        if let key = earlier.last, let day = parse(key, calendar: calendar) {
            return calendar.startOfDay(for: day)
        }
        let latest = availableDateStrings.sorted().last
        if let key = latest, let day = parse(key, calendar: calendar) {
            return calendar.startOfDay(for: day)
        }
        return nil
    }

    private static func parse(_ string: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    /// Always both: the month chevrons move `visibleMonth` without touching
    /// `selection`, so writing only the day is a no-op whenever the day is
    /// already today — which is how the screen opens.
    ///
    /// When `availableDateStrings` is non-empty, an unpublished today is not
    /// a selection: the latest recorded day is. An empty set keeps today's
    /// cell so a calendar with no feed yet still has a highlight.
    mutating func revealToday(
        now: Date,
        availableDateStrings: Set<String> = [],
        calendar: Calendar = grid
    ) {
        let today = calendar.startOfDay(for: now)
        if let next = Self.selection(
            preferring: today,
            availableDateStrings: availableDateStrings,
            calendar: calendar
        ) {
            selection = next
            visibleMonth = next
            return
        }
        selection = today
        visibleMonth = today
    }
}
