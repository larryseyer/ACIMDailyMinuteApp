#!/bin/bash
# Proves the medium band is one control that never changes shape: three
# segments always present, Listen gated on audio, Watch gated on a YouTube
# id or compose, unavailable segments dimmed to 32%.
#
# Compiles ReadingMedium in isolation (Foundation only) and greps the view
# for the measurements the mockup pinned. No SwiftData — a band that needs
# the store cannot be checked without launching the app.
#
#   ./tools/verify_medium_band.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$REPO/ACIMDailyMinute/Views/Reading/MediumBand.swift"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$SRC" ] || fail "MediumBand.swift is missing"

STRIPPED="$(sed 's://.*::' "$SRC")"
echo "$STRIPPED" | grep -qE 'import[[:space:]]+SwiftData' \
    && fail "MediumBand.swift must not import SwiftData"

echo "$STRIPPED" | grep -q '"Read"' || fail "the band must name Read"
echo "$STRIPPED" | grep -q '"Listen"' || fail "the band must name Listen"
echo "$STRIPPED" | grep -q '"Watch"' || fail "the band must name Watch"
echo "$STRIPPED" | grep -q '0.32' || fail "unavailable opacity must be 0.32"
echo "$STRIPPED" | grep -q 'height: 58' || fail "the band must be 58pt tall"
echo "$STRIPPED" | grep -q '29' || fail "the band radius must be 29"
echo "$STRIPPED" | grep -q '24' || fail "segment radius must be 24"

python3 - "$SRC" "$WORK" <<'PY'
import sys
src = open(sys.argv[1]).read()
start = src.find("struct ReadingMedium")
if start < 0:
    sys.exit("FAIL: could not extract struct ReadingMedium")
i = src.find("{", start)
depth = 0
end = None
for j in range(i, len(src)):
    if src[j] == "{":
        depth += 1
    elif src[j] == "}":
        depth -= 1
        if depth == 0:
            end = j + 1
            break
if end is None:
    sys.exit("FAIL: could not extract struct ReadingMedium")
open(sys.argv[2] + "/ReadingMedium.swift", "w").write("import Foundation\n\n" + src[start:end] + "\n")
PY

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures: [String] = []
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

let silent = ReadingMedium(title: "Lesson 84")
check(silent.showsListen == false, "no audio means Listen is unavailable")
check(silent.showsWatch == false, "no video and no compose means Watch is unavailable")
check(silent.isAvailable(.read), "Read is always available")
check(!silent.isAvailable(.listen), "Listen must follow showsListen")
check(!silent.isAvailable(.watch), "Watch must follow showsWatch")

let audio = ReadingMedium(title: "Lesson 84", audioURL: "https://example/a.mp3")
check(audio.showsListen, "audio means Listen")
check(!audio.showsWatch, "audio alone is not Watch")

let youtube = ReadingMedium(title: "Lesson 84", youtubeID: "abc")
check(!youtube.showsListen, "a video id is not Listen")
check(youtube.showsWatch, "a video id means Watch")

let compose = ReadingMedium(title: "T-1.1", canCompose: true)
check(!compose.showsListen, "compose is not Listen")
check(compose.showsWatch, "compose means Watch")

let both = ReadingMedium(
    title: "Daily Minute",
    audioURL: " https://example/a.mp3 ",
    youtubeID: " xyz "
)
check(both.showsListen, "whitespace around an audio URL still counts")
check(both.showsWatch, "whitespace around a video id still counts")

let empty = ReadingMedium(title: "x", audioURL: "  ", youtubeID: "  ")
check(!empty.showsListen, "whitespace-only audio is not Listen")
check(!empty.showsWatch, "whitespace-only video is not Watch")

if failures.isEmpty {
    print("\(checks) checks, the band never changes shape")
    print("OK")
    exit(0)
}
for f in failures { print("FAIL: \(f)") }
print("\(failures.count) FAILURE(S) of \(checks) checks")
exit(1)
SWIFT

swiftc -O \
    "$WORK/ReadingMedium.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"
echo "OK"
