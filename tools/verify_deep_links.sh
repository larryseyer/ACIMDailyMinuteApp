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
if case .archive(let d) = parse("acimdailyminute://video/2026-09-10") {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    check(f.string(from: d) == "2026-09-10", "video day is the URL's day")
} else {
    check(false, "video/2026-09-10 must parse")
}
if case .archive(let d) = parse("acimdailyminute://archive/2026-09-10") {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    check(f.string(from: d) == "2026-09-10", "archive day still names the same place")
} else {
    check(false, "archive/2026-09-10 must still parse")
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
if ! grep -q 'case .archive' "$REPO/ACIMDailyMinute/App/ContentView.swift"; then
    echo "ContentView never opens the Video tab from a URL"
    exit 1
fi
if ! grep -q 'Label("Video"' "$REPO/ACIMDailyMinute/App/ContentView.swift"; then
    echo "the Video tab is not labelled Video"
    exit 1
fi
if grep -q 'Label("Archive"' "$REPO/ACIMDailyMinute/App/ContentView.swift"; then
    echo "the Video tab is still labelled Archive"
    exit 1
fi
if ! grep -q 'title: "Video"' "$REPO/ACIMDailyMinute/App/ContentView.swift"; then
    echo "the Mac tab bar does not name Video"
    exit 1
fi
if ! grep -q 'navigationTitle("Video")' "$REPO/ACIMDailyMinute/Views/Archive/ArchiveView.swift"; then
    echo "the Video tab's navigation title is not Video"
    exit 1
fi
if grep -q 'navigationTitle("Archive")' "$REPO/ACIMDailyMinute/Views/Archive/ArchiveView.swift"; then
    echo "the Video tab's navigation title is still Archive"
    exit 1
fi
if ! grep -q '("play.rectangle", "Video"' "$REPO/ACIMDailyMinute/Views/Onboarding/OnboardingView.swift"; then
    echo "the introduction never names the Video tab"
    exit 1
fi
if grep -q '"Archive"' "$REPO/ACIMDailyMinute/Views/Onboarding/OnboardingView.swift"; then
    echo "the introduction still names the Archive tab"
    exit 1
fi
if ! grep -q 'final class ArchiveService' "$REPO/ACIMDailyMinute/Services/ArchiveService.swift"; then
    echo "ArchiveService was renamed; it talks to the feed archive, not the tab"
    exit 1
fi
if ! grep -q 'final class ArchivedReading' "$REPO/ACIMDailyMinute/Models/ArchivedReading.swift"; then
    echo "ArchivedReading was renamed; it is the feed row, not the tab"
    exit 1
fi
if ! grep -q 'archive.org' "$REPO/ACIMDailyMinute/Utilities/LessonNarration.swift"; then
    echo "archive.org hosting was stripped from lesson narration"
    exit 1
fi
