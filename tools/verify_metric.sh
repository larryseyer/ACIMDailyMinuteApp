#!/bin/bash
# Proves Metric's platform multiplier is a compile-time constant, hits spacing
# and radii only, and leaves tap / hairline / quote unmultiplied.
#
# Simulator binaries cannot run on the host, so tvOS and watchOS are compile
# checks; the values are asserted from the #if os constants in source plus a
# macOS run of the unmultiplied (×1.0) path.
#
#   ./tools/verify_metric.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$REPO/ACIMDailyMinute/Utilities/Metric.swift"

if sed 's://.*::' "$SRC" | grep -E '^[[:space:]]*import[[:space:]]+' \
    | grep -vE 'import[[:space:]]+(Foundation|SwiftUI)[[:space:]]*$'; then
    echo "FAIL: Metric.swift imports something other than Foundation or SwiftUI"
    exit 1
fi
if ! grep -q 'os(tvOS)' "$SRC" || ! grep -q 'os(watchOS)' "$SRC"; then
    echo "FAIL: Metric.swift must bake the platform multiplier in with #if os(tvOS) / #if os(watchOS)"
    exit 1
fi
if grep -nE 'Font|acimMasthead|acimReading' "$SRC"; then
    echo "FAIL: Metric.swift must not scale type"
    exit 1
fi

python3 - "$SRC" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
def const(name):
    m = re.search(rf'static let {name}: CGFloat = ([0-9.]+)', src)
    if not m:
        print(f"FAIL: {name} is not a bare unmultiplied constant")
        sys.exit(1)
    return float(m.group(1))
if const("tapTarget") != 44:
    print("FAIL: tapTarget must be 44 on every platform")
    sys.exit(1)
if const("progressHairline") != 2:
    print("FAIL: progressHairline must be 2 on every platform")
    sys.exit(1)
if const("quoteRule") != 2:
    print("FAIL: quoteRule must be 2 on every platform")
    sys.exit(1)
if not re.search(r'#if os\(tvOS\)\s+private static let m: CGFloat = 1\.6', src):
    print("FAIL: tvOS multiplier must be compile-time 1.6")
    sys.exit(1)
if not re.search(r'#elseif os\(watchOS\)\s+private static let m: CGFloat = 0\.7', src):
    print("FAIL: watchOS multiplier must be compile-time 0.7")
    sys.exit(1)
if not re.search(r'#else\s+private static let m: CGFloat = 1\.0', src):
    print("FAIL: default multiplier must be compile-time 1.0")
    sys.exit(1)
if "static let gutter: CGFloat = 24 * m" not in src:
    print("FAIL: gutter must be 24 * m")
    sys.exit(1)
print("source: tap 44, hairline 2, quote 2; m is 1.6 / 0.7 / 1.0")
PY

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation
setvbuf(stdout, nil, _IONBF, 0)
print("gutter=\(Metric.gutter)")
print("tapTarget=\(Metric.tapTarget)")
print("progressHairline=\(Metric.progressHairline)")
print("quoteRule=\(Metric.quoteRule)")
SWIFT

compile() {
    local sdk="$1" target="$2" label="$3" run="$4"
    local sdk_path out
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
    if ! xcrun --sdk "$sdk" swiftc -O \
        -target "$target" \
        -sdk "$sdk_path" \
        "$SRC" "$WORK/main.swift" \
        -o "$WORK/verify-$label" 2>"$WORK/err-$label"; then
        echo "FAIL: $label did not compile"
        cat "$WORK/err-$label"
        exit 1
    fi
    echo "$label compiled"
    if [[ "$run" == "run" ]]; then
        out="$("$WORK/verify-$label")"
        echo "$label: $out"
        python3 - "$out" <<'PY'
import sys
vals = dict(part.split("=", 1) for part in sys.argv[1].split())
if float(vals["gutter"]) != 24:
    print(f"FAIL: macOS/iOS gutter {vals['gutter']} != 24")
    sys.exit(1)
if float(vals["tapTarget"]) != 44:
    print(f"FAIL: tapTarget {vals['tapTarget']} != 44")
    sys.exit(1)
if float(vals["progressHairline"]) != 2 or float(vals["quoteRule"]) != 2:
    print("FAIL: unmultiplied constants moved")
    sys.exit(1)
PY
    fi
}

compile macosx arm64-apple-macos14.0 macos run
compile iphonesimulator arm64-apple-ios17.0-simulator ios norun
compile appletvsimulator arm64-apple-tvos17.0-simulator tvos norun
compile watchsimulator arm64-apple-watchos10.0-simulator watchos norun

echo "Metric multiplier is compile-time; tap/hairline/quote unmultiplied"
echo "OK"
