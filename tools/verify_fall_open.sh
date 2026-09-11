#!/bin/bash
# Proves "Let it fall open" picks a published Daily Minute, and only a
# bundled segment when there is no published minute to open.
#
# What this guards is a book that will not fall open. A physical volume
# opens onto a page that exists; this app's published minutes are those
# pages, and the bundled corpus is the volume itself when none have been
# fetched yet. Picking a lesson, inventing a date, or silently doing
# nothing is not that gesture.
#
# ⛔ The compile line names TWO source files and no others. The rule must
# stay free of SwiftUI, SwiftData and Date(), or the only way to prove a
# random opening is to tap it.
#
#   ./tools/verify_fall_open.sh
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

let dates = ["2026-03-20", "2026-05-30", "2026-09-02"]
let segments = [12, 44, 90]

func fall(
    dates published: [String] = dates,
    segments ids: [Int] = segments,
    pick: @escaping (Int) -> Int
) -> FallOpen.Opening? {
    FallOpen.opening(publishedDates: published, segmentIDs: ids, pickIndex: pick)
}

// MARK: - A published minute wins over the bundled corpus

var pickedCount: Int?
check(
    fall(pick: { n in pickedCount = n; return 1 }) == .publishedMinute(dateString: "2026-05-30"),
    "a published minute is opened, not a bundled segment"
)
check(pickedCount == 3, "the pick is among the published dates, not the segments")

check(
    fall(pick: { _ in 0 }) == .publishedMinute(dateString: "2026-03-20"),
    "index 0 is the first published date"
)
check(
    fall(pick: { _ in 2 }) == .publishedMinute(dateString: "2026-09-02"),
    "the last published date is reachable"
)

// MARK: - No published minute: the bundled corpus is the book

pickedCount = nil
check(
    fall(dates: [], pick: { n in pickedCount = n; return 2 }) == .bundledSegment(id: 90),
    "with no published minute, a bundled segment opens: \(String(describing: fall(dates: [], pick: { _ in 2 })))"
)
check(pickedCount == 3, "the pick is among the bundled segments")

check(
    fall(dates: [""], pick: { _ in 0 }) == .bundledSegment(id: 12),
    "an empty date string is not a published minute"
)

// MARK: - Nothing to open

var pickCalled = false
check(
    fall(dates: [], segments: [], pick: { _ in pickCalled = true; return 0 }) == nil,
    "an empty book does not invent a page"
)
check(!pickCalled, "a pick is not asked of an empty book")

check(
    fall(dates: [], segments: [], pick: { $0 }) == nil,
    "nil stays nil whatever the picker would have returned"
)

if failures == 0 {
    print("\(checks) checks, the book falls open onto a page that exists")
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

if ! grep -q 'FallOpen.opening' "$REPO/ACIMDailyMinute/Views/Course/CourseView.swift"; then
    echo "CourseView never lets the book fall open"
    exit 1
fi
