#!/bin/bash
# Detects available iOS simulators for Makefile use
# Usage: ./detect-simulator.sh [iphone|ipad]

TYPE="${1:-iphone}"

case "$TYPE" in
    iphone)
        PATTERN="iPhone"
        ;;
    ipad)
        PATTERN="iPad"
        ;;
    *)
        echo "Usage: $0 [iphone|ipad]" >&2
        exit 1
        ;;
esac

# Get first available simulator matching pattern, extract name before (UUID)
xcrun simctl list devices available 2>/dev/null \
    | grep "$PATTERN" \
    | head -1 \
    | sed 's/^[[:space:]]*//' \
    | sed 's/ (.*$//'
