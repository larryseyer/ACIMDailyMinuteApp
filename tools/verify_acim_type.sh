#!/bin/bash
# Proves every Font.acimX token in the redesign table resolves, the file can
# compile on macOS and iOS, and ReaderTextSize is not applied to the new tokens.
#
#   ./tools/verify_acim_type.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$REPO/ACIMDailyMinute/Utilities/ACIMType.swift"

if grep -qE 'import[[:space:]]+SwiftData|UIDevice' "$SRC"; then
    echo "FAIL: ACIMType.swift imports SwiftData or names UIDevice"
    exit 1
fi

TOKENS="acimMasthead acimMastheadSub acimDisplayTitle acimSubject acimSubjectSub acimReading acimReadingPushed acimRowTitle acimRowSub acimRowNumber acimAddress acimAddressSmall acimCardTitle acimCardBody acimChrome acimChipText acimGroupHeader acimTabLabel"
missing=0
for t in $TOKENS; do
    if ! grep -q "static var $t:" "$SRC"; then
        echo "FAIL: Font.$t is missing"
        missing=1
    fi
done
if [[ $missing -ne 0 ]]; then
    exit 1
fi

# ReaderTextSize multiplies the reading tokens only, at the view, not here.
if grep -n 'ReaderTextSize' "$SRC"; then
    echo "FAIL: ReaderTextSize must not live inside ACIMType"
    exit 1
fi

cat > "$WORK/main.swift" <<'SWIFT'
import SwiftUI
setvbuf(stdout, nil, _IONBF, 0)
let fonts: [Font] = [
    .acimMasthead, .acimMastheadSub, .acimDisplayTitle, .acimSubject, .acimSubjectSub,
    .acimReading, .acimReadingPushed, .acimRowTitle, .acimRowSub, .acimRowNumber,
    .acimAddress, .acimAddressSmall, .acimCardTitle, .acimCardBody, .acimChrome,
    .acimChipText, .acimGroupHeader, .acimTabLabel
]
print("\(fonts.count) tokens")
SWIFT

MAC_SDK="$(xcrun --sdk macosx --show-sdk-path)"
if ! swiftc -O -sdk "$MAC_SDK" -target arm64-apple-macos14.0 \
    "$SRC" "$WORK/main.swift" -o "$WORK/verify-mac"; then
    echo "FAIL: ACIMType.swift did not compile on macOS"
    exit 1
fi
"$WORK/verify-mac"

IOS_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
if ! xcrun --sdk iphonesimulator swiftc -O \
    -sdk "$IOS_SDK" -target arm64-apple-ios17.0-simulator \
    "$SRC" "$WORK/main.swift" -o "$WORK/verify-ios"; then
    echo "FAIL: ACIMType.swift did not compile for iOS"
    exit 1
fi

echo "18 Font.acimX tokens resolve; ReaderTextSize stays off the token table"
echo "OK"
