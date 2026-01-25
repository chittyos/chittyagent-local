#!/bin/bash
##############################################
# ChittyAgent-Cleaner Installation Script
# Installs/updates launchd agents from canonical location
##############################################

REPO_DIR="/Volumes/chitty/github.com/CHITTYOS/chittyagent-cleaner"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "=== ChittyAgent-Cleaner Installer ==="
echo ""

# Unload old agents if they exist
echo "Unloading old agents..."
OLD_AGENTS=(
    "com.chittycleaner.auto"
    "com.chittyos.kondo"
    "com.chittyos.volume-cleanup"
)

for agent in "${OLD_AGENTS[@]}"; do
    if [ -f "$LAUNCH_AGENTS_DIR/$agent.plist" ]; then
        launchctl unload "$LAUNCH_AGENTS_DIR/$agent.plist" 2>/dev/null
        rm "$LAUNCH_AGENTS_DIR/$agent.plist"
        echo "  Removed: $agent"
    fi
done

# Install new agents
echo ""
echo "Installing new agents..."
NEW_AGENTS=(
    "com.chittyos.cleaner.local"
    "com.chittyos.cleaner.volume"
    "com.chittyos.cleaner.kondo"
)

for agent in "${NEW_AGENTS[@]}"; do
    src="$REPO_DIR/launchd/$agent.plist"
    dst="$LAUNCH_AGENTS_DIR/$agent.plist"

    if [ -f "$src" ]; then
        cp "$src" "$dst"
        launchctl load "$dst"
        echo "  Installed: $agent"
    else
        echo "  ERROR: Source not found: $src"
    fi
done

# Verify installation
echo ""
echo "=== Verification ==="
for agent in "${NEW_AGENTS[@]}"; do
    status=$(launchctl list | grep "$agent" | awk '{print $2}')
    if [ -n "$status" ]; then
        echo "  $agent: RUNNING (PID: $status)"
    else
        echo "  $agent: LOADED"
    fi
done

echo ""
echo "=== Installation Complete ==="
echo "Logs available at:"
echo "  /tmp/chittyos-cleaner-local.out"
echo "  /tmp/chittyos-cleaner-volume.out"
echo "  /tmp/chittyos-cleaner-kondo.out"
echo ""
echo "Insights will be generated at:"
echo "  ~/.chittyos/insights/recommendations.md"
