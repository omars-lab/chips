#!/bin/bash
# Clear macOS icon cache and force icon refresh
# Usage: ./scripts/clear-icon-cache.sh

echo "🧹 Clearing macOS icon cache..."

# Clear icon cache
rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null
rm -rf ~/Library/Caches/com.apple.iconservices 2>/dev/null

# Clear LaunchServices database (this is the main icon cache)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || true

# Restart Finder and Dock
killall Finder 2>/dev/null
killall Dock 2>/dev/null

echo "✅ Icon cache cleared"
echo ""
echo "💡 Next steps:"
echo "   1. Rebuild the app: make run-mac-stdout"
echo "   2. If icon still doesn't appear, restart your Mac"
echo "   3. macOS aggressively caches app icons and may require a restart"

