#!/bin/bash
# Build and run macOS app
# Usage: ./scripts/run-mac.sh

set -e

PROJECT="Chips.xcodeproj"
SCHEME="Chips-macOS"

echo "💻 Building and running on macOS..."

# Build
set +e
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS' \
    2>&1 | xcbeautify
BUILD_EXIT=$?
set -e

if [ $BUILD_EXIT -ne 0 ]; then
    echo "❌ Build failed with exit code $BUILD_EXIT"
    exit $BUILD_EXIT
fi

# Find and launch app
echo "🚀 Launching app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Chips.app" -path "*Debug/*" -not -path "*iphonesimulator*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found, build may have failed"
    exit 1
fi

echo ""
echo "📋 To view logs, run in another terminal:"
echo "   make tail-mac-logs"
echo "   OR open Console.app and filter by 'Chips'"
echo ""

open "$APP_PATH" || echo "Failed to launch app"

