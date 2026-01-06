#!/bin/bash
# Generate app icon and in-app logo images from ChipLogoView
# Usage: ./scripts/generate-logo.sh [output_dir]
#
# Generates:
# - App icons: 16, 32, 64, 128, 256, 512, 1024 (for AppIcon.appiconset)
# - App logos: 40, 60, 80, 120, 180, 240 (for use in UI)

set -e

OUTPUT_DIR="${1:-$(pwd)/logo-assets}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🎨 Generating logo assets..."
echo "   Output directory: $OUTPUT_DIR"
echo ""

# Create output directories
mkdir -p "$OUTPUT_DIR/app-icons"
mkdir -p "$OUTPUT_DIR/app-logos"

# Determine output directory argument
if [ $# -lt 1 ]; then
    OUTPUT_DIR_ARG="$OUTPUT_DIR"
else
    OUTPUT_DIR_ARG="$1"
fi

# Run the standalone Swift script
SWIFT_SCRIPT="$SCRIPT_DIR/generate-logo.swift"
if [ ! -f "$SWIFT_SCRIPT" ]; then
    echo "❌ Swift script not found: $SWIFT_SCRIPT"
    exit 1
fi

if command -v swift >/dev/null 2>&1; then
    swift "$SWIFT_SCRIPT" "$OUTPUT_DIR_ARG" || {
        echo "⚠️  Swift script execution failed."
        echo ""
        echo "Alternative: Use Xcode to export the logo:"
        echo "1. Open Chips.xcodeproj"
        echo "2. Run the app"
        echo "3. Take screenshots of ChipLogoView at different sizes"
        echo "4. Or use the logo in Assets.xcassets directly"
        exit 1
    }
else
    echo "❌ Swift not found. Please install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

# Copy icons to AppIcon.appiconset if it exists
APPICON_DIR="$PROJECT_ROOT/Chips/Resources/Assets.xcassets/AppIcon.appiconset"
if [ -d "$APPICON_DIR" ]; then
    echo ""
    echo "📦 Copying icons to AppIcon.appiconset..."
    cp "$OUTPUT_DIR/app-icons/"*.png "$APPICON_DIR/" 2>/dev/null || true
    
    # Update Contents.json to reference the icon files
    echo "📝 Updating Contents.json..."
    PYTHON_SCRIPT="$SCRIPT_DIR/update-appicon-contents.py"
    if [ ! -f "$PYTHON_SCRIPT" ]; then
        echo "  ⚠️  Python script not found: $PYTHON_SCRIPT"
    else
        python3 "$PYTHON_SCRIPT" "$APPICON_DIR" "$OUTPUT_DIR/app-icons" || {
            echo "  ⚠️  Failed to update Contents.json"
        }
    fi
    
    echo "  ✅ Icons copied to AppIcon.appiconset"
else
    echo ""
    echo "⚠️  AppIcon.appiconset directory not found at:"
    echo "   $APPICON_DIR"
    echo ""
    echo "📁 Logo assets saved to:"
    echo "   App Icons: $OUTPUT_DIR/app-icons/"
    echo "   App Logos: $OUTPUT_DIR/app-logos/"
    echo ""
    echo "📱 To use app icons manually:"
    echo "   1. Open Assets.xcassets in Xcode"
    echo "   2. Select AppIcon"
    echo "   3. Drag PNG files from app-icons/ to the appropriate slots"
fi

echo ""
echo "🎨 App logos saved to:"
echo "   $OUTPUT_DIR/app-logos/"
echo ""
echo "💡 After copying icons, you may need to:"
echo "   1. Clean build folder in Xcode (Cmd+Shift+K)"
echo "   2. Rebuild the app"
echo "   3. Restart the app or rebuild to see icon changes"
