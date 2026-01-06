#!/bin/bash

# View Chips app logs
# Usage: ./scripts/view-logs.sh or make view-logs

echo "📋 Viewing Chips app logs..."
echo "Press Ctrl+C to stop"
echo ""
echo "This will show unified logging (os_log) messages."
echo "For stdout/stderr, check Console.app or run the app from terminal."
echo ""

# Stream logs from unified logging system - try multiple predicates
log stream --predicate 'process == "Chips"' --level debug --style compact

