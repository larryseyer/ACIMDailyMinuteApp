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
