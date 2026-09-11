#!/bin/bash
# Proves the Video tab plays YouTube on iPhone/iPad/Mac, and that the
# television still builds its picture from the MP3 — it has no WebKit.
#
# What this guards is a day that opens as a reading with a Listen button.
# The tab exists to play the video. Audio is the Listen tab. The Course
# text is the Read tab. A long-press "Watch video" on Listen is not a
# Video tab.
#
#   ./tools/verify_video_tab.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$REPO/ACIMDailyMinute/Views/Archive/ArchiveDateDetailView.swift"
IDS="$REPO/ACIMDailyMinute/Utilities/YouTubeID.swift"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$FILE" ]] || fail "ArchiveDateDetailView.swift missing"

# Television: still the MP3-built player. No YouTube embed.
grep -q 'openPlayer' "$FILE" \
    || fail "tvOS Video day no longer opens the MP3-built player"

# Phone, iPad, Mac: the day is a YouTube player.
grep -q 'LiteYouTubeCard' "$FILE" \
    || fail "iOS/macOS Video day has no YouTube player"

# Bare ids and watch URLs both resolve — archive rows ship one, the
# podcast <link> ships the other.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation
func check(_ cond: Bool, _ msg: String) { if !cond { fputs("FAIL: \(msg)\n", stderr); exit(1) } }
check(YouTubeID.resolve("2_eAO5jBbHM") == "2_eAO5jBbHM", "bare id")
check(YouTubeID.resolve("https://www.youtube.com/watch?v=SlAhY7QszJo") == "SlAhY7QszJo", "watch URL")
check(YouTubeID.resolve("https://youtu.be/Spt75SO4HhE") == "Spt75SO4HhE", "short URL")
check(YouTubeID.resolve("") == nil, "empty")
check(YouTubeID.resolve(nil) == nil, "nil")
print("youtube ids resolve")
print("OK")
SWIFT
swiftc -O "$IDS" "$WORK/main.swift" -o "$WORK/verify"
"$WORK/verify"

echo "Video tab plays YouTube off the television"
echo "OK"
