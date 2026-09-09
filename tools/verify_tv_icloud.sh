#!/bin/bash
# Proves the television is entitled to the same iCloud container the phone
# and the Mac use.
#
# What this guards is the launch crash on a box that had no iCloud
# entitlement: EXC_BREAKPOINT on com.apple.coredata.cloudkit.queue
# (PFCloudKitContainerProvider), crash ACIMDailyMinuteTV-2026-09-09-101331.ips
# on LIVINGROOM. CloudKit is a tvOS API. The television target shares the
# app's bundle ID, so the same container is the one that already holds a
# reader's marks. Forcing cloudKitDatabase .none would have been the other
# door; this file is the proof we took the entitled one.
#
#   ./tools/verify_tv_icloud.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO/ACIMDailyMinute.xcodeproj/project.pbxproj"
TV_DEBUG="$REPO/ACIMDailyMinuteTV.entitlements"
TV_RELEASE="$REPO/ACIMDailyMinuteTV-Release.entitlements"
IOS_DEBUG="$REPO/ACIMDailyMinute.entitlements"
IOS_RELEASE="$REPO/ACIMDailyMinute-Release.entitlements"
CONTAINER="$REPO/ACIMDailyMinuteWidget/SharedModelContainer.swift"
SETTINGS="$REPO/ACIMDailyMinute/Views/Settings/SettingsView.swift"

failures=0
fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

# ── 1. The files exist ──────────────────────────────────────────────────────
for f in "$TV_DEBUG" "$TV_RELEASE" "$IOS_DEBUG" "$IOS_RELEASE"; do
    if [ ! -f "$f" ]; then
        fail "missing $(basename "$f")"
    fi
done

# ── 2. Same CloudKit container as iOS, on both TV entitlement files ─────────
/usr/bin/python3 - "$TV_DEBUG" "$TV_RELEASE" "$IOS_DEBUG" "$IOS_RELEASE" <<'PY' || fail "plist parse of entitlements failed"
import plistlib, sys

def load(path):
    with open(path, "rb") as f:
        return plistlib.load(f)

tv_d, tv_r, ios_d, ios_r = (load(p) for p in sys.argv[1:])
fails = []

def require(plist, key, pred, msg):
    val = plist.get(key)
    if not pred(val):
        fails.append(msg)

container = "iCloud.com.larryseyer.acimdailyminute"

for name, plist, aps in (
    ("ACIMDailyMinuteTV.entitlements", tv_d, "development"),
    ("ACIMDailyMinuteTV-Release.entitlements", tv_r, "production"),
):
    require(plist, "com.apple.developer.icloud-services",
            lambda v: isinstance(v, list) and "CloudKit" in v,
            f"{name}: icloud-services does not include CloudKit")
    require(plist, "com.apple.developer.icloud-container-identifiers",
            lambda v: isinstance(v, list) and v == [container],
            f"{name}: icloud-container-identifiers is not [{container}]")
    require(plist, "aps-environment",
            lambda v: v == aps,
            f"{name}: aps-environment is {plist.get('aps-environment')!r}, want {aps!r}")
    require(plist, "com.apple.developer.user-management",
            lambda v: isinstance(v, list) and "runs-as-current-user" in v,
            f"{name}: missing user-management runs-as-current-user "
            "(without it the TV runs as the default user, so iCloud is not "
            "the person sitting in front of it)")
    require(plist, "com.apple.security.application-groups",
            lambda v: isinstance(v, list) and "group.com.larryseyer.acimdailyminute" in v,
            f"{name}: lost the App Group")

ios_containers = ios_d.get("com.apple.developer.icloud-container-identifiers")
if ios_containers != [container]:
    fails.append(f"iOS debug container drifted: {ios_containers!r}")
if ios_r.get("com.apple.developer.icloud-container-identifiers") != ios_containers:
    fails.append("iOS Release container does not match iOS Debug")
if tv_d.get("com.apple.developer.icloud-container-identifiers") != ios_containers:
    fails.append("TV Debug container does not match iOS")
if tv_r.get("com.apple.developer.icloud-container-identifiers") != ios_containers:
    fails.append("TV Release container does not match iOS")

if fails:
    for f in fails:
        print("FAIL:", f)
    sys.exit(1)
PY

# ── 3. The project actually SIGNS with those files ──────────────────────────
if ! grep -q 'CODE_SIGN_ENTITLEMENTS = ACIMDailyMinuteTV.entitlements;' "$PROJECT"; then
    fail "Debug TV target is not signing with ACIMDailyMinuteTV.entitlements"
fi
if ! grep -q 'CODE_SIGN_ENTITLEMENTS = "ACIMDailyMinuteTV-Release.entitlements";' "$PROJECT" \
    && ! grep -q 'CODE_SIGN_ENTITLEMENTS = ACIMDailyMinuteTV-Release.entitlements;' "$PROJECT"; then
    fail "Release TV target is not signing with ACIMDailyMinuteTV-Release.entitlements"
fi

# CloudKit silent push is how another device's mark reaches this one.
# The TV target generates its Info.plist, so the background mode has to
# live in the build setting, not in ACIMDailyMinute/Info.plist.
tv_remote=$(grep -c 'INFOPLIST_KEY_UIBackgroundModes = .*remote-notification' "$PROJECT" || true)
if [ "$tv_remote" -lt 2 ]; then
    fail "TV target is missing UIBackgroundModes remote-notification (need Debug and Release)"
fi

# ── 4. The container still honours the reader's toggle; it is not fenced off
# tvOS. A hardcoded .none on the television would make the entitlement
# theatre: the box would be allowed to talk to iCloud and then told not to.
if ! grep -q 'mirrorsReader ? .private(cloudKitContainerIdentifier) : .none' "$CONTAINER"; then
    fail "reader store is no longer gated on mirrorsReader / the private container"
fi
if grep -n 'os(tvOS)' "$CONTAINER" | grep -q 'cloudKitDatabase'; then
    fail "SharedModelContainer fences CloudKit off tvOS — the entitlement would then do nothing"
fi

# ── 5. Settings still offers the toggle on the television. A hidden switch
# with a working entitlement is the same as no iCloud.
if ! grep -q 'Toggle("Sync with iCloud"' "$SETTINGS"; then
    fail "Settings no longer offers Sync with iCloud"
fi
# The toggle must not sit inside a !os(tvOS) fence. Walk the file: if the
# last fence opened above the toggle is `!os(tvOS)` and still open, fail.
/usr/bin/python3 - "$SETTINGS" <<'PY' || fail "iCloud toggle is fenced off tvOS"
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
# Strip comments so a mention in a note cannot hide a real fence.
lines = []
for line in text.splitlines():
    if "//" in line:
        line = line[:line.index("//")]
    lines.append(line)
joined = "\n".join(lines)
idx = joined.find('Toggle("Sync with iCloud"')
if idx < 0:
    print("no toggle")
    sys.exit(1)
before = joined[:idx]
# Naive #if stack.
stack = []
for raw in before.splitlines():
    s = raw.strip()
    if s.startswith("#if "):
        stack.append(s[4:].strip())
    elif s.startswith("#elseif ") or s.startswith("#else"):
        if stack:
            stack[-1] = s
    elif s.startswith("#endif"):
        if stack:
            stack.pop()
for frame in stack:
    if "tvOS" in frame and frame.startswith("!"):
        print("toggle sits under", frame)
        sys.exit(1)
PY

if [ "$failures" -ne 0 ]; then
    echo "FAIL — $failures check(s) failed"
    exit 1
fi
echo "PASS — TV is entitled to iCloud.com.larryseyer.acimdailyminute, runs as the current user, and still honours the Settings toggle"
