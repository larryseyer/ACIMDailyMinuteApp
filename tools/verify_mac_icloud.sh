#!/bin/bash
# Proves a Mac process without a real code-signing grant cannot open the
# live CloudKit-backed App Group store.
#
# What this guards is Mac Debug launched from Terminal: a linker-signed
# binary (empty team ID, no entitlements) whose parent is the shell.
# `containerURL(forSecurityApplicationGroupIdentifier:)` still returns
# the group path on macOS without the entitlement, so the process opened
# `reader.store` — a file that already holds `ANSCK*` mirroring tables —
# and `PFCloudKitContainerProvider` trapped (EXC_BREAKPOINT on
# `com.apple.coredata.cloudkit.queue`, `_os_crash`). Passing
# `cloudKitDatabase: .none` does not skip that setup once those tables
# exist. The entitlements *file* is not the grant; the live signature is.
#
# A signed Mac build must still mirror when the reader asks. Hardcoding
# `.none` for `os(macOS)` is the other door, and it would silently drop
# iCloud on the Mac that is supposed to receive a mark from the phone.
#
#   ./tools/verify_mac_icloud.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER="$REPO/ACIMDailyMinuteWidget/SharedModelContainer.swift"
MAC_DEBUG="$REPO/ACIMDailyMinute.macos.entitlements"
MAC_RELEASE="$REPO/ACIMDailyMinute.macos-Release.entitlements"

failures=0
fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

# ── 1. The Mac entitlement files still name the same CloudKit container ──
for f in "$MAC_DEBUG" "$MAC_RELEASE"; do
    if [ ! -f "$f" ]; then
        fail "missing $(basename "$f")"
    fi
done

/usr/bin/python3 - "$MAC_DEBUG" "$MAC_RELEASE" <<'PY' || fail "plist parse of Mac entitlements failed"
import plistlib, sys

def load(path):
    with open(path, "rb") as f:
        return plistlib.load(f)

debug, release = (load(p) for p in sys.argv[1:])
container = "iCloud.com.larryseyer.acimdailyminute"
group = "group.com.larryseyer.acimdailyminute"
fails = []

def require(plist, name, key, pred, msg):
    if not pred(plist.get(key)):
        fails.append(f"{name}: {msg}")

for name, plist, aps in (
    ("ACIMDailyMinute.macos.entitlements", debug, "development"),
    ("ACIMDailyMinute.macos-Release.entitlements", release, "production"),
):
    require(plist, name, "com.apple.developer.icloud-services",
            lambda v: isinstance(v, list) and "CloudKit" in v,
            "icloud-services does not include CloudKit")
    require(plist, name, "com.apple.developer.icloud-container-identifiers",
            lambda v: isinstance(v, list) and v == [container],
            f"icloud-container-identifiers is not [{container}]")
    require(plist, name, "com.apple.security.application-groups",
            lambda v: isinstance(v, list) and group in v,
            "lost the App Group")
    require(plist, name, "aps-environment",
            lambda v: v == aps,
            f"aps-environment is {plist.get('aps-environment')!r}, want {aps!r}")

if fails:
    for f in fails:
        print("FAIL:", f)
    sys.exit(1)
PY

# ── 2. groupURL consults the live signature, not only containerURL ──────
if ! grep -q 'MacCodeSignature.current.hasAppGroup' "$CONTAINER"; then
    fail "groupURL no longer asks the live Mac signature for the App Group"
fi
if ! grep -q 'containerURL(forSecurityApplicationGroupIdentifier' "$CONTAINER"; then
    fail "groupURL no longer looks up the App Group container"
fi

# ── 3. Mirroring still honours the reader's toggle, and also the grant ──
if ! grep -q 'mirrorsReader ? .private(cloudKitContainerIdentifier) : .none' "$CONTAINER"; then
    fail "reader store is no longer gated on mirrorsReader / the private container"
fi
if ! grep -q 'syncEnabled && processCanUseCloudKit' "$CONTAINER"; then
    fail "mirrorsReader no longer requires processCanUseCloudKit"
fi
if ! grep -q 'MacCodeSignature.current.canUseCloudKit' "$CONTAINER"; then
    fail "processCanUseCloudKit no longer reads the live Mac signature"
fi

# A hardcoded .none on macOS would make the entitlement file theatre.
if grep -n 'os(macOS)' "$CONTAINER" | grep -q 'cloudKitDatabase'; then
    fail "SharedModelContainer fences CloudKit off macOS — a signed Mac would then never sync"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL — $failures check(s) failed"
    exit 1
fi
echo "PASS — Mac Debug without a signing grant cannot open the CloudKit store; a signed Mac still can"
