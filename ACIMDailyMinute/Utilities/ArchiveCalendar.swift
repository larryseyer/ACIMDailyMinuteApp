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

    /// Always both: the month chevrons move `visibleMonth` without touching
    /// `selection`, so writing only the day is a no-op whenever the day is
    /// already today — which is how the screen opens.
    mutating func revealToday(now: Date, calendar: Calendar = grid) {
        let today = calendar.startOfDay(for: now)
        selection = today
        visibleMonth = today
    }
}
