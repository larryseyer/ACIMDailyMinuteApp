#!/bin/bash
# Proves the app names the right day when it says "available on".
#
# What this guards is a promise made to a reader about the future. A lesson the
# publisher has not recorded yet, and a day the Daily Minute run missed, are both
# told WHEN — the lesson by counting weekdays from the newest recording, the day
# by its place in the line of missed days the nightly run clears one at a time.
# A day off in either direction is not a crash and not a warning: it is a reader
# who came back on the day they were told and found nothing.
#
# ⛔ The compile line names TWO source files and no others. That is half the
# check: both rules must stay free of SwiftData, SwiftUI and Date(), or the only
# way to exercise a weekend, a missed day or an empty archive is to wait for one.
#
#   ./tools/verify_schedules.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 20 { print("  \(message())") }
    }
}

func day(_ string: String) -> Date {
    guard let date = LessonSchedule.day(from: string) else {
        print("  bad date literal \(string)"); exit(1)
    }
    return date
}

let cal = LessonSchedule.publicationCalendar

// MARK: - The day formatter is the publisher's own, in the publisher's zone

check(LessonSchedule.formatted(day("2026-09-02")) == "2026-09-02", "formatted round trips")
check(LessonSchedule.day(from: "not a day") == nil, "garbage is not a day")
// Ten minutes before midnight UTC is still that day, wherever the reader is.
let lateUTC = day("2026-09-02").addingTimeInterval(23 * 3600 + 50 * 60)
check(LessonSchedule.formatted(lateUTC) == "2026-09-02", "late UTC evening stays on its day")

// MARK: - The weekday walk

// Friday 2026-08-28 → Monday 2026-08-31 → Tuesday 2026-09-01.
check(LessonSchedule.advancingWeekdays(1, from: day("2026-08-28")) == day("2026-08-31"), "a Friday advances to Monday")
check(LessonSchedule.advancingWeekdays(2, from: day("2026-08-28")) == day("2026-09-01"), "two weekdays from Friday is Tuesday")
check(LessonSchedule.advancingWeekdays(0, from: day("2026-08-28")) == day("2026-08-28"), "zero stays put")
check(LessonSchedule.advancingWeekdays(5, from: day("2026-08-31")) == day("2026-09-07"), "five weekdays is one week")

// MARK: - Which lesson lands when, from the feed's own anchor

// The feed on 2026-09-02: Lesson 84 recorded that day, a Wednesday.
let anchorNumber = 84
let anchorDate = day("2026-09-02")
check(LessonSchedule.availabilityDate(for: 84, latestRecorded: anchorNumber, latestDate: anchorDate) == nil, "the recorded lesson has no date")
check(LessonSchedule.availabilityDate(for: 1, latestRecorded: anchorNumber, latestDate: anchorDate) == nil, "an earlier lesson has no date")
check(LessonSchedule.availabilityDate(for: 85, latestRecorded: anchorNumber, latestDate: anchorDate) == day("2026-09-03"), "85 lands Thursday")
check(LessonSchedule.availabilityDate(for: 86, latestRecorded: anchorNumber, latestDate: anchorDate) == day("2026-09-04"), "86 lands Friday")
check(LessonSchedule.availabilityDate(for: 87, latestRecorded: anchorNumber, latestDate: anchorDate) == day("2026-09-07"), "87 skips the weekend to Monday")
check(LessonSchedule.availabilityDate(for: 90, latestRecorded: 0, latestDate: anchorDate) == nil, "no anchor, no date")

// MARK: - The anchor is the highest DATED lesson

typealias Candidate = (number: Int, date: Date?)
let dated: [Candidate] = [(83, day("2026-09-01")), (84, day("2026-09-02"))]
let a1 = LessonSchedule.anchor(from: dated)
check(a1?.number == 84 && a1?.date == day("2026-09-02"), "the newest dated lesson anchors")
let a2 = LessonSchedule.anchor(from: dated + [(90, nil)])
check(a2?.number == 84, "a higher number with no date is passed over")
let a3 = LessonSchedule.anchor(from: dated + [(85, day("2026-09-03"))])
check(a3?.number == 85 && a3?.date == day("2026-09-03"), "a later archived lesson with a date wins")
check(LessonSchedule.anchor(from: []) == nil, "nothing seen, no anchor")
check(LessonSchedule.anchor(from: [(0, day("2026-03-30"))]) == nil, "lesson 0 is not an anchor")
let a4 = LessonSchedule.anchor(from: [(84, day("2026-09-02")), (83, day("2026-09-01"))])
check(a4?.number == 84, "order of candidates does not matter")

// MARK: - When a day's Daily Minute exists

// The real feed on 2026-09-02: every day from 03-20 to 09-02 except 05-31 and 08-14.
var archived = Set<String>()
var cursor = day("2026-03-20")
while cursor <= day("2026-09-02") {
    let key = LessonSchedule.formatted(cursor)
    if key != "2026-05-31" && key != "2026-08-14" { archived.insert(key) }
    cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
}
let today = day("2026-09-02")
func availability(_ string: String) -> MinuteSchedule.Availability {
    MinuteSchedule.availability(of: day(string), archived: archived, today: today)
}

check(availability("2026-09-02") == .archived, "today with a reading is archived")
check(availability("2026-04-10") == .archived, "a past day with a reading is archived")
check(availability("2026-09-03") == .publishesOn(day("2026-09-03")), "tomorrow publishes tomorrow")
check(availability("2026-09-10") == .publishesOn(day("2026-09-10")), "next week publishes on its day")
check(availability("2026-05-31") == .expectedOn(day("2026-09-03")), "the oldest missed day is filled tomorrow")
check(availability("2026-08-14") == .expectedOn(day("2026-09-04")), "the next missed day the night after")
check(availability("2026-03-19") == .beforeTheArchive(day("2026-03-20")), "the day before the first is before the archive")
check(availability("2025-01-01") == .beforeTheArchive(day("2026-03-20")), "long before is before the archive")

// Today with no reading yet — before the 02:00 run — publishes today.
var beforeTheRun = archived
beforeTheRun.remove("2026-09-02")
check(
    MinuteSchedule.availability(of: today, archived: beforeTheRun, today: today) == .publishesOn(today),
    "today before the run publishes today"
)
// And yesterday's gap does not move because today is not in yet: the line of
// missed days is counted up to yesterday only.
check(
    MinuteSchedule.availability(of: day("2026-08-14"), archived: beforeTheRun, today: today) == .expectedOn(day("2026-09-04")),
    "today's own absence is not a missed day"
)

// A reader's instant, not midnight: 2026-05-31 at 15:42 UTC is still 05-31.
check(
    MinuteSchedule.availability(of: day("2026-05-31").addingTimeInterval(15 * 3600 + 42 * 60), archived: archived, today: today)
        == .expectedOn(day("2026-09-03")),
    "an instant inside a day is that day"
)

// An empty archive can say nothing about the past.
check(MinuteSchedule.availability(of: day("2026-04-10"), archived: [], today: today) == .unknown, "empty archive, past day, unknown")
check(MinuteSchedule.availability(of: day("2026-09-09"), archived: [], today: today) == .publishesOn(day("2026-09-09")), "empty archive, future day, still publishes on its day")

// MARK: - Every sentence names its day the publisher's way

check(MinuteSchedule.Availability.archived.sentence == nil, "an archived day has a reading, not a sentence")
check(availability("2026-09-10").sentence == "The Daily Minute for this day will be available on 2026-09-10.", "publishes sentence: \(availability("2026-09-10").sentence ?? "nil")")
check(availability("2026-05-31").sentence == "No reading was published on this day. Missed days are filled in one a night; expect this one on 2026-09-03.", "expected sentence: \(availability("2026-05-31").sentence ?? "nil")")
check(availability("2026-03-01").sentence == "The Daily Minute began on 2026-03-20. There is nothing before it.", "before sentence: \(availability("2026-03-01").sentence ?? "nil")")
check(MinuteSchedule.Availability.unknown.sentence == "No readings archived on this date.", "unknown sentence")

if failures == 0 {
    print("\(checks) checks, every day the app promises is the day the publisher will keep")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/LessonSchedule.swift" \
    "$REPO/ACIMDailyMinute/Utilities/MinuteSchedule.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"
