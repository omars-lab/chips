#!/bin/bash
# Clean build artifacts
# Usage: ./scripts/clean.sh

set -e

PROJECT="Chips.xcodeproj"
SCHEME_IOS="Chips-iOS"
SCHEME_MACOS="Chips-macOS"

echo "🧹 Cleaning..."

# Clean Xcode builds
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME_IOS" 2>/dev/null || true
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME_MACOS" 2>/dev/null || true

# Remove DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData

# Remove build directory
rm -rf build/

# Remove generated Xcode project
rm -rf "$PROJECT"

echo "✅ Clean complete"

