#!/bin/bash
# Proves a macOS reading scrolls to a search hit and to the ribbon.
#
# What this guards is a spotlight or a ribbon that opens the right passage
# and then sits at the top of it. The iOS half walks up to the SwiftUI
# ScrollView and asks that scroller. The macOS half used to call
# NSTextView.scrollToVisible, which — when the representable is not yet
# inside a clip view — moves the text view's own bounds over its title.
# Swallowing those calls stopped the overlap and also stopped the scroll.
# The clip view is the thing that must move, the same way UIScrollView
# is on the phone, and it is asked only after it exists.
#
#   ./tools/verify_mac_reading_scroll.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$REPO/ACIMDailyMinute/Views/SelectableReadingText.swift"

fail() { echo "FAIL: $1"; exit 1; }

# Bounded to the AppKit representable so an iOS comment about scrolling
# cannot satisfy this.
MAC="$(awk '/^#elseif os\(macOS\)$/,/^#endif$/' "$FILE")"
[[ -n "$MAC" ]] || fail "no macOS representable in SelectableReadingText.swift"

echo "$MAC" | grep -q 'Nothing scrolls here' \
    && fail "macOS representable still refuses to scroll"

echo "$MAC" | grep -q 'open a macOS reading at its top' \
    && fail "macOS representable still leaves spotlight and ribbon at the top"

echo "$MAC" | grep -q 'scrolledSpotlight' \
    || fail "macOS Coordinator does not remember the spotlight it already scrolled to"

echo "$MAC" | grep -q 'scrolledResume' \
    || fail "macOS Coordinator does not remember the ribbon it already scrolled to"

# Swift's NSView.scroll takes a point, not a rectangle. The clip view is
# asked through super.scrollToVisible, and only after enclosingScrollView
# exists. The override on ReadingNSTextView must stay so a too-early call
# cannot paint the body over the title.
echo "$MAC" | grep -q 'scrollEnclosingClip' \
    || fail "macOS representable has no enclosed-clip scroll"

echo "$MAC" | grep -q 'super.scrollToVisible' \
    || fail "macOS enclosed-clip scroll never asks the clip view"

echo "$MAC" | grep -qE '[^.]view\.scrollToVisible' \
    && fail "macOS representable still calls scrollToVisible on the text view"

echo "$MAC" | grep -q 'enclosingScrollView' \
    || fail "macOS scroll does not wait for the enclosing NSScrollView"

# The reporter used to read the text view's own visibleRect, which is
# the whole passage when SwiftUI is the scroller, so every ribbon saved
# offset 0.
echo "$MAC" | awk '/func installReporter/,/^    }/' | grep -q 'enclosingScrollView' \
    || fail "macOS position reporter does not read the enclosing scroller"

echo "$MAC" | awk '/func installReporter/,/^    }/' | grep -q 'documentVisibleRect' \
    || fail "macOS position reporter does not read the clip view's visible rect"

echo "macOS readings scroll the clip view, not the text view"
echo "OK"
