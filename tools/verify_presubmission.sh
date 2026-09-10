#!/bin/bash
# Proves a surface that does not have a fact does not print one.
#
# What this guards is a sentence the app states and the reader believes.
# A missing lesson number rendered as "Lesson 0", or an availability date
# counted from Date() because the publisher's day was absent, is not a
# crash. It is a reading that never existed, offered as if it did.
#
#   ./tools/verify_presubmission.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

check() {
    local message="$1"
    shift
    if "$@"; then
        :
    else
        echo "  $message"
        fail=$((fail + 1))
    fi
}

# A missing lesson number is not lesson 0. 0 is the Workbook introduction.
if grep -n 'lessonNumber ?? 0' \
    "$REPO/ACIMDailyMinute/Views/Archive/ArchiveView.swift" \
    "$REPO/ACIMDailyMinute/Views/Saved/BookmarkRow.swift" \
    "$REPO/ACIMDailyMinute/Utilities/ShareTextBuilder.swift"
then
    echo "  a missing lesson number is being printed as 0"
    fail=$((fail + 1))
fi

if grep -n 'latestPublishedAt ?? Date()' \
    "$REPO/ACIMDailyMinute/Views/Lessons/LessonsView.swift"
then
    echo "  an availability date is being counted from Date() instead of the publisher's day"
    fail=$((fail + 1))
fi

# Widget views must not stamp when a minute was published. The entry may
# still carry the instant for timeline math; the drawing must not.
if grep -n 'publishedAt' \
    "$REPO/ACIMDailyMinuteWidget/SmallWidgetView.swift" \
    "$REPO/ACIMDailyMinuteWidget/MediumWidgetView.swift" \
    "$REPO/ACIMDailyMinuteWidget/LargeWidgetView.swift"
then
    echo "  a widget is drawing a publication date"
    fail=$((fail + 1))
fi

if [[ $fail -eq 0 ]]; then
    echo "surfaces that lack a fact do not print one"
    echo "OK"
    exit 0
fi
echo "$fail FAILURE(S)"
exit 1
