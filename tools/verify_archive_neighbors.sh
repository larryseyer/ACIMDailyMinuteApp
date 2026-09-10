#!/bin/bash
# Proves an empty Archive day can name the nearest days before it that do
# have a reading.
#
# What this guards is a calendar cell that opens onto a sentence and a dead
# end. A missed night, a day before the first publication, or a day that has
# not come yet, used to leave the reader with nothing to tap. The days that
# do hold a reading sit one or two cells away; the empty day has to list
# them, nearest first, and never invent a day the archive does not have.
#
# ⛔ The compile line names TWO source files and no others. The rule must stay
# free of SwiftUI, SwiftData and Date() as "now", or the only way to exercise
# a missed night is to wait for one.
#
#   ./tools/verify_archive_neighbors.sh
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

// The real feed on 2026-09-02: every day from 03-20 to 09-02 except 05-31 and 08-14.
var archived = Set<String>()
var cursor = day("2026-03-20")
while cursor <= day("2026-09-02") {
    let key = LessonSchedule.formatted(cursor)
    if key != "2026-05-31" && key != "2026-08-14" { archived.insert(key) }
    cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
}

func neighbors(_ string: String, count: Int = 3) -> [String] {
    MinuteSchedule.nearestArchivedDays(before: day(string), archived: archived, count: count)
}

// MARK: - A missed day names the days just before it, not the gap itself

check(
    neighbors("2026-05-31") == ["2026-05-30", "2026-05-29", "2026-05-28"],
    "the oldest missed day lists the three days before it, not itself: \(neighbors("2026-05-31"))"
)
check(
    neighbors("2026-08-14") == ["2026-08-13", "2026-08-12", "2026-08-11"],
    "the next missed day lists the three days before it: \(neighbors("2026-08-14"))"
)

// MARK: - A day that has not come yet still offers the latest readings

check(
    neighbors("2026-09-10") == ["2026-09-02", "2026-09-01", "2026-08-31"],
    "a future day lists the latest archived days before it: \(neighbors("2026-09-10"))"
)

// MARK: - Nothing before the first publication

check(neighbors("2026-03-01").isEmpty, "before the archive there is no earlier reading")
check(neighbors("2026-03-20").isEmpty, "the first published day has no earlier reading")

// MARK: - The empty day itself is never listed, even when it later fills in

check(
    !neighbors("2026-09-02").contains("2026-09-02"),
    "today is not an earlier day"
)
check(
    neighbors("2026-09-02").first == "2026-09-01",
    "the nearest day before today is yesterday, not today"
)

// MARK: - Never invent a day, never look forward, never pad

check(MinuteSchedule.nearestArchivedDays(before: day("2026-04-10"), archived: [], count: 3).isEmpty, "an empty archive lists nothing")
check(neighbors("2026-03-22", count: 5) == ["2026-03-21", "2026-03-20"], "fewer than the asked-for count is not padded")
check(neighbors("2026-05-31", count: 1) == ["2026-05-30"], "count 1 is the single nearest day")
check(neighbors("2026-05-31", count: 0).isEmpty, "count 0 is nothing")
check(
    !neighbors("2026-05-31").contains(where: { $0 > "2026-05-31" }),
    "days after the empty day are not offered as earlier readings"
)
check(
    neighbors("2026-08-15").first == "2026-08-13",
    "the day after a gap still skips the gap: \(neighbors("2026-08-15"))"
)

if failures == 0 {
    print("\(checks) checks, an empty day names the nearest earlier readings")
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

# The empty-day screen has to ask for the neighbors, not only print a sentence.
if ! grep -q 'nearestArchivedDays' "$REPO/ACIMDailyMinute/Views/Archive/ArchiveDateDetailView.swift"; then
    echo "ArchiveDateDetailView never asks for nearby days"
    exit 1
fi
