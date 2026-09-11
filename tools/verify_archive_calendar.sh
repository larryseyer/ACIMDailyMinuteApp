#!/bin/bash
# Proves the Archive Today button lands on today's month and today's day.
#
# What this guards is a calendar that looks frozen. The month chevrons move
# the grid without touching the selected day, and Today used to write only
# that day — so a tap did nothing whenever the day was already today, which
# is the state the screen opens in. A second trap: Today used to write UTC
# midnight, which is yesterday anywhere west of Greenwich, so even a tap that
# "worked" highlighted the wrong cell.
#
# ⛔ The compile line names ONE source file and no others. The rule must stay
# free of SwiftUI, SwiftData and Date() as "now", or the only way to exercise
# a chevroned month or a US afternoon is to wait for one.
#
#   ./tools/verify_archive_calendar.sh
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

func instant(_ string: String, timeZone: TimeZone) -> Date {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = f.date(from: string) else {
        print("  bad instant \(string)")
        exit(1)
    }
    return date
}

let chicago = TimeZone(identifier: "America/Chicago")!
var grid = Calendar(identifier: .gregorian)
grid.firstWeekday = 1
grid.timeZone = chicago

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(secondsFromGMT: 0)!

// 15:00 in Chicago on 2026-09-09 is 20:00 UTC. UTC midnight of that UTC date
// is 19:00 the previous evening in Chicago — yesterday on the grid.
let now = instant("2026-09-09 15:00:00", timeZone: chicago)
let utcMidnight = utc.startOfDay(for: now)
let lastMonth = grid.date(byAdding: .month, value: -1, to: now)!
let march = instant("2026-03-15 10:00:00", timeZone: chicago)

// MARK: - Today restores the month even when the selected day is already today

var afterChevron = ArchiveCalendarState(
    selection: utcMidnight,
    visibleMonth: lastMonth
)
afterChevron.revealToday(now: now, calendar: grid)
check(
    grid.isDate(afterChevron.visibleMonth, equalTo: now, toGranularity: .month),
    "Today after a chevron must show this month, not stay on \(afterChevron.visibleMonth)"
)
check(
    grid.isDate(afterChevron.selection, inSameDayAs: now),
    "Today after a chevron must select today, not \(afterChevron.selection)"
)

// MARK: - Today from another selected day

var fromMarch = ArchiveCalendarState(selection: march, visibleMonth: march)
fromMarch.revealToday(now: now, calendar: grid)
check(
    grid.isDate(fromMarch.visibleMonth, equalTo: now, toGranularity: .month),
    "Today from March must show this month"
)
check(
    grid.isDate(fromMarch.selection, inSameDayAs: now),
    "Today from March must select today"
)

// MARK: - The selected day is the grid's today, not UTC midnight

check(
    !grid.isDate(fromMarch.selection, inSameDayAs: utcMidnight),
    "Today must not land on UTC midnight (yesterday in Chicago)"
)
check(
    grid.component(.day, from: fromMarch.selection) == 9,
    "the highlighted day is the 9th, not \(grid.component(.day, from: fromMarch.selection))"
)

// MARK: - Opening the calendar already sits on today

let opened = ArchiveCalendarState.starting(now: now, calendar: grid)
check(
    grid.isDate(opened.selection, inSameDayAs: now),
    "the calendar opens on today"
)
check(
    grid.isDate(opened.visibleMonth, equalTo: now, toGranularity: .month),
    "the calendar opens on this month"
)

// MARK: - A day with no recording is not a selection

func key(_ date: Date) -> String {
    ArchiveCalendarState.dateString(from: date, calendar: grid)
}

let recordedDay = instant("2026-09-08 10:00:00", timeZone: chicago)
let recorded = Set([key(recordedDay)])

check(
    ArchiveCalendarState.isRecorded(recordedDay, availableDateStrings: recorded, calendar: grid),
    "a published day is recorded"
)
check(
    !ArchiveCalendarState.isRecorded(now, availableDateStrings: recorded, calendar: grid),
    "today before the run is not recorded"
)

check(
    ArchiveCalendarState.selection(preferring: now, availableDateStrings: recorded, calendar: grid)
        .map { grid.isDate($0, inSameDayAs: recordedDay) } == true,
    "preferring an unrecorded today lands on the latest recorded day"
)
check(
    ArchiveCalendarState.selection(preferring: recordedDay, availableDateStrings: recorded, calendar: grid)
        .map { grid.isDate($0, inSameDayAs: recordedDay) } == true,
    "a recorded preference is kept"
)
check(
    ArchiveCalendarState.selection(preferring: now, availableDateStrings: [], calendar: grid) == nil,
    "an empty archive has nothing to select"
)

var snapped = ArchiveCalendarState.starting(now: now, calendar: grid)
snapped.revealToday(now: now, availableDateStrings: recorded, calendar: grid)
check(
    grid.isDate(snapped.selection, inSameDayAs: recordedDay),
    "Today when today is unpublished lands on the latest recorded day, not \(snapped.selection)"
)
check(
    grid.isDate(snapped.visibleMonth, equalTo: recordedDay, toGranularity: .month),
    "Today when today is unpublished still shows that month"
)

var kept = ArchiveCalendarState.starting(now: now, calendar: grid)
kept.revealToday(now: now, availableDateStrings: Set([key(now)]), calendar: grid)
check(
    grid.isDate(kept.selection, inSameDayAs: now),
    "Today when today is recorded still selects today"
)

if failures == 0 {
    print("\(checks) checks, Today lands on today's month and today's day")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/ArchiveCalendar.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"
