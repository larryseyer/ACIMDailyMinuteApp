#!/bin/bash
# Proves a URL names a place that exists, including the Listen tab.
#
# What this guards is a tap that opens the wrong tab, or nowhere. Widgets,
# reminders and shared links all parse through DeepLinkRoute; a host the
# parser does not know is silently dropped, and the reader stays where they
# were with no explanation.
#
# ⛔ The compile line names ONE source file. The route table must stay free
# of SwiftUI and SwiftData, or the only way to prove a URL is to tap it.
#
#   ./tools/verify_deep_links.sh
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

func parse(_ string: String) -> DeepLinkRoute? {
    DeepLinkRoute.parse(URL(string: string)!)
}

check(parse("acimdailyminute://today") == .today, "today")
check(parse("acimdailyminute://lessons") == .lessons, "lessons")
check(parse("acimdailyminute://lesson/84") == .lesson(84), "lesson 84")
check(parse("acimdailyminute://lesson/0") == nil, "lesson 0 is not a lesson")
check(parse("acimdailyminute://lesson/366") == nil, "lesson 366 is not a lesson")
check(parse("acimdailyminute://listen") == .listen, "listen")
check(parse("acimdailyminute://saved") == .saved, "saved")
if case .archive(let d) = parse("acimdailyminute://archive/2026-09-10") {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    check(f.string(from: d) == "2026-09-10", "archive day is the URL's day")
} else {
    check(false, "archive/2026-09-10 must parse")
}
check(parse("acimdailyminute://nope") == nil, "unknown host is not a place")
check(parse("https://www.acimdailyminute.org/listen") == nil, "https is not an app link")

if failures == 0 {
    print("\(checks) checks, every URL names a place that exists")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/DeepLinkRoute.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"

if ! grep -q 'case .listen' "$REPO/ACIMDailyMinute/App/ContentView.swift"; then
    echo "ContentView never opens the Listen tab from a URL"
    exit 1
fi
