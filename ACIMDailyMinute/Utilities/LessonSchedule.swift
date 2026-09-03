import Foundation

/// Maps a workbook lesson number onto the date its recording becomes available.
///
/// The publisher runs the Daily Lessons pipeline once per weekday and takes the
/// next lesson in sequence — there is no holiday calendar and no catch-up on
/// weekends, so lesson *n* lands exactly `n - latestRecorded` weekdays after the
/// most recently recorded lesson. Sundays and Saturdays are skipped, which is why
/// this cannot be a plain day-offset.
enum LessonSchedule {
    /// The calendar every date in this type is reasoned about in.
    ///
    /// Publication dates arrive as bare `yyyy-MM-dd` strings and are parsed at
    /// UTC midnight by `DataService.parseISODate`. Those are calendar days, not
    /// instants — so doing the weekday walk in `Calendar.current` reads
    /// "2026-08-28" as the evening of the 27th anywhere west of Greenwich, and
    /// every date computed from it lands one publishing day early. Pinning the
    /// arithmetic *and* the display formatting to UTC keeps them agreeing with
    /// how the date was parsed in the first place.
    static let publicationCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    /// The publisher's own `yyyy-MM-dd`, in the publication calendar's zone, so
    /// a printed day never slips either side of midnight depending on where
    /// the reader is. One formatter for every surface that names a day this
    /// way — the lesson row, the lesson screen and the Archive — so they
    /// cannot disagree.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = publicationCalendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = publicationCalendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func formatted(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func day(from string: String) -> Date? {
        dayFormatter.date(from: string)
    }

    /// The highest numbered lesson known to be recorded, with the day it was
    /// published — the anchor every availability date is counted from.
    ///
    /// A candidate without a date cannot anchor anything: without a day to
    /// count weekdays from, a guessed date would be worse than none. So a
    /// dateless archive hit is passed over even when its number is higher, and
    /// `nil` means nothing dated has been seen yet.
    static func anchor(from candidates: [(number: Int, date: Date?)]) -> (number: Int, date: Date)? {
        var best: (number: Int, date: Date)?
        for candidate in candidates {
            guard let date = candidate.date, candidate.number > 0 else { continue }
            if let current = best, current.number >= candidate.number { continue }
            best = (candidate.number, date)
        }
        return best
    }

    /// Advances `count` publishing days (Mon–Fri) past `date`.
    ///
    /// `date` itself is never returned for a positive `count`: the walk always
    /// steps at least one calendar day forward, then keeps stepping while it
    /// lands on a weekend. A non-positive `count` returns `date` unchanged.
    static func advancingWeekdays(
        _ count: Int,
        from date: Date,
        calendar: Calendar = publicationCalendar
    ) -> Date {
        guard count > 0 else { return date }

        var result = date
        var remaining = count

        while remaining > 0 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: result) else {
                return result
            }
            result = next
            if !calendar.isDateInWeekend(result) {
                remaining -= 1
            }
        }

        return result
    }

    /// How many publishing days (Mon–Fri) fall after `after` and up to and
    /// including `through`, both read as calendar days in `calendar`. Zero
    /// when `through` is not later than `after`.
    ///
    /// This is how many lessons the publisher has moved on by: the newest
    /// recorded lesson plus this count is the lesson for `through`, and a
    /// weekend adds nothing, so Saturday and Sunday repeat Friday's lesson.
    static func publishingDays(
        after: Date,
        through: Date,
        calendar: Calendar = publicationCalendar
    ) -> Int {
        var cursor = calendar.startOfDay(for: after)
        let last = calendar.startOfDay(for: through)
        var count = 0
        while cursor < last {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            if !calendar.isDateInWeekend(cursor) { count += 1 }
        }
        return count
    }

    /// The date lesson `lessonNumber` becomes available, or `nil` when it has
    /// already been recorded (`lessonNumber <= latestRecorded`).
    ///
    /// Returns `nil` when `latestRecorded` is not a real lesson yet, because
    /// without a recorded anchor there is nothing to count weekdays from and a
    /// guessed date would be worse than no date.
    static func availabilityDate(
        for lessonNumber: Int,
        latestRecorded: Int,
        latestDate: Date,
        calendar: Calendar = publicationCalendar
    ) -> Date? {
        guard latestRecorded > 0, lessonNumber > latestRecorded else { return nil }
        return advancingWeekdays(
            lessonNumber - latestRecorded,
            from: latestDate,
            calendar: calendar
        )
    }
}
