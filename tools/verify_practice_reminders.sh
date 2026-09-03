#!/bin/bash
# Proves the practice reminders keep three promises: they follow the lesson's
# own cadence, they never exceed what a phone will hold, and they yield to
# Focus and Do Not Disturb.
#
# What this guards is a phone buzzing at the wrong time, about the wrong
# lesson, or not at all. iOS keeps 64 pending requests per app and drops the
# oldest silently past that; a plan one reminder over budget loses tomorrow's
# morning session with no error anywhere. A reminder outside the reader's
# window wakes them. A reminder at `.timeSensitive` cuts through a Focus the
# reader set on purpose. None of these crash, and none of them show in a build.
#
# ⛔ The compile line names TWO source files and no others. That is half the
# check: the planner must stay free of SwiftUI, SwiftData, UserDefaults,
# Bundle and Date(), or the only way to exercise a weekend, a DST change or an
# inverted window is to wait for one.
#
#   ./tools/verify_practice_reminders.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# MARK: - Purity

stripped="$(sed -e 's://.*::' "$REPO/ACIMDailyMinute/Utilities/PracticePlanner.swift")"
for banned in SwiftUI SwiftData UserDefaults Bundle "Date()" CorpusService; do
  if grep -q -F "$banned" <<<"$stripped"; then
    echo "FAIL: PracticePlanner.swift reaches $banned — the planner must stay pure" >&2
    exit 1
  fi
done

# MARK: - Do Not Disturb

# Every request the app builds says `.active`, and nothing in the app tree
# asks for more. Comments are stripped first: the invariant is allowed to
# name what it forbids.
if ! grep -q "interruptionLevel = .active" "$REPO/ACIMDailyMinute/Services/NotificationManager.swift"; then
  echo "FAIL: NotificationManager.swift no longer sets interruptionLevel = .active" >&2
  exit 1
fi
offenders="$(find "$REPO/ACIMDailyMinute" "$REPO/ACIMDailyMinuteWidget" "$REPO/ACIMDailyMinuteWatch" -name '*.swift' -print0 \
  | xargs -0 sed -e 's://.*::' \
  | grep -E "timeSensitive|interruptionLevel = \.critical|\.critical\b" || true)"
if [ -n "$offenders" ]; then
  echo "FAIL: a notification asks to cut through Focus:" >&2
  echo "$offenders" >&2
  exit 1
fi
if grep -q -i "time-sensitive" "$REPO/ACIMDailyMinute.entitlements"; then
  echo "FAIL: the time-sensitive entitlement is present" >&2
  exit 1
fi

# MARK: - The harness

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 25 { print("  \(message())") }
    }
}

let repo = CommandLine.arguments[1]

// MARK: - The records

let recordData = try! Data(contentsOf: URL(fileURLWithPath: "\(repo)/ACIMDailyMinute/Resources/WorkbookPractice.json"))
let recordList = try! JSONDecoder().decode([PracticeRecord].self, from: recordData)
check(recordList.count == 365, "365 records, found \(recordList.count)")
check(recordList.map(\.lesson) == Array(1...365), "records are lessons 1…365 in order")
var records: [Int: PracticeRecord] = [:]
for record in recordList {
    records[record.lesson] = record
    check(record.sessions.count <= 6, "lesson \(record.lesson): \(record.sessions.count) sessions")
    check(record.shortPerDay <= 6, "lesson \(record.lesson): \(record.shortPerDay) short practices")
    check(!record.evidence.isEmpty && record.evidence.count < 160, "lesson \(record.lesson): evidence length")
    check(!record.source.isEmpty, "lesson \(record.lesson): source")
    check(record.clockMinutes >= 0 && record.shortMinutes >= 0, "lesson \(record.lesson): negative minutes")
    let plans = record.sessions.count + record.shortPerDay + record.shortPerHour
        + (record.clock == .none ? 0 : 1)
    check(plans > 0 || record.throughout, "lesson \(record.lesson): asks for nothing at all")
}
check(records.count == 365, "each lesson once")

struct Title: Decodable { let lessonNumber: Int; let title: String }
let titleData = try! Data(contentsOf: URL(fileURLWithPath: "\(repo)/ACIMDailyMinute/Resources/Workbook365.json"))
var titles: [Int: String] = [:]
for entry in try! JSONDecoder().decode([Title].self, from: titleData) { titles[entry.lessonNumber] = entry.title }
check(titles.count == 365, "365 titles")

// The text's own cadence, as the survey read it, spot-checked against the data.
func expect(_ lesson: Int, clock: PracticeRecord.Clock, sessions: Int, shortPerDay: Int = 0) {
    guard let r = records[lesson] else { return check(false, "no record for \(lesson)") }
    check(r.clock == clock, "lesson \(lesson) clock \(r.clock) expected \(clock)")
    check(r.sessions.count == sessions, "lesson \(lesson) sessions \(r.sessions.count) expected \(sessions)")
    check(r.shortPerDay == shortPerDay, "lesson \(lesson) shortPerDay \(r.shortPerDay) expected \(shortPerDay)")
}
expect(1, clock: .none, sessions: 0, shortPerDay: 2)
expect(20, clock: .halfHour, sessions: 0)
expect(27, clock: .halfHour, sessions: 0)
expect(31, clock: .none, sessions: 2)
expect(40, clock: .tenMinutes, sessions: 0)
expect(41, clock: .none, sessions: 1)
expect(51, clock: .none, sessions: 2, shortPerDay: 5)
expect(70, clock: .none, sessions: 2)
expect(75, clock: .quarterHour, sessions: 2)
expect(95, clock: .hour, sessions: 0)
check(records[95]?.clockMinutes == 5, "lesson 95 is five minutes an hour")
expect(111, clock: .halfHour, sessions: 2)
expect(121, clock: .hour, sessions: 2)
expect(122, clock: .quarterHour, sessions: 2)
expect(141, clock: .hour, sessions: 2)
expect(153, clock: .hour, sessions: 2)
expect(171, clock: .hour, sessions: 2)
expect(201, clock: .hour, sessions: 2)
check(records[201]?.sessions.allSatisfy { $0.minutes == 15 } == true, "Review VI is fifteen minutes")
expect(221, clock: .hour, sessions: 2)
expect(365, clock: .hour, sessions: 2)
for n in 221...365 {
    check(records[n]?.sessions.allSatisfy { $0.minutes == 0 } == true, "Part II lesson \(n) states no duration")
}
for n in 93...110 {
    check(records[n]?.clock == .hour && records[n]?.clockMinutes == 5, "lesson \(n) is the first five minutes of every hour")
}

// MARK: - A calendar with a DST change in it

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Chicago")!
calendar.locale = Locale(identifier: "en_US_POSIX")

func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}
func clock(_ date: Date) -> (Int, Int, Int, Int, Int) {
    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    return (c.year!, c.month!, c.day!, c.hour!, c.minute!)
}
func wall(_ date: Date) -> TimeOfDay {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return TimeOfDay(hour: c.hour!, minute: c.minute!)
}

// MARK: - The track

let friday = at(2026, 8, 28)
let published = LessonTrack.published(latestRecorded: 84, recordedOn: friday)
check(published.lesson(on: at(2026, 8, 28), calendar: calendar) == 84, "the recorded day is its own lesson")
check(published.lesson(on: at(2026, 8, 29), calendar: calendar) == 84, "Saturday repeats Friday")
check(published.lesson(on: at(2026, 8, 30), calendar: calendar) == 84, "Sunday repeats Friday")
check(published.lesson(on: at(2026, 8, 31), calendar: calendar) == 85, "Monday advances")
check(published.lesson(on: at(2026, 9, 1), calendar: calendar) == 86, "Tuesday advances again")
check(published.lesson(on: at(2026, 9, 7), calendar: calendar) == 90, "next Monday is five on")
check(published.lesson(on: at(2026, 8, 20), calendar: calendar) == 84, "before the anchor is the anchor")
check(LessonTrack.published(latestRecorded: 364, recordedOn: friday).lesson(on: at(2027, 1, 1), calendar: calendar) == 365, "the publisher's sequence stops at 365")
check(LessonSchedule.publishingDays(after: friday, through: friday) == 0, "no days through itself")
check(LessonSchedule.publishingDays(after: friday, through: at(2026, 8, 31)) == 1, "Friday to Monday is one publishing day")

let own = LessonTrack.own(startLesson: 363, startDay: at(2026, 8, 28, 15, 0))
check(own.lesson(on: at(2026, 8, 28), calendar: calendar) == 363, "the start day is the start lesson")
check(own.lesson(on: at(2026, 8, 29), calendar: calendar) == 364, "one day on is one lesson on")
check(own.lesson(on: at(2026, 8, 30), calendar: calendar) == 365, "two days on is 365")
check(own.lesson(on: at(2026, 9, 15), calendar: calendar) == 365, "and it stays at 365")
check(own.lesson(on: at(2026, 8, 27), calendar: calendar) == 363, "a day before the start is still the start")
check(LessonTrack.own(startLesson: 1, startDay: at(2026, 1, 1)).lesson(on: at(2026, 12, 31), calendar: calendar) == 365, "day 364 later is 365")
check(LessonTrack.own(startLesson: 1, startDay: at(2026, 1, 1)).lesson(on: at(2026, 3, 9), calendar: calendar) == 68, "a DST change does not lose a day")

// MARK: - Every lesson, every window, every hour of the day

let windows: [(name: String, window: PracticeWindow)] = [
    ("07-22", PracticeWindow(start: TimeOfDay(hour: 7, minute: 0), end: TimeOfDay(hour: 22, minute: 0))),
    ("06-23", PracticeWindow(start: TimeOfDay(hour: 6, minute: 0), end: TimeOfDay(hour: 23, minute: 0))),
    ("all day", PracticeWindow(start: TimeOfDay(hour: 0, minute: 0), end: TimeOfDay(hour: 23, minute: 59))),
    ("inverted", PracticeWindow(start: TimeOfDay(hour: 22, minute: 0), end: TimeOfDay(hour: 7, minute: 0))),
    ("half an hour", PracticeWindow(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 9, minute: 30))),
]
let nows: [(name: String, date: Date)] = [
    ("before", at(2026, 9, 3, 5, 0)),
    ("midday", at(2026, 9, 3, 13, 37)),
    ("after", at(2026, 9, 3, 23, 30)),
]
let prefix = PracticePlanner.identifierPrefix

for lesson in 1...365 {
    for (wname, window) in windows {
        for (nname, now) in nows {
            let input = PracticePlanner.Input(
                records: records, titles: titles, window: window,
                track: .own(startLesson: lesson, startDay: now), now: now, calendar: calendar
            )
            let plan = PracticePlanner.plan(input)
            let label = "lesson \(lesson) \(wname) \(nname)"
            check(plan.count <= PracticePlanner.defaultBudget, "\(label): \(plan.count) over budget")
            check(plan.allSatisfy { $0.fireDate > now }, "\(label): a reminder in the past")
            check(zip(plan, plan.dropFirst()).allSatisfy { $0.fireDate < $1.fireDate }, "\(label): not strictly ascending")
            check(Set(plan.map(\.identifier)).count == plan.count, "\(label): duplicate identifier")
            check(plan.allSatisfy { $0.identifier.hasPrefix(prefix) }, "\(label): identifier without prefix")
            check(plan.allSatisfy { $0.title.contains("Lesson \($0.lesson)") }, "\(label): title without lesson")
            check(plan.allSatisfy { $0.body.contains(titles[$0.lesson]!) }, "\(label): body without the idea")
            check(plan.allSatisfy { $0.lesson == lesson || $0.dayOffset > 0 }, "\(label): day 0 names another lesson")
            check(plan.allSatisfy { $0.dayOffset >= 0 && $0.dayOffset < PracticePlanner.defaultHorizonDays }, "\(label): outside the horizon")
            let lo = window.isUsable ? window.start : window.start
            let hi = window.isUsable ? window.end : window.start
            for r in plan {
                let t = wall(r.fireDate)
                check(t >= lo && t <= hi, "\(label): \(r.identifier) at \(t.hour):\(t.minute) outside the window")
                if r.kind == .hour || r.kind == .halfHour {
                    check(t > lo && t < hi, "\(label): a clock stop on the window's edge")
                    check(r.kind == .hour ? t.minute == 0 : t.minute == 30, "\(label): \(r.kind) at minute \(t.minute)")
                }
                let (y, m, d, h, min) = clock(r.fireDate)
                let expected = String(format: "%@%04d%02d%02d.%@.%02d%02d", prefix, y, m, d, r.kind.rawValue, h, min)
                check(r.identifier == expected, "\(label): identifier \(r.identifier) is not \(expected)")
            }
            if !window.isUsable {
                check(plan.allSatisfy { $0.kind == .session }, "\(label): more than sessions in an unusable window")
            }
            let tails = plan.filter { $0.body.hasSuffix(PracticePlanner.closingLine) }.count
            check(tails == (plan.isEmpty ? 0 : 1), "\(label): \(tails) closing lines")
            if !plan.isEmpty {
                check(plan.last!.body.hasSuffix(PracticePlanner.closingLine), "\(label): the closing line is not last")
            }
        }
    }
}

// MARK: - The shape of one day

let day = PracticeWindow(start: TimeOfDay(hour: 7, minute: 0), end: TimeOfDay(hour: 22, minute: 0))
let early = at(2026, 9, 3, 5, 0)
func plan(_ lesson: Int, window: PracticeWindow = day, now: Date = early, budget: Int = PracticePlanner.defaultBudget, days: Int = PracticePlanner.defaultHorizonDays) -> [PracticePlanner.Reminder] {
    PracticePlanner.plan(.init(
        records: records, titles: titles, window: window,
        track: .own(startLesson: lesson, startDay: now), now: now, calendar: calendar,
        horizonDays: days, budget: budget
    ))
}
func today(_ plan: [PracticePlanner.Reminder]) -> [PracticePlanner.Reminder] { plan.filter { $0.dayOffset == 0 } }

// Lesson 95: sessions none, the first five minutes of every hour, strictly inside.
let l95 = today(plan(95))
check(l95.count == 14, "lesson 95: \(l95.count) stops, expected 14 (08:00…21:00)")
check(l95.allSatisfy { $0.kind == .hour }, "lesson 95: only hourly stops")
check(l95.first.map { wall($0.fireDate) } == TimeOfDay(hour: 8, minute: 0), "lesson 95: first stop at 08:00")
check(l95.last.map { wall($0.fireDate) } == TimeOfDay(hour: 21, minute: 0), "lesson 95: last stop at 21:00")
check(l95.allSatisfy { $0.body.contains("five minutes") }, "lesson 95: the body says five minutes")

// Lesson 121: morning at the start, evening at the end, an hourly stop between.
let l121 = today(plan(121))
let sessions121 = l121.filter { $0.kind == .session }
check(sessions121.count == 2, "lesson 121: two sessions")
check(sessions121.first.map { wall($0.fireDate) } == day.start, "lesson 121: morning at the window's start")
check(sessions121.last.map { wall($0.fireDate) } == day.end, "lesson 121: evening at the window's end")
check(sessions121.first?.title.hasPrefix("Morning practice") == true, "lesson 121: morning is named")
check(sessions121.last?.title.hasPrefix("Evening practice") == true, "lesson 121: evening is named")
check(sessions121.first?.body.contains("ten minutes") == true, "lesson 121: ten minutes")
check(l121.filter { $0.kind == .hour }.count == 14, "lesson 121: fourteen hourly stops")

// Lesson 111: on the hour and the half hour, wake and sleep sessions.
let l111 = today(plan(111))
check(l111.filter { $0.kind == .hour }.count == 14, "lesson 111: fourteen hours")
check(l111.filter { $0.kind == .halfHour }.count == 15, "lesson 111: fifteen half hours")
check(l111.filter { $0.kind == .session }.count == 2, "lesson 111: two sessions")

// Lesson 40: every ten minutes in the text, every half hour on the phone.
let l40 = today(plan(40))
check(l40.filter { $0.kind == .halfHour }.count == 15, "lesson 40: half-hour floor")
check(l40.allSatisfy { $0.kind == .session || $0.body.contains("every ten minutes") }, "lesson 40: the body keeps the text's cadence")

// Lesson 1: twice a day, morning and evening, no sessions.
let l1 = today(plan(1))
check(l1.count == 2 && l1.allSatisfy { $0.kind == .short }, "lesson 1: two short practices")
check(l1.first.map { wall($0.fireDate) } == day.start && l1.last.map { wall($0.fireDate) } == day.end, "lesson 1: at the ends of the day")
check(l1.first?.title.hasPrefix("Practice 1 of 2") == true, "lesson 1: numbered")

// Lesson 21: five a day, evenly, ends included, equal gaps within five minutes.
let l21 = today(plan(21))
check(l21.count == 5, "lesson 21: five short practices, found \(l21.count)")
let gaps21 = zip(l21, l21.dropFirst()).map { Int($1.fireDate.timeIntervalSince($0.fireDate) / 60) }
check(gaps21.allSatisfy { abs($0 - 225) <= 5 }, "lesson 21: gaps \(gaps21) are not even")

// Review I (51): wake and sleep sessions with five short practices between them.
let l51 = today(plan(51))
check(l51.filter { $0.kind == .session }.count == 2, "lesson 51: two sessions")
let shorts51 = l51.filter { $0.kind == .short }
check(shorts51.count == 5, "lesson 51: five short practices")
check(shorts51.allSatisfy { wall($0.fireDate) > day.start && wall($0.fireDate) < day.end }, "lesson 51: shorts are interior")

// Lesson 36: four periods spread across the day, the first and last at the ends.
let l36 = today(plan(36))
check(l36.count == 4 && l36.allSatisfy { $0.kind == .session }, "lesson 36: four sessions")
check(l36.first.map { wall($0.fireDate) } == day.start && l36.last.map { wall($0.fireDate) } == day.end, "lesson 36: at the ends")
check(l36[1].title.hasPrefix("Practice period"), "lesson 36: the middle ones are practice periods")

// Lesson 65: one period, at the start; hourly stops.
let l65 = today(plan(65))
check(l65.filter { $0.kind == .session }.count == 1, "lesson 65: one session")
check(l65.first.map { wall($0.fireDate) } == day.start, "lesson 65: at the start")

// Lesson 153: as long as you can.
let l153 = today(plan(153))
check(l153.first?.body.contains("as long as you can") == true, "lesson 153: as long as you can")

// Lesson 67 (four or five times an hour, no clock of its own): one stop each hour.
let l67 = today(plan(67))
check(l67.filter { $0.kind == .hour }.count == 14, "lesson 67: a stop each hour for a per-hour rate")
check(l67.filter { $0.kind == .hour }.allSatisfy { $0.body.contains("this hour") }, "lesson 67: the stop names the rate")

// Throughout: the words.
check(today(plan(95)).allSatisfy { $0.body.contains("Remember it in between") }, "lesson 95: throughout is said")
check(!today(plan(1)).contains { $0.body.contains("Remember it in between") }, "lesson 1: throughout is not said")

// MARK: - Budget and drop order

let full111 = plan(111)
check(full111.count == PracticePlanner.defaultBudget, "lesson 111 fills the budget: \(full111.count)")
check(full111.filter { $0.dayOffset == 0 && $0.kind == .halfHour }.count == 15, "day 0 keeps every half hour")
check(full111.filter { $0.dayOffset == 1 && $0.kind == .hour }.count == 14, "day 1 keeps its hours")
check(full111.filter { $0.dayOffset == 2 && $0.kind == .halfHour }.isEmpty, "day 2 loses its half hours")
check(full111.filter { $0.kind == .session }.count == 6, "every session survives")
let six = plan(111, budget: 6)
check(six.count == 6 && six.allSatisfy { $0.kind == .session }, "budget 6 is sessions only")
check(plan(111, budget: 0).isEmpty, "budget 0 is nothing")
check(plan(111, days: 0).isEmpty, "no horizon is nothing")
let oneDay = plan(111, days: 1)
check(oneDay.allSatisfy { $0.dayOffset == 0 }, "a one-day horizon stays on day 0")
check(oneDay.count == 31, "a one-day horizon is a whole day: \(oneDay.count)")

// Day 2 keeps at least its sessions, whatever the budget did to its hours.
check(full111.filter { $0.dayOffset == 2 && $0.kind == .session }.count == 2, "day 2 keeps its sessions")

// MARK: - Now

let mid = plan(95, now: at(2026, 9, 3, 13, 37))
check(today(mid).first.map { wall($0.fireDate) } == TimeOfDay(hour: 14, minute: 0), "midday: the next stop is 14:00")
let late = plan(95, now: at(2026, 9, 3, 23, 30))
check(today(late).isEmpty, "after the window, today is over")
check(late.first?.dayOffset == 1, "after the window, tomorrow comes first")

// MARK: - The window

let inverted = plan(121, window: PracticeWindow(start: TimeOfDay(hour: 22, minute: 0), end: TimeOfDay(hour: 7, minute: 0)))
check(today(inverted).count == 1, "inverted: the two sessions fold onto one time")
check(today(inverted).allSatisfy { wall($0.fireDate) == TimeOfDay(hour: 22, minute: 0) }, "inverted: at the start")
let short = plan(121, window: PracticeWindow(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 9, minute: 30)))
check(today(short).allSatisfy { $0.kind == .session }, "a half-hour window has no clock stops")
let exact = plan(95, window: PracticeWindow(start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 9, minute: 0)))
check(today(exact).isEmpty, "a one-hour window on the hours has no stop strictly inside")
let offHour = plan(95, window: PracticeWindow(start: TimeOfDay(hour: 7, minute: 30), end: TimeOfDay(hour: 8, minute: 45)))
check(today(offHour).count == 1 && today(offHour).first.map { wall($0.fireDate) } == TimeOfDay(hour: 8, minute: 0), "a stop inside an off-hour window")

// A session within ten minutes of a stop is the stop, and keeps it away.
let crowded = today(plan(121, window: PracticeWindow(start: TimeOfDay(hour: 7, minute: 55), end: TimeOfDay(hour: 21, minute: 5))))
check(!crowded.contains { $0.kind == .hour && wall($0.fireDate) == TimeOfDay(hour: 8, minute: 0) }, "crowded: 08:00 is five minutes from the morning session")
check(!crowded.contains { $0.kind == .hour && wall($0.fireDate) == TimeOfDay(hour: 21, minute: 0) }, "crowded: 21:00 is five minutes from the evening session")
check(crowded.filter { $0.kind == .hour }.count == 12, "crowded: 09:00…20:00 is twelve, found \(crowded.filter { $0.kind == .hour }.count)")
let roomy = today(plan(121, window: PracticeWindow(start: TimeOfDay(hour: 7, minute: 5), end: TimeOfDay(hour: 21, minute: 55))))
check(roomy.filter { $0.kind == .hour }.count == 14, "roomy: 08:00…21:00 is fourteen, found \(roomy.filter { $0.kind == .hour }.count)")

// MARK: - DST

// Spring forward on 2026-03-08 in Chicago. Day 2's evening is two calendar
// days after day 0's, at the same wall-clock hour, although 23 hours passed
// on the middle day.
let dst = plan(121, now: at(2026, 3, 7, 5, 0))
let evenings = dst.filter { $0.kind == .session && wall($0.fireDate) == day.end }
check(evenings.count == 3, "three evenings across the change: \(evenings.count)")
if evenings.count == 3 {
    let span = calendar.dateComponents([.day], from: evenings[0].fireDate, to: evenings[2].fireDate).day
    check(span == 2, "day 2's evening is two days on")
    check(clock(evenings[1].fireDate).3 == 22, "the evening after the change is still at 22:00")
    check(evenings[1].fireDate.timeIntervalSince(evenings[0].fireDate) == 23 * 3600, "the short day is 23 hours")
}

// MARK: - The summary line

check(PracticePlanner.cadenceSummary(records[95]!) == "five minutes every hour", "summary 95: \(PracticePlanner.cadenceSummary(records[95]!))")
check(PracticePlanner.cadenceSummary(records[121]!) == "morning and evening of ten minutes, a moment every hour", "summary 121: \(PracticePlanner.cadenceSummary(records[121]!))")
check(PracticePlanner.cadenceSummary(records[1]!) == "two short practices of a minute", "summary 1: \(PracticePlanner.cadenceSummary(records[1]!))")
check(PracticePlanner.cadenceSummary(records[300]!) == "morning and evening, as long as you can, a moment every hour", "summary 300: \(PracticePlanner.cadenceSummary(records[300]!))")
for n in 1...365 {
    check(!PracticePlanner.cadenceSummary(records[n]!).isEmpty, "summary \(n) is empty")
}

if failures == 0 {
    print("\(checks) checks, every reminder is inside the day, under budget and about the right lesson")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/PracticePlanner.swift" \
    "$REPO/ACIMDailyMinute/Utilities/LessonSchedule.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify" "$REPO"
