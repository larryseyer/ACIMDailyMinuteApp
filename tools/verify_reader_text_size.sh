#!/bin/bash
# Proves the reading-body size choice is three named multipliers on
# preferredFont(.body), and nothing else.
#
# What this guards is a setting that looks like it did something while the
# words stayed the same size. Titles, captions and chrome are not this
# setting; a multiplier applied to the wrong font, or a Default that is
# not 1.0, would change the book without the reader asking.
#
# ⛔ The compile line names ONE source file. The type must stay free of
# SwiftUI, SwiftData, Bundle and CorpusService so the numbers can be
# checked without launching the app.
#
#   ./tools/verify_reader_text_size.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

if sed 's://.*::' "$REPO/ACIMDailyMinute/Utilities/ReaderTextSize.swift" \
    | grep -qE '^[[:space:]]*import[[:space:]]+(SwiftUI|SwiftData)|Bundle\.|CorpusService'; then
    fail "ReaderTextSize.swift imports a UI or storage framework, or names Bundle or CorpusService"
fi

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures: [String] = []
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

check(ReaderTextSize.allCases.map(\.rawValue) == ["default", "large", "larger"],
      "cases must be default, large, larger in that order")
check(ReaderTextSize.allCases.map(\.label) == ["Default", "Large", "Larger"],
      "labels must be Default, Large, Larger")
check(ReaderTextSize.key == "readerTextSize", "AppStorage key")

check(ReaderTextSize.default.multiplier == 1.0, "Default is 1.0, the current body")
check(ReaderTextSize.large.multiplier == 1.25, "Large is 1.25")
check(ReaderTextSize.larger.multiplier == 1.5, "Larger is 1.5")

check(ReaderTextSize.resolved("nope") == .default, "an unknown raw value is Default")
check(ReaderTextSize.resolved("large") == .large, "large resolves")

// The body size is preferredFont(.body) times the multiplier. 17 is iOS
// body; 13 is macOS body. Both must scale, or Mac's Default would be
// a no-op while Large jumped from a different base.
check(ReaderTextSize.scaledBodySize(base: 17, raw: "default") == 17, "iOS Default")
check(ReaderTextSize.scaledBodySize(base: 17, raw: "large") == 21.25, "iOS Large")
check(ReaderTextSize.scaledBodySize(base: 17, raw: "larger") == 25.5, "iOS Larger")
check(ReaderTextSize.scaledBodySize(base: 13, raw: "default") == 13, "Mac Default")
check(ReaderTextSize.scaledBodySize(base: 13, raw: "large") == 16.25, "Mac Large")
check(ReaderTextSize.scaledBodySize(base: 13, raw: "larger") == 19.5, "Mac Larger")

if failures.isEmpty {
    print("\(checks) checks, Default is 1.0 on preferredFont(.body)")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Utilities/ReaderTextSize.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify"

# The picker and the body renderer must share the key, and tvOS must not
# offer the control. Grep, because a second literal is how they drift.
grep -q 'ReaderTextSize.key' "$REPO/ACIMDailyMinute/Views/Settings/SettingsView.swift" \
    || fail "Settings does not bind ReaderTextSize"
grep -q 'Text size' "$REPO/ACIMDailyMinute/Views/Settings/SettingsView.swift" \
    || fail "Settings has no Text size picker"
grep -q 'os(tvOS)' "$REPO/ACIMDailyMinute/Views/Settings/SettingsView.swift" \
    || fail "Settings no longer fences tvOS"

grep -q 'sizeMultiplier' "$REPO/ACIMDailyMinute/Views/SelectableReadingText.swift" \
    || fail "SelectableReadingText does not take a size multiplier"

echo "reader text size is three multipliers on the body"
echo "OK"
