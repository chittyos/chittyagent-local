#!/bin/bash
##############################################
# ChittyAgent-Cleaner Uninstallation Script
##############################################

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "=== ChittyAgent-Cleaner Uninstaller ==="
echo ""

AGENTS=(
    "com.chittyos.cleaner.local"
    "com.chittyos.cleaner.volume"
    "com.chittyos.cleaner.kondo"
)

for agent in "${AGENTS[@]}"; do
    plist="$LAUNCH_AGENTS_DIR/$agent.plist"
    if [ -f "$plist" ]; then
        launchctl unload "$plist" 2>/dev/null
        rm "$plist"
        echo "Removed: $agent"
    fi
done

echo ""
echo "=== Uninstallation Complete ==="
