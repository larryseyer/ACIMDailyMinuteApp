#!/bin/bash
# Proves the header Listen control can tell which reading owns the mini player,
# and that a tap on that reading pauses rather than dismissing the session.
#
# What this guards is a Pause that appears on the wrong card. Every Daily Minute
# is titled "Daily Minute", so matching on the title would paint Pause on a
# different day's header. Identity is the resolved URL. Relative feed paths
# and their absolute host form are the same session; two different paths are not.
#
# The header matches the mini player: play/pause, not Stop. playOrToggle on the
# active URL must leave the session up. stop() still clears it. play() itself
# is not called — it would construct an AVPlayer — because this harness is
# about identity, not playback.
#
#   ./tools/verify_listen_session.sh
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
        let relative = "/audio/a.mp3"
        let absolute = "https://www.acimdailyminute.org/audio/a.mp3"
        let other = "/audio/b.mp3"

        check(!audio.isActive(url: relative), "an idle player must not match a URL")
        check(audio.currentURL.isEmpty, "an idle player has no current URL")

        audio.hasActiveAudio = true
        audio.currentURL = AudioManager.resolve(relative)
        audio.currentTitle = "Daily Minute"

        check(audio.isActive(url: relative), "the stored session must match its relative URL")
        check(audio.isActive(url: absolute), "the stored session must match the absolute form of the same path")
        check(!audio.isActive(url: other), "a different path is a different session")
        check(
            AudioManager.resolve(relative) == AudioManager.resolve(absolute),
            "resolve() must collapse the relative path and its host form"
        )

        audio.isPlaying = true
        audio.playOrToggle(url: relative, title: "Daily Minute")
        check(audio.hasActiveAudio, "playOrToggle on the active URL must not dismiss the mini player")
        check(audio.isActive(url: relative), "playOrToggle on the active URL must keep the session")
        check(audio.currentTitle == "Daily Minute", "playOrToggle must not clear the title")
        check(!audio.isActive(url: other), "a different path is still a different session")

        audio.hasActiveAudio = true
        audio.currentURL = AudioManager.resolve(relative)
        audio.stop()
        check(!audio.hasActiveAudio, "stop() must clear hasActiveAudio")
        check(audio.currentURL.isEmpty, "stop() must clear currentURL")
        check(!audio.isActive(url: relative), "stop() must make isActive false")

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
