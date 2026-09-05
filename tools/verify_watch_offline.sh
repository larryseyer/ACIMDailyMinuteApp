#!/bin/bash
# ⛔ The only check that guards what the WATCH can say with no phone and no
# network.
#
# The durability rule says the app must be wholly usable on bundled content
# alone. Every other target keeps that promise because its Resources phase
# carries the corpus. The watch is the one that did not: its entire content was
# a four-key `WCSession` payload, so an unpaired watch, or a watch whose phone
# had not opened the app, had nothing at all to show.
#
# ⛔ **And the failure mode is silent.** `CorpusService.load()` returns `[]` for
# a file it cannot find in the bundle — no crash, no log, no warning. A corpus
# JSON dropped from the watch's Resources phase therefore compiles green, ships,
# and shows an empty screen on a wrist. No other check in this repo can see it,
# because every other check reads the files from `ACIMDailyMinute/Resources/`
# directly rather than through the bundle the watch actually gets.
#
# So this one builds a directory holding EXACTLY the JSON files the watch target
# names in its own Resources phase, and asks `CorpusFallback` to answer out of
# that and nothing else. If the phase and the code path ever disagree, the
# fallback comes back nil here rather than blank on his wrist.
#
# It guards three more things the watch depends on and nothing else states:
#   - that the watch's own source list still COMPILES for watchOS at all;
#   - that the watch never opens the reader's store, which today is a comment;
#   - that the watch target carries no iCloud entitlement.
#
#   ./tools/verify_watch_offline.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"
WATCH_TARGET="ACIMDailyMinuteWatch Watch App"

# ── Read the watch target's real phases out of the project file ──────────────
# Not a hardcoded phase id: the point is to follow whatever the target actually
# compiles and copies today, so that adding a file to the watch brings it under
# this check automatically.
/usr/bin/python3 - "$PROJECT" "$WATCH_TARGET" "$WORK" <<'PARSE'
import re, sys
from pathlib import Path

project, target_name, work = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
text = project.read_text(encoding="utf-8")

# The native target block, then the phase ids it lists.
#
# ⛔ Each target block is isolated FIRST and matched by name second. A single
# lazy regex from `isa = PBXNativeTarget;` to the wanted `name =` spans every
# target declared before it and hands back the first target's phases under the
# last target's name — which is a green check measuring the wrong target.
blocks = re.findall(r"\{\s*\n\t\t\tisa = PBXNativeTarget;.*?\n\t\t\};", text, re.S)
target = next(
    (b for b in blocks
     if re.search(r"\n\t\t\tname = \"?" + re.escape(target_name) + r"\"?;", b)),
    None)
if not target:
    sys.exit(f"FAIL: no PBXNativeTarget named {target_name!r}")
phases = re.search(r"buildPhases = \((.*?)\);", target, re.S)
if not phases:
    sys.exit("FAIL: the watch target lists no build phases")
phase_ids = re.findall(r"([0-9A-Za-z]{10,})\s*/\*", phases.group(1))

def files_in(phase_id):
    """The basenames a build phase names, in order.

    ⛔ The phase's own comment may hold spaces — `Embed Foundation Extensions`
    and `Embed Watch Content` both do — so it is matched as "anything but a
    star", never as `\\w+`.
    """
    block = re.search(
        re.escape(phase_id) + r" /\* [^*]+ \*/ = \{(.*?)\n\t\t\};", text, re.S)
    if not block:
        sys.exit(f"FAIL: build phase {phase_id} not found")
    body = block.group(1)
    kind = re.search(r"isa = (\w+);", body).group(1)
    names = re.findall(r"/\* (.+?) in [^*]+ \*/", body)
    return kind, names

sources, resources = [], []
for pid in phase_ids:
    kind, names = files_in(pid)
    if kind == "PBXSourcesBuildPhase":
        sources = names
    elif kind == "PBXResourcesBuildPhase":
        resources = names

if not sources:
    sys.exit("FAIL: the watch target has no Sources phase")
if not resources:
    sys.exit("FAIL: the watch target has no Resources phase")

# ⛔ Trailing newline, deliberately. `while read` drops a final line that is not
# newline-terminated, so a join alone silently omits the LAST file of each list —
# and the last file is the one most recently added, which is exactly the one a
# check like this exists to catch.
(work / "sources.txt").write_text("\n".join(sources) + "\n", encoding="utf-8")
(work / "resources.txt").write_text("\n".join(resources) + "\n", encoding="utf-8")
print(f"watch target compiles {len(sources)} files and copies {len(resources)} resources")
PARSE

# ── Resolve each compiled basename to a real path, failing loud on ambiguity ─
: > "$WORK/source_paths.txt"
while IFS= read -r name; do
    [ -n "$name" ] || continue
    matches="$(find "$REPO/ACIMDailyMinute" "$REPO/ACIMDailyMinuteWatch" "$REPO/ACIMDailyMinuteWidget" \
        -name "$name" -type f)"
    count="$(printf '%s\n' "$matches" | grep -c . || true)"
    if [ "$count" -ne 1 ]; then
        echo "FAIL: the watch compiles '$name', which resolves to $count files on disk"
        printf '%s\n' "$matches"
        exit 1
    fi
    printf '%s\n' "$matches" >> "$WORK/source_paths.txt"
done < "$WORK/sources.txt"

# ── 1. The watch's own source list still compiles FOR watchOS ───────────────
# ⛔ `-wmo` is not optional here. Plain batch-mode `-typecheck` stops after the
# first file that fails and reports one error where there are dozens — a sweep
# written without it passes for the wrong reason.
WATCH_SDK="$(xcrun --sdk watchsimulator --show-sdk-path)"
if ! swiftc -typecheck -wmo \
        -sdk "$WATCH_SDK" \
        -target arm64-apple-watchos10.0-simulator \
        $(cat "$WORK/source_paths.txt") > "$WORK/typecheck.log" 2>&1; then
    echo "FAIL: the watch target's source list does not typecheck against the watchOS SDK"
    grep "error:" "$WORK/typecheck.log" | head -20
    exit 1
fi

# ── 2. A directory holding EXACTLY what the watch's Resources phase names ───
# This is the whole point of the check: the fallback is asked to answer out of
# the watch's real bundle contents, not out of the repo's Resources directory.
mkdir -p "$WORK/bundle"
copied=0
while IFS= read -r name; do
    case "$name" in
        *.json) ;;
        *) continue ;;
    esac
    src="$REPO/ACIMDailyMinute/Resources/$name"
    if [ ! -f "$src" ]; then
        echo "FAIL: the watch copies '$name', which is not in ACIMDailyMinute/Resources"
        exit 1
    fi
    cp "$src" "$WORK/bundle/$name"
    copied=$((copied + 1))
done < "$WORK/resources.txt"
echo "the watch's bundle carries $copied corpus file(s)"

# ── 3. Two rules that are comments today and nothing else ──────────────────
# The watch must never open the reader's store. Its own comment says why: a
# device with no screen for a highlight has no business holding every highlight
# the reader has ever written.
if ! grep -rq "includeReader: false" "$REPO/ACIMDailyMinuteWatch"; then
    echo "FAIL: the watch does not ask for a cache-only container (includeReader: false)"
    exit 1
fi
if grep -rq "includeReader: true" "$REPO/ACIMDailyMinuteWatch"; then
    echo "FAIL: something in the watch target opens the reader's store"
    exit 1
fi
# ⛔ And no iCloud on this target, ever. `cloudKitDatabase` defaults to
# `.automatic` — "mirror if entitled" — so the entitlement alone is enough to
# start mirroring.
if grep -q "com.apple.developer.icloud" "$REPO/ACIMDailyMinuteWatch/ACIMDailyMinuteWatch.entitlements"; then
    echo "FAIL: the watch entitlements carry an iCloud key"
    exit 1
fi

# ── 4. The behaviour, out of that bundle and nothing else ──────────────────
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures: [String] = []
var checks = 0
func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition { failures.append(message()) }
}

// The watch's bundle, and only the watch's bundle.
let bundle = URL(fileURLWithPath: CommandLine.arguments[1])
let corpus = CorpusService(resourceDirectory: bundle)

// ⛔ The defect this exists for: `load()` answers `[]` for a file it cannot
// find, so an empty pool is exactly what a dropped resource looks like.
check(!corpus.allSegmentIDs.isEmpty,
      "the watch's bundle yields no segments at all — a corpus file is missing from its Resources phase")

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

// Over more than a year of days: the watch always has something to say, says
// the same thing about the same day, and can always name where it came from.
var addressed = 0
var distinct = Set<Int>()
for offset in 0..<400 {
    let day = calendar.date(byAdding: .day, value: offset, to: start)!
    guard let segment = CorpusFallback.segment(for: day, corpus: corpus) else {
        check(false, "no reading for day \(offset) — the watch would be blank")
        continue
    }
    distinct.insert(segment.segmentId)

    // Deterministic: the same date must yield the same passage, or the watch
    // and the phone disagree about what the offline reading for a day is.
    let again = CorpusFallback.segment(for: day, corpus: corpus)
    check(again?.segmentId == segment.segmentId,
          "day \(offset) yielded two different segments")

    check(!segment.body.isEmpty, "day \(offset): segment \(segment.segmentId) has no words")

    // Every reading can name its place, or failing that its volume. Nothing is
    // guessed and nothing is blank.
    let address = segment.citation ?? segment.bookName
    check(!address.isEmpty, "day \(offset): segment \(segment.segmentId) has no address at all")
    if segment.citation != nil { addressed += 1 }
    if let raw = segment.citation {
        check(Citation(rawValue: raw) != nil,
              "day \(offset): citation \(raw.debugDescription) does not parse")
    }
}
check(distinct.count > 300,
      "400 days drew only \(distinct.count) distinct passages — the walk is not spreading over the corpus")

// The staleness rule the watch shares with the phone's Today tab. Getting this
// wrong in either direction is visible: too eager and the feed's real reading is
// hidden, too slow and a week-old passage draws under a heading saying Today.
check(CorpusFallback.isStale(newest: nil), "no cached reading at all must be stale")
let now = Date()
check(!CorpusFallback.isStale(newest: now, now: now), "today's reading is not stale")
check(!CorpusFallback.isStale(newest: now.addingTimeInterval(-2 * 86_400), now: now),
      "a two-day-old reading is inside the threshold")
check(CorpusFallback.isStale(newest: now.addingTimeInterval(-7 * 86_400), now: now),
      "a week-old reading must be stale — that is the bug the watch shipped with")

if failures.isEmpty {
    print("\(checks) checks over 400 days; \(corpus.allSegmentIDs.count) segments in the watch's bundle, \(addressed)/400 days citable")
    print("OK")
} else {
    print("\(failures.count) FAILURE(S) of \(checks) checks")
    for f in failures.prefix(20) { print("  \(f)") }
    exit(1)
}
SWIFT

# ⛔ Four files and no others — the same discipline every other check keeps.
# These are exactly the files the watch target compiles for its offline floor,
# so a dependency creeping into any of them breaks this compile before it
# reaches a wrist.
swiftc -O \
    "$REPO/ACIMDailyMinute/Services/CorpusService.swift" \
    "$REPO/ACIMDailyMinute/Services/CorpusFallback.swift" \
    "$REPO/ACIMDailyMinute/Utilities/Citation.swift" \
    "$REPO/ACIMDailyMinute/Utilities/LessonSchedule.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify" 2>&1 | grep -v "^$" || true

"$WORK/verify" "$WORK/bundle"
