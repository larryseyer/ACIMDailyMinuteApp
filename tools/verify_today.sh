#!/bin/bash
# Proves Today is a page: the passage sits on ink, the lesson is a summary
# card, the citation is W-N, and the practice card reads the planner.
#
# Grep, not a launch: the layout is what a screenshot would catch after the
# fact. These strings are the decisions that would otherwise silently revert
# to a grey rounded rectangle.
#
#   ./tools/verify_today.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TODAY="$REPO/ACIMDailyMinute/Views/Today"
fail() { echo "FAIL: $1"; exit 1; }

MINUTE="$TODAY/DailyMinuteCard.swift"
CORPUS="$TODAY/CorpusReadingCard.swift"
LESSON="$TODAY/DailyLessonCard.swift"
VIEW="$TODAY/TodayView.swift"

# The passage is a page. Card fill and the old 12pt radius have to be gone
# from both twins, or they disagree the next time one is edited.
for f in "$MINUTE" "$CORPUS"; do
    grep -q 'Color.acimCard' "$f" && fail "$(basename "$f") still fills acimCard"
    grep -q 'cornerRadius: 12' "$f" && fail "$(basename "$f") still rounds at 12"
    grep -q 'ReadingScaffold(' "$f" || fail "$(basename "$f") left the scaffold"
    grep -q 'AnnotatableReadingText' "$f" || fail "$(basename "$f") lost the reading"
    grep -q 'Metric.readingGap' "$f" || fail "$(basename "$f") does not set the reading gap"
done

# The lesson card is no longer a reading of the body.
grep -q 'ReadingScaffold(' "$LESSON" && fail "DailyLessonCard is still a reading surface"
grep -q 'AnnotatableReadingText' "$LESSON" && fail "DailyLessonCard still draws the lesson body"
grep -q 'CitationLabel' "$LESSON" || fail "DailyLessonCard has no CitationLabel"
grep -Fq 'W-\(' "$LESSON" || fail "DailyLessonCard does not address the lesson as W-N"
grep -q 'W-r' "$LESSON" && fail "DailyLessonCard renders a review as part of the address"
grep -q 'WorkbookBodiesCatalog.reviewTitle' "$LESSON" || fail "DailyLessonCard does not ask for the review grouping"
grep -q 'todaySurfaceCard' "$LESSON" || fail "DailyLessonCard is not a surface card"

# Masthead lives in the content; the nav title is empty and inline.
grep -q 'TodayMasthead' "$VIEW" || fail "TodayView has no masthead"
grep -q 'navigationTitle("")' "$VIEW" || fail "TodayView still titles the nav chrome"
grep -q 'navigationBarTitleDisplayMode(.inline)' "$VIEW" || fail "TodayView is not inline"
grep -q 'Metric.gutter' "$VIEW" || fail "TodayView does not use Metric.gutter"
grep -q 'PracticeCard' "$VIEW" || fail "TodayView has no practice card"
grep -q 'buttonStyle(.card)' "$VIEW" && fail "TodayView still wraps the page in a tvOS card"

# Action row: gold Listen, visible Watch, no hand-rolled Listen label.
grep -q 'TodayActionRow' "$MINUTE" || fail "DailyMinuteCard has no action row"
grep -q 'TodayActionRow' "$CORPUS" && fail "CorpusReadingCard grew actions for a passage with no identity"
if grep -Eln 'Label\("(Listen|Stop|Pause|Play)", systemImage:' "$TODAY"/*.swift; then
    fail "Today hand-rolled a Listen control"
fi

# Practice card is a surface over the planner, not a scheduler.
PRACTICE="$TODAY/PracticeCard.swift"
[[ -f "$PRACTICE" ]] || fail "PracticeCard.swift is missing"
grep -q 'PracticePlanner' "$PRACTICE" || fail "PracticeCard does not read PracticePlanner"
grep -q 'cadenceSummary' "$PRACTICE" || fail "PracticeCard does not use cadenceSummary"
grep -q 'WorkbookPracticeCatalog' "$PRACTICE" || fail "PracticeCard does not read the catalog"
grep -q 'UNUserNotification' "$PRACTICE" && fail "PracticeCard reached into notifications"

# Review grouping: lesson 84 is Review II, never part of the address.
python3 - "$REPO" <<'PY'
import json, sys
from pathlib import Path
repo = Path(sys.argv[1])
rows = json.loads((repo / "ACIMDailyMinute/Resources/WorkbookIntroductions.json").read_text())
reviews = sorted(
    [(r["title"], r["insertBefore"]) for r in rows if r["title"].startswith("Review ")],
    key=lambda x: x[1],
)
def title_for(n):
    hit = None
    for title, before in reviews:
        if before <= n:
            hit = title
    return hit
cases = {20: None, 50: None, 51: "Review I", 80: "Review I", 81: "Review II", 84: "Review II", 110: "Review II", 111: "Review III"}
for lesson, expected in cases.items():
    got = title_for(lesson)
    if got != expected:
        print(f"FAIL: lesson {lesson} grouped as {got!r}, expected {expected!r}")
        sys.exit(1)
print("review grouping: 84 is Review II")
PY

grep -q 'func reviewTitle' "$REPO/ACIMDailyMinute/Services/WorkbookBodiesCatalog.swift" \
    || fail "WorkbookBodiesCatalog has no reviewTitle"

echo "Today is a page: no card on the passage, lesson is a summary, W-N, planner-only practice"
echo "OK"
