#!/bin/bash
# Update Swift packages to latest versions
# Usage: ./scripts/update-packages.sh

set -e

PROJECT_FILE="project.yml"

echo "🔄 Updating Swift packages to latest versions..."
echo ""

# Get latest versions from GitHub
SWIFT_MARKDOWN_LATEST=$(git ls-remote --tags https://github.com/apple/swift-markdown.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///' || echo "")
YAMS_LATEST=$(git ls-remote --tags https://github.com/jpsim/Yams.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///' || echo "")

if [ -z "$SWIFT_MARKDOWN_LATEST" ] || [ -z "$YAMS_LATEST" ]; then
    echo "❌ Error: Could not fetch latest versions. Check your internet connection."
    exit 1
fi

# Get current versions from project.yml
SWIFT_MARKDOWN_CURRENT=$(grep -A 2 "swift-markdown:" "$PROJECT_FILE" | grep "from:" | sed 's/.*"\(.*\)"/\1/' || echo "")
YAMS_CURRENT=$(grep -A 2 "^  Yams:" "$PROJECT_FILE" | grep "from:" | sed 's/.*"\(.*\)"/\1/' || echo "")

echo "Updating packages:"

UPDATED=false

# Update swift-markdown
if [ -n "$SWIFT_MARKDOWN_CURRENT" ] && [ "$SWIFT_MARKDOWN_CURRENT" != "$SWIFT_MARKDOWN_LATEST" ]; then
    echo "  swift-markdown: $SWIFT_MARKDOWN_CURRENT → $SWIFT_MARKDOWN_LATEST"
    sed -i '' "s/from: \"$SWIFT_MARKDOWN_CURRENT\"/from: \"$SWIFT_MARKDOWN_LATEST\"/" "$PROJECT_FILE"
    UPDATED=true
else
    echo "  swift-markdown: ${SWIFT_MARKDOWN_CURRENT:-unknown} (already latest)"
fi

# Update Yams
if [ -n "$YAMS_CURRENT" ] && [ "$YAMS_CURRENT" != "$YAMS_LATEST" ]; then
    echo "  Yams: $YAMS_CURRENT → $YAMS_LATEST"
    sed -i '' "s/from: \"$YAMS_CURRENT\"/from: \"$YAMS_LATEST\"/" "$PROJECT_FILE"
    UPDATED=true
else
    echo "  Yams: ${YAMS_CURRENT:-unknown} (already latest)"
fi

echo ""

if [ "$UPDATED" = true ]; then
    echo "✅ Updated project.yml"
    echo "🔄 Regenerating Xcode project..."
    xcodegen generate
    echo ""
    echo "✅ Package update complete! Run 'make check-packages' to verify."
else
    echo "✅ All packages are already at latest versions!"
fi

