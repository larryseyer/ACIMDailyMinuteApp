#!/bin/bash
# clean.sh — Nuke build artifacts and DerivedData for ACIM Daily Minute
set -e

echo "▸ Removing local build/ ..."
rm -rf "$(pwd)/build"

echo "▸ Removing Xcode DerivedData for ACIMDailyMinute ..."
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -type d -name "ACIMDailyMinute-*" -exec rm -rf {} + 2>/dev/null || true

echo "✓ Clean"
