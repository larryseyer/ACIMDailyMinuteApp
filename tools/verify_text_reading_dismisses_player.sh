#!/bin/bash
# Proves a Workbook lesson in the mini player cannot remain under a Text
# chapter or section.
#
# What this guards: Listen on a lesson docks the mini player globally
# (ContentView shows it on Today, Video, and Saved). Opening Read > Text >
# a chapter then still showed that lesson at the bottom of the chapter page.
# The Text is a different book and has no audio of its own, so arriving on
# a chapter or section must dismiss the session. hasActiveAudio going false
# is what takes the overlay and the reserved inset with it.
#
#   ./tools/verify_text_reading_dismisses_player.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

@main
@MainActor
enum Harness {
    static func main() {
        setvbuf(stdout, nil, _IONBF, 0)

        var failures = 0
        var checks = 0
        func check(_ condition: Bool, _ message: @autoclosure () -> String) {
            checks += 1
            if !condition {
                failures += 1
                print("FAIL: \(message())")
            }
        }

        let audio = AudioManager()
        audio.hasActiveAudio = true
        audio.currentTitle = "Lesson 81"
        audio.currentURL = AudioManager.resolve("/audio/lesson-81.mp3")

        audio.dismissForTextReading()
        check(!audio.hasActiveAudio, "opening a Text page must dismiss the mini player")
        check(audio.currentTitle.isEmpty, "the previous lesson title must not remain")
        check(audio.currentURL.isEmpty, "the previous lesson URL must not remain")
        check(!audio.isActive(url: "/audio/lesson-81.mp3"), "the previous lesson must no longer own the session")

        audio.dismissForTextReading()
        check(!audio.hasActiveAudio, "dismiss on an idle player is a no-op")

        if failures == 0 {
            print("\(checks) checks")
            print("OK")
        } else {
            print("\(failures) FAILURE(S) of \(checks) checks")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
SWIFT

swiftc -O -parse-as-library \
    -framework AVFoundation \
    -framework MediaPlayer \
    "$REPO/ACIMDailyMinute/Utilities/PlaybackProgress.swift" \
    "$REPO/ACIMDailyMinute/Utilities/AudioTransport.swift" \
    "$REPO/ACIMDailyMinute/Services/PlaybackProgressStore.swift" \
    "$REPO/ACIMDailyMinute/Services/AudioManager.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"

fail() { echo "FAIL: $1"; exit 1; }

CHAPTER="$REPO/ACIMDailyMinute/Views/Text/TextChapterView.swift"
SECTION="$REPO/ACIMDailyMinute/Views/Text/TextSectionView.swift"

grep -q 'dismissForTextReading' "$CHAPTER" || fail "TextChapterView does not dismiss the mini player — a previous lesson would sit under the chapter"
grep -q 'dismissForTextReading' "$SECTION" || fail "TextSectionView does not dismiss the mini player — a previous lesson would sit under the section"

echo "Text chapter and section dismiss the previous lesson"
echo "OK"
