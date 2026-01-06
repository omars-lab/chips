#!/bin/bash
# Build and run iOS app on simulator
# Usage: ./scripts/run-ios.sh [simulator_name]

set -e

PROJECT="Chips.xcodeproj"
SCHEME="Chips-iOS"
BUNDLE_ID="com.chips.app"
IPHONE_SIMULATOR="${1:-$(./scripts/detect-simulator.sh iphone)}"

echo "📱 Building and running on ${IPHONE_SIMULATOR}..."

# Find device ID
DEVICE_ID=$(xcrun simctl list devices available | grep "${IPHONE_SIMULATOR}" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Could not find simulator device: ${IPHONE_SIMULATOR}"
    echo "   Available devices:"
    xcrun simctl list devices available | grep "iPhone" | head -5
    exit 1
fi

echo "   Using device ID: $DEVICE_ID"

# Boot simulator
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
open -a Simulator

# Build
echo "🔨 Building app..."
set +e
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    2>&1 | xcbeautify
BUILD_EXIT=$?
set -e

if [ $BUILD_EXIT -ne 0 ]; then
    echo "❌ Build failed with exit code $BUILD_EXIT"
    echo "   Build errors (last 50 lines):"
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=$DEVICE_ID" 2>&1 | tail -50
    exit $BUILD_EXIT
fi

# Find and install app
echo "🚀 Launching app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Chips.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found, build may have failed"
    exit 1
fi

echo "📦 Installing app from $APP_PATH..."

# Verify Info.plist exists
if [ ! -f "$APP_PATH/Info.plist" ]; then
    echo "❌ Error: Info.plist not found in app bundle. Build may have failed."
    echo "   Try: make clean && make generate && make run-ios"
    exit 1
fi

# Verify bundle ID
BUNDLE_ID_CHECK=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null)
if [ -z "$BUNDLE_ID_CHECK" ]; then
    echo "❌ Error: Bundle ID not found in Info.plist."
    echo "   Try: make clean && make generate && make run-ios"
    exit 1
fi

echo "   Bundle ID: $BUNDLE_ID_CHECK"

# Install and launch
xcrun simctl install booted "$APP_PATH" && \
xcrun simctl launch booted "$BUNDLE_ID" || echo "Launch failed - try opening from Xcode"

