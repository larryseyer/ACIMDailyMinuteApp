#!/bin/bash
# Proves every reading has one shape: a running head that keeps the address
# in view, the citation never wrapping, and no surface assembling its own bands.
#
# The uppercase eyebrow over a play + Share + Save row is gone. This script
# now holds the running head (parent leading, citation trailing) and the
# scaffold still owning every surface.
#
#   ./tools/verify_card_header.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import SwiftUI
import AppKit

setvbuf(stdout, nil, _IONBF, 0)

struct FrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, b in b }
    }
}

extension View {
    func tracked(_ name: String, _ space: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: FrameKey.self, value: [name: g.frame(in: .named(space))])
        })
    }
}

@MainActor
func layout(parent: String, citation: String?, width: CGFloat) -> [String: CGRect] {
    var out: [String: CGRect] = [:]
    let header = CardHeaderRow(parent: parent, citation: citation) {
    } trailing: {
    }
    let probe = header
        .tracked("all", "hdr")
        .coordinateSpace(name: "hdr")
        .frame(width: width)
        .onPreferenceChange(FrameKey.self) { out = $0 }
    let renderer = ImageRenderer(content: probe)
    renderer.scale = 2
    _ = renderer.nsImage
    return out
}

var failures = 0
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 20 { print("  \(message())") }
    }
}

MainActor.assumeIsolated {
    let widths: [CGFloat] = [240, 280, 303, 342, 500, 672]
    let citations = ["W-84", "W-365", "T-31.8", "Pref.4", "M-4.1"]

    let reference = layout(parent: "Workbook", citation: "W-84", width: 303)["all"]!.height
    check(reference > 20 && reference < 70,
          "the running head is \(reference)pt tall — that is not parent + citation + rule")

    for width in widths {
        let f = layout(parent: "Workbook", citation: "W-84", width: width)
        guard let all = f["all"] else {
            check(false, "Workbook at \(Int(width))pt: the header did not lay out")
            continue
        }
        check(all.width <= width + 0.5,
              "\(Int(width))pt: the running head is \(all.width)pt inside a \(Int(width))pt card")
        check(abs(all.height - reference) < 8,
              "\(Int(width))pt: \(all.height)pt vs \(reference)pt — the head changed shape")
    }

    for citation in citations {
        let f = layout(parent: "Review II", citation: citation, width: 303)
        guard let all = f["all"] else {
            check(false, "citation \(citation) did not lay out")
            continue
        }
        check(abs(all.height - reference) < 8,
              "citation \(citation) is \(all.height)pt, not \(reference)pt — it wrapped at 303pt")
        check(all.width <= 303 + 0.5,
              "citation \(citation): the block is \(all.width)pt inside a 303pt card")
    }

    let parents = [
        "Workbook", "Review II", "Daily Minute", "Manual", "Preface",
        "Text", "Introduction"
    ]
    for parent in parents {
        let f = layout(parent: parent, citation: "W-84", width: 303)
        guard let all = f["all"] else {
            check(false, "parent \(parent.debugDescription) did not lay out")
            continue
        }
        check(all.width <= 303 + 0.5,
              "parent \(parent.debugDescription): the block is \(all.width)pt inside a 303pt card")
    }

    if failures == 0 {
        print("\(checks) checks, the running head keeps the address in view")
        print("OK")
    } else {
        print("\(failures) FAILURE(S) of \(checks) checks")
    }
    exit(failures == 0 ? 0 : 1)
}
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Views/CardHeaderRow.swift" \
    "$REPO/ACIMDailyMinute/Views/CitationLabel.swift" \
    "$REPO/ACIMDailyMinute/Views/ACIMColors.swift" \
    "$REPO/ACIMDailyMinute/Utilities/ACIMType.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"

VIEWS="$REPO/ACIMDailyMinute/Views"

SURFACES="
Today/DailyMinuteCard.swift
Today/CorpusReadingCard.swift
Archive/ArchivedReadingCard.swift
Lessons/LessonDetailView.swift
Lessons/WorkbookIntroductionView.swift
Text/TextSectionView.swift
Manual/ManualSegmentView.swift
Segment/SegmentReadingView.swift
"
for surface in $SURFACES; do
    if ! grep -q 'ReadingScaffold(' "$VIEWS/$surface"; then
        echo "FAIL: $surface draws a reading without ReadingScaffold"
        exit 1
    fi
done

HEADER_USERS="$(grep -rln 'CardHeaderRow(' "$VIEWS" | grep -v 'ReadingScaffold.swift' | grep -v 'CardHeaderRow.swift' || true)"
if [ -n "$HEADER_USERS" ]; then
    echo "FAIL: these reach past the scaffold to the header directly:"
    echo "$HEADER_USERS"
    exit 1
fi

if grep -q 'textCase(.uppercase)' "$VIEWS/CardHeaderRow.swift"; then
    echo "FAIL: CardHeaderRow still draws an uppercase eyebrow"
    exit 1
fi
if ! grep -q 'CitationLabel' "$VIEWS/CardHeaderRow.swift"; then
    echo "FAIL: CardHeaderRow must draw the citation through CitationLabel"
    exit 1
fi

for word in Listen Pause Play; do
    if ! grep -q "\"$word\"" "$VIEWS/ListenButton.swift"; then
        echo "FAIL: ListenButton lost the $word label"
        exit 1
    fi
done
INLINE_LISTEN="$(grep -rEln 'Label\("(Listen|Stop|Pause|Play)", systemImage:' "$VIEWS" --include='*.swift' \
    | grep -v 'ListenButton.swift' || true)"
if [ -n "$INLINE_LISTEN" ]; then
    echo "FAIL: a Listen control is hand-rolled in:"
    echo "$INLINE_LISTEN"
    exit 1
fi

echo "the scaffold owns the bands: 8 reading surfaces, running head, no uppercase eyebrow, no hand-rolled Listen"
echo "OK"
