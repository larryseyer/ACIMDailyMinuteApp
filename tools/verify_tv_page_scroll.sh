#!/bin/bash
# Proves a television page of a tall document lands on a real next offset,
# and that an arrow at either end returns nothing so focus can leave.
#
# What this guards is the companion note (and any other SwiftUI scroller) on
# tvOS. A ScrollView of Text has nothing the focus engine can walk, so the
# down arrow never moves a pixel; Get Started stays focused and the rest of
# the note is unreachable. The reading screens already page a UITextView by
# this same arithmetic. The note has to use it too, or a second copy of the
# rule will drift and one of the two will stop at the wrong place.
#
# ⛔ The compile line names ONE source file and no others. The pager must stay
# free of SwiftUI, or it can only be exercised by launching the television.
#
#   ./tools/verify_tv_page_scroll.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

var failures: [String] = []
func check(_ cond: Bool, _ message: String) {
    if !cond { failures.append(message) }
}

// 1000pt viewport, 28pt lines: 0.8 of the viewport is 800pt, which is
// 28 whole lines (784pt). That is the step the reading UITextView uses.
let line: CGFloat = 28
let view: CGFloat = 1000
let step = max((view * 0.8 / line).rounded(.down) * line, line)
check(step == 784, "step is 784pt, got \(step)")

// A note that fits on one screen: both arrows leave.
check(
    VerticalPager.page(current: 0, contentHeight: 800, viewportHeight: view, goingDown: true, lineHeight: line) == nil,
    "short content, down leaves"
)
check(
    VerticalPager.page(current: 0, contentHeight: 800, viewportHeight: view, goingDown: false, lineHeight: line) == nil,
    "short content, up leaves"
)

let tall: CGFloat = 3000
let maxY = tall - view // 2000

// Top of a long note.
check(
    VerticalPager.page(current: 0, contentHeight: tall, viewportHeight: view, goingDown: false, lineHeight: line) == nil,
    "at top, up leaves"
)
let first = VerticalPager.page(current: 0, contentHeight: tall, viewportHeight: view, goingDown: true, lineHeight: line)
check(first == 784, "at top, down pages one step, got \(String(describing: first))")

// Mid-note.
let second = VerticalPager.page(current: 784, contentHeight: tall, viewportHeight: view, goingDown: true, lineHeight: line)
check(second == 1568, "second page is 1568, got \(String(describing: second))")

// Last page must clamp, not overshoot.
let last = VerticalPager.page(current: 1568, contentHeight: tall, viewportHeight: view, goingDown: true, lineHeight: line)
check(last == maxY, "third page clamps to \(maxY), got \(String(describing: last))")
check(
    VerticalPager.page(current: maxY, contentHeight: tall, viewportHeight: view, goingDown: true, lineHeight: line) == nil,
    "at bottom, down leaves"
)

let upFromBottom = VerticalPager.page(current: maxY, contentHeight: tall, viewportHeight: view, goingDown: false, lineHeight: line)
check(upFromBottom == maxY - 784, "from bottom, up one step, got \(String(describing: upFromBottom))")

// A near-top offset still goes home rather than leaving.
let home = VerticalPager.page(current: 100, contentHeight: tall, viewportHeight: view, goingDown: false, lineHeight: line)
check(home == 0, "small up from 100 lands at 0, got \(String(describing: home))")

if !failures.isEmpty {
    fputs(failures.map { "FAIL: \($0)" }.joined(separator: "\n") + "\n", stderr)
    exit(1)
}
print("tv page scroll: \(8) cases")
SWIFT

swiftc -O -o "$WORK/verify" \
    "$REPO/ACIMDailyMinute/Utilities/VerticalPager.swift" \
    "$WORK/main.swift"
"$WORK/verify"
