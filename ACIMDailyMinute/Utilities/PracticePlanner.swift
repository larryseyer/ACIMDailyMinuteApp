import Foundation

/// One lesson's practice cadence, as the Workbook states it.
///
/// Decoded from `Resources/WorkbookPractice.json`, which was authored from
/// every lesson's own instructions (or the review introduction that holds
/// them) and carries the sentence each record rests on. `clock` is the
/// text's cadence, literally — a lesson that asks for every ten minutes says
/// `tenMinutes` here, and it is the planner, not the data, that decides how
/// often a phone should actually buzz.
struct PracticeRecord: Codable, Equatable, Sendable {
    struct Session: Codable, Equatable, Sendable {
        enum Moment: String, Codable, Sendable {
            case wake, morning, midday, evening, sleep, any
        }
        let at: Moment
        /// 0 means the text says "as long as you can", or gives no length.
        let minutes: Int
    }

    enum Clock: String, Codable, Sendable {
        case none, hour, halfHour, quarterHour, tenMinutes
    }

    let lesson: Int
    /// The longer practice periods, one entry each.
    let sessions: [Session]
    /// Short practices per day, when the text counts them per day.
    let shortPerDay: Int
    /// Short practices per hour, when the text gives a rate instead.
    let shortPerHour: Int
    let shortMinutes: Int
    let clock: Clock
    let clockMinutes: Int
    /// The lesson also says to use the idea in between — whenever tempted,
    /// as often as possible. Copy, never a slot.
    let throughout: Bool
    let source: String
    let evidence: String
}

/// A wall-clock time, minute resolution.
struct TimeOfDay: Equatable, Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.init(minutesFromMidnight: hour * 60 + minute)
    }

    /// Clamped to the day: nothing before 00:00, nothing after 23:59.
    init(minutesFromMidnight raw: Int) {
        let clamped = min(max(raw, 0), 23 * 60 + 59)
        hour = clamped / 60
        minute = clamped % 60
    }

    var minutesFromMidnight: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }
}

/// The reader's waking hours: the morning session sits at `start`, the
/// evening session at `end`, and every hourly stop falls strictly between.
struct PracticeWindow: Equatable, Sendable {
    let start: TimeOfDay
    let end: TimeOfDay

    /// A window shorter than an hour, or one that ends before it starts,
    /// cannot hold an hourly stop. The sessions are still planned.
    var isUsable: Bool {
        end.minutesFromMidnight - start.minutesFromMidnight >= 60
    }
}

/// Which lesson the reader is on, on any given day.
enum LessonTrack: Equatable, Sendable {
    /// The publisher's sequence: one lesson per weekday, counted from the
    /// newest recorded lesson and the day it was published. Saturday and
    /// Sunday repeat Friday's lesson, because the publisher does.
    case published(latestRecorded: Int, recordedOn: Date)
    /// The reader's own sequence: they said "I am on lesson N" on a day, and
    /// it advances by one every calendar day from there.
    case own(startLesson: Int, startDay: Date)

    /// Never below 1 and never past 365 — the Workbook ends, and a reader
    /// who reaches the end stays there rather than being sent nowhere.
    func lesson(on day: Date, calendar: Calendar) -> Int {
        let number: Int
        switch self {
        case .published(let latestRecorded, let recordedOn):
            number = latestRecorded + LessonSchedule.publishingDays(
                after: recordedOn, through: day, calendar: calendar
            )
        case .own(let startLesson, let startDay):
            let elapsed = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: startDay),
                to: calendar.startOfDay(for: day)
            ).day ?? 0
            number = startLesson + max(elapsed, 0)
        }
        return min(max(number, 1), 365)
    }
}

/// Lays the practice reminders out ahead of time.
///
/// Pure: everything it needs arrives in `Input`, and what comes back is a
/// list of dated reminders the notification layer adds one for one.
/// `tools/verify_practice_reminders.sh` compiles this file with
/// `LessonSchedule.swift` and nothing else, so nothing about the horizon,
/// the budget, the drop order or the day-to-lesson arithmetic may move
/// into the `UN*` code.
///
/// ⛔ **No reminder is ever planned more often than every half hour.**
/// Lessons 27, 40, 75 and 122 ask for every ten to twenty minutes; as
/// notifications that would be a nag and would spend the phone's whole
/// budget of pending requests in two hours. Those lessons get the half-hour
/// mark, and its words carry the text's own cadence.
enum PracticePlanner {
    struct Input: Sendable {
        var records: [Int: PracticeRecord]
        var titles: [Int: String]
        var window: PracticeWindow
        var track: LessonTrack
        var now: Date
        var calendar: Calendar
        var horizonDays: Int = PracticePlanner.defaultHorizonDays
        var budget: Int = PracticePlanner.defaultBudget

        init(
            records: [Int: PracticeRecord],
            titles: [Int: String],
            window: PracticeWindow,
            track: LessonTrack,
            now: Date,
            calendar: Calendar,
            horizonDays: Int = PracticePlanner.defaultHorizonDays,
            budget: Int = PracticePlanner.defaultBudget
        ) {
            self.records = records
            self.titles = titles
            self.window = window
            self.track = track
            self.now = now
            self.calendar = calendar
            self.horizonDays = horizonDays
            self.budget = budget
        }
    }

    enum Kind: String, Sendable {
        case session, hour, halfHour, short
    }

    struct Reminder: Equatable, Sendable {
        let fireDate: Date
        let identifier: String
        let title: String
        let body: String
        let kind: Kind
        let dayOffset: Int
        let lesson: Int
    }

    /// Every practice reminder's identifier starts with this, and nothing
    /// else's does, so the notification layer can replace exactly these.
    static let identifierPrefix = "acim.practice."

    /// Today and two more. Two days is the longest an ordinary weekend away
    /// from the app lasts, and three days of hourly reminders fit the budget.
    static let defaultHorizonDays = 3

    /// iOS keeps 64 pending requests per app and drops the oldest silently
    /// beyond that. Two repeating daily reminders and the test notification
    /// live alongside these, and a little room is left over.
    static let defaultBudget = 56

    /// Appended to the last reminder in a plan, because after it the app has
    /// to be opened for the reminders to continue.
    static let closingLine = "Open the app to keep these reminders going."

    /// A short practice or an hourly stop this close to a longer session is
    /// the session, and is dropped.
    private static let crowdingMinutes = 10

    // MARK: - The plan

    /// The reminders for the horizon, earliest first, never more than
    /// `budget`, every one after `now`.
    static func plan(_ input: Input) -> [Reminder] {
        var ranked: [(reminder: Reminder, rank: Int)] = []
        let today = input.calendar.startOfDay(for: input.now)

        for offset in 0..<max(input.horizonDays, 0) {
            guard let day = input.calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let lesson = input.track.lesson(on: day, calendar: input.calendar)
            guard let record = input.records[lesson] else { continue }
            let title = input.titles[lesson] ?? "Lesson \(lesson)"

            for slot in slots(for: record, in: input.window) {
                guard let fireDate = input.calendar.date(
                    bySettingHour: slot.time.hour, minute: slot.time.minute, second: 0, of: day
                ), fireDate > input.now else { continue }

                let reminder = Reminder(
                    fireDate: fireDate,
                    identifier: identifier(day: day, kind: slot.kind, time: slot.time, calendar: input.calendar),
                    title: slot.title(lesson: lesson),
                    body: slot.body(record: record, title: title),
                    kind: slot.kind,
                    dayOffset: offset,
                    lesson: lesson
                )
                ranked.append((reminder, rank(of: slot.kind, dayOffset: offset)))
            }
        }

        // Over budget, the highest rank goes first and, within a rank, the
        // latest: a session is never dropped, then day 0 keeps everything,
        // day 1 keeps its hours, day 2 keeps its sessions.
        ranked.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.reminder.fireDate < rhs.reminder.fireDate
        }
        var kept = ranked.prefix(max(input.budget, 0)).map(\.reminder)
        kept.sort { $0.fireDate < $1.fireDate }

        if let last = kept.last {
            kept[kept.count - 1] = Reminder(
                fireDate: last.fireDate,
                identifier: last.identifier,
                title: last.title,
                body: last.body + " " + closingLine,
                kind: last.kind,
                dayOffset: last.dayOffset,
                lesson: last.lesson
            )
        }
        return kept
    }

    private static func rank(of kind: Kind, dayOffset: Int) -> Int {
        switch kind {
        case .session: 0
        case .hour, .short: 1 + 2 * dayOffset
        case .halfHour: 2 + 2 * dayOffset
        }
    }

    // MARK: - The slots of one day

    /// One reminder-to-be, before it has a date.
    struct Slot: Equatable, Sendable {
        let time: TimeOfDay
        let kind: Kind
        /// For a short practice: which of how many.
        let ordinal: Int
        let count: Int
        /// For a session: what the text said about its length.
        let minutes: Int

        fileprivate func title(lesson: Int) -> String {
            switch kind {
            case .session:
                return "\(sessionName) · Lesson \(lesson)"
            case .hour, .halfHour:
                return "Lesson \(lesson)"
            case .short:
                return "Practice \(ordinal) of \(count) · Lesson \(lesson)"
            }
        }

        /// "Morning practice" for the first of the day and "Evening practice"
        /// for the last, whatever moment the record named; anything between
        /// is a "Practice period".
        var sessionName: String {
            switch ordinal {
            case 1 where count > 1: "Morning practice"
            case 1: "Morning practice"
            case let n where n == count: "Evening practice"
            default: "Practice period"
            }
        }

        fileprivate func body(record: PracticeRecord, title: String) -> String {
            let quoted = "\u{201C}\(title)\u{201D}"
            var line: String
            switch kind {
            case .session:
                let length = minutes > 0 ? "about \(words(minutes)) minutes" : "as long as you can"
                switch sessionName {
                case "Morning practice": line = "\(quoted) — \(length) to begin the day."
                case "Evening practice": line = "\(quoted) — \(length) to close the day."
                default: line = "\(quoted) — \(length)."
                }
            case .hour, .halfHour:
                line = "\(quoted) — \(PracticePlanner.stopPhrase(for: record))"
            case .short:
                let length = record.shortMinutes > 0 ? "about \(minuteWords(record.shortMinutes))" : "a moment"
                line = "\(quoted) — \(length)."
            }
            if record.throughout, kind != .session {
                line += " Remember it in between, too."
            }
            return line
        }
    }

    /// The slots a record produces inside a window, in time order. The
    /// half-hour floor lives here, as does the crowding rule.
    static func slots(for record: PracticeRecord, in window: PracticeWindow) -> [Slot] {
        let usable = window.isUsable
        let start = window.start
        let end = usable ? window.end : window.start
        let span = end.minutesFromMidnight - start.minutesFromMidnight

        // Sessions. Named moments pin to the window's ends; "any" sessions
        // spread evenly — over the whole window when they are the only
        // sessions, over its interior when named ones already hold the ends.
        var sessionTimes: [(time: TimeOfDay, minutes: Int)] = []
        let named = record.sessions.filter { $0.at != .any }
        let anys = record.sessions.filter { $0.at == .any }
        for session in named {
            let time: TimeOfDay
            switch session.at {
            case .wake, .morning: time = start
            case .sleep, .evening: time = end
            case .midday: time = TimeOfDay(minutesFromMidnight: start.minutesFromMidnight + span / 2)
            case .any: continue
            }
            sessionTimes.append((time, session.minutes))
        }
        let anyTimes = spread(count: anys.count, from: start, to: end, includingEnds: named.isEmpty)
        for (session, time) in zip(anys, anyTimes) {
            sessionTimes.append((time, session.minutes))
        }
        sessionTimes.sort { $0.time < $1.time }
        var seen: Set<TimeOfDay> = []
        sessionTimes = sessionTimes.filter { seen.insert($0.time).inserted }

        var slots: [Slot] = sessionTimes.enumerated().map { index, entry in
            Slot(time: entry.time, kind: .session, ordinal: index + 1, count: sessionTimes.count, minutes: entry.minutes)
        }
        guard usable else { return slots }

        func crowded(_ time: TimeOfDay) -> Bool {
            sessionTimes.contains { abs($0.time.minutesFromMidnight - time.minutesFromMidnight) < crowdingMinutes }
        }

        // The clock. A per-hour rate with no clock of its own still earns one
        // stop each hour, so the reader is told the hour has practices in it.
        let clock = effectiveClock(for: record)
        if clock != .none {
            var minute = (start.minutesFromMidnight / 30 + 1) * 30
            while minute < end.minutesFromMidnight {
                let time = TimeOfDay(minutesFromMidnight: minute)
                let onTheHour = time.minute == 0
                if (onTheHour || clock == .halfHour), !crowded(time) {
                    slots.append(Slot(
                        time: time, kind: onTheHour ? .hour : .halfHour,
                        ordinal: 0, count: 0, minutes: record.clockMinutes
                    ))
                }
                minute += 30
            }
        } else if record.shortPerDay > 0 {
            // Short practices, spread like sessions and only where no clock
            // already carries the day.
            let times = spread(count: record.shortPerDay, from: start, to: end, includingEnds: sessionTimes.isEmpty)
                .filter { !crowded($0) }
            for (index, time) in times.enumerated() {
                slots.append(Slot(
                    time: time, kind: .short, ordinal: index + 1, count: times.count, minutes: record.shortMinutes
                ))
            }
        }

        slots.sort { $0.time < $1.time }
        return slots
    }

    /// How often the phone stops for this record: the text's own clock,
    /// floored at every half hour; or once an hour for a per-hour rate.
    static func effectiveClock(for record: PracticeRecord) -> PracticeRecord.Clock {
        switch record.clock {
        case .hour: return .hour
        case .halfHour, .quarterHour, .tenMinutes: return .halfHour
        case .none: return record.shortPerHour > 0 ? .hour : .none
        }
    }

    /// `count` times between `from` and `to`, evenly, rounded to five
    /// minutes. With the ends included one time is the start, two are the
    /// ends, and more divide the span; without them all are interior.
    static func spread(count: Int, from: TimeOfDay, to: TimeOfDay, includingEnds: Bool) -> [TimeOfDay] {
        guard count > 0 else { return [] }
        let span = to.minutesFromMidnight - from.minutesFromMidnight
        guard span > 0 else { return Array(repeating: from, count: 1) }
        var result: [TimeOfDay] = []
        if includingEnds {
            if count == 1 { return [from] }
            for index in 0..<count {
                let raw = from.minutesFromMidnight + span * index / (count - 1)
                result.append(TimeOfDay(minutesFromMidnight: roundedToFive(raw)))
            }
        } else {
            for index in 1...count {
                let raw = from.minutesFromMidnight + span * index / (count + 1)
                result.append(TimeOfDay(minutesFromMidnight: roundedToFive(raw)))
            }
        }
        var seen: Set<TimeOfDay> = []
        return result.filter { seen.insert($0).inserted }
    }

    private static func roundedToFive(_ minutes: Int) -> Int {
        (minutes + 2) / 5 * 5
    }

    // MARK: - Identifiers

    /// `acim.practice.<yyyyMMdd>.<kind>.<HHmm>` — the day and the slot rather
    /// than the lesson, so the same slot planned again replaces itself.
    static func identifier(day: Date, kind: Kind, time: TimeOfDay, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let stamp = String(
            format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
        let clock = String(format: "%02d%02d", time.hour, time.minute)
        return "\(identifierPrefix)\(stamp).\(kind.rawValue).\(clock)"
    }

    // MARK: - Words

    /// What one hourly stop asks for, in the text's own terms.
    static func stopPhrase(for record: PracticeRecord) -> String {
        let length: String? = record.clockMinutes > 0 ? minuteWords(record.clockMinutes) : nil
        switch record.clock {
        case .tenMinutes:
            return "every ten minutes today, if you can."
        case .quarterHour:
            return "every quarter hour today, if you can."
        case .halfHour:
            if let length { return "\(length), every half hour today." }
            return "every half hour today."
        case .hour:
            if record.clockMinutes == 5 { return "the first five minutes of this hour." }
            if let length { return "\(length), as the hour strikes." }
            return "a moment, as the hour strikes."
        case .none:
            switch record.shortPerHour {
            case 1: return "once this hour, a minute or so."
            case 2: return "twice this hour, a minute or so each."
            default: return "several times this hour, a minute or so each."
            }
        }
    }

    /// One line for the Settings row: what this lesson asks for.
    static func cadenceSummary(_ record: PracticeRecord) -> String {
        var parts: [String] = []

        if !record.sessions.isEmpty {
            let minutes = Set(record.sessions.map(\.minutes))
            let length: String
            if minutes.count == 1, let only = minutes.first, only > 0 {
                length = " of \(words(only)) minutes"
            } else if minutes == [0] {
                length = ", as long as you can"
            } else {
                length = ""
            }
            let ends = record.sessions.allSatisfy { $0.at == .wake || $0.at == .morning || $0.at == .sleep || $0.at == .evening }
            if record.sessions.count == 2, ends {
                parts.append("morning and evening" + length)
            } else if record.sessions.count == 1 {
                parts.append("one longer period" + length)
            } else {
                parts.append("\(words(record.sessions.count)) longer periods" + length)
            }
        }

        switch record.clock {
        case .hour:
            parts.append(record.clockMinutes > 0 ? "\(minuteWords(record.clockMinutes)) every hour" : "a moment every hour")
        case .halfHour: parts.append("every half hour")
        case .quarterHour: parts.append("every quarter hour")
        case .tenMinutes: parts.append("every ten minutes")
        case .none:
            if record.shortPerHour > 0 {
                parts.append("several times an hour")
            } else if record.shortPerDay > 0 {
                let length = record.shortMinutes > 0 ? " of \(minuteWords(record.shortMinutes))" : ""
                parts.append(record.shortPerDay == 1
                    ? "one short practice" + length
                    : "\(words(record.shortPerDay)) short practices" + length)
            }
        }

        if parts.isEmpty { parts.append("as often as you remember") }
        return parts.joined(separator: ", ")
    }

    private static func minuteWords(_ minutes: Int) -> String {
        minutes == 1 ? "a minute" : "\(words(minutes)) minutes"
    }

    private static func words(_ number: Int) -> String {
        let small = [
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
            "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
            "nineteen", "twenty"
        ]
        if number >= 0, number < small.count { return small[number] }
        if number == 30 { return "thirty" }
        return String(number)
    }
}
