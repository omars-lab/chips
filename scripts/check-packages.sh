#!/bin/bash
# Check for Swift package updates
# Usage: ./scripts/check-packages.sh

set -e

PROJECT="Chips.xcodeproj"
SCHEME="Chips-iOS"

echo "📦 Checking for Swift package updates..."
echo ""

# Resolve packages and get current versions
echo "Resolving packages..."
xcodebuild -resolvePackageDependencies -project "$PROJECT" -scheme "$SCHEME" > /dev/null 2>&1 || true

RESOLVED=$(xcodebuild -resolvePackageDependencies -project "$PROJECT" -scheme "$SCHEME" 2>&1 | grep -A 10 "Resolved source packages" | grep "@" | sed 's/.*@ //' || echo "")

if [ -n "$RESOLVED" ]; then
    echo "Current versions:"
    echo "$RESOLVED"
    echo ""
fi

echo "Checking latest versions on GitHub..."
echo ""

# Get latest versions from GitHub
SWIFT_MARKDOWN_LATEST=$(git ls-remote --tags https://github.com/apple/swift-markdown.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///' || echo "")
YAMS_LATEST=$(git ls-remote --tags https://github.com/jpsim/Yams.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///' || echo "")
CMARK_LATEST=$(git ls-remote --tags https://github.com/swiftlang/swift-cmark.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///' || echo "")

# Get current versions from project.yml
SWIFT_MARKDOWN_CURRENT=$(grep -A 2 "swift-markdown:" project.yml | grep "from:" | sed 's/.*"\(.*\)"/\1/' || echo "")
YAMS_CURRENT=$(grep -A 2 "^  Yams:" project.yml | grep "from:" | sed 's/.*"\(.*\)"/\1/' || echo "")

echo "Package Version Comparison:"
echo "  swift-markdown:  ${SWIFT_MARKDOWN_CURRENT:-unknown} → ${SWIFT_MARKDOWN_LATEST:-unknown}"
echo "  Yams:            ${YAMS_CURRENT:-unknown} → ${YAMS_LATEST:-unknown}"
echo "  cmark-gfm:       (dependency, latest: ${CMARK_LATEST:-unknown})"
echo ""

if [ -n "$SWIFT_MARKDOWN_LATEST" ] && [ -n "$YAMS_LATEST" ]; then
    if [ "$SWIFT_MARKDOWN_CURRENT" != "$SWIFT_MARKDOWN_LATEST" ] || [ "$YAMS_CURRENT" != "$YAMS_LATEST" ]; then
        echo "⚠️  Updates available! Run 'make update-packages' to update."
        exit 1
    else
        echo "✅ All packages are up to date!"
    fi
else
    echo "⚠️  Could not fetch latest versions. Check your internet connection."
    exit 1
fi

