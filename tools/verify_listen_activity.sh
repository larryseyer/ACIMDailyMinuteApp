#!/bin/bash
# Proves Listen is activity rather than a second catalogue of the Course.
#
# What this guards is a tab that still lists every Minute and every Lesson
# the feed has ever published. That is Read's job. Listen has four buckets —
# now playing, part-finished, downloaded, finished — and an unplayed,
# undownloaded reading is not in the list.
#
#   ./tools/verify_listen_activity.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
VIEW="$REPO/ACIMDailyMinute/Views/Listen/ListenView.swift"
ROW="$REPO/ACIMDailyMinute/Views/Listen/PodcastEpisodeRow.swift"
PROGRESS="$REPO/ACIMDailyMinute/Utilities/PlaybackProgress.swift"

fail() { echo "FAIL: $1"; exit 1; }

# 1. The four buckets exist, in the order continue.md named them.
grep -q 'Section("Now Playing")' "$VIEW" || fail "ListenView has no Now Playing section"
grep -q 'Section("Part finished")' "$VIEW" || fail "ListenView has no Part finished section"
grep -q 'Section("Downloaded")' "$VIEW" || fail "ListenView has no Downloaded section"
grep -q 'Section("Finished")' "$VIEW" || fail "ListenView has no Finished section"

# 2. Empty activity is not "no episodes yet" — that is a catalogue empty state.
if grep -q 'No episodes yet' "$VIEW"; then
    fail "ListenView still has the catalogue empty state"
fi
grep -q 'Nothing to resume' "$VIEW" || fail "ListenView has no activity empty state"
grep -q 'Start a reading from Today or Read' "$VIEW" || fail "empty activity does not send the reader to Today or Read"

# 3. The Minute / Lessons picker organised the Course a second time.
if grep -q 'Picker("Feed"' "$VIEW"; then
    fail "ListenView still has the Minute/Lessons feed picker"
fi
if grep -q 'Daily Minute Playlist' "$VIEW"; then
    fail "ListenView still embeds the YouTube catalogue"
fi

# 4. Classification is the pure rule the harness already proves, not a view-local if.
grep -q 'ListenActivity.classify' "$VIEW" || fail "ListenView does not classify through ListenActivity"
grep -q 'enum ListenActivity' "$PROGRESS" || fail "ListenActivity is not in PlaybackProgress.swift"

# 5. A row still pauses the episode it started. The activity change must not
#    resurrect a play-only list.
grep -q 'ListenButton(' "$ROW" || fail "PodcastEpisodeRow does not use ListenButton"
grep -q 'playOrToggle' "$VIEW" || fail "ListenView never calls playOrToggle"
grep -q 'episodeID:' "$VIEW" || fail "ListenView plays without an episode identity — progress cannot resume"

echo "Listen is activity, not a catalogue"
echo "OK"
