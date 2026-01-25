#!/bin/bash
# Uninstall all ChittyAgent Local agents

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
source "$REPO_DIR/shared/common.sh"

log_info "Uninstalling ChittyAgent Local agents..."

# Unload and remove each agent's launchd plists
for plist in "$HOME"/Library/LaunchAgents/com.chittyos.*.plist; do
  if [[ -f "$plist" ]]; then
    name=$(basename "$plist")

    # Unload the agent
    launchctl unload "$plist" 2>/dev/null || true
    log_info "Unloaded: $name"

    # Remove the plist
    rm -f "$plist"
    log_success "Removed: $name"
  fi
done

log_success "Uninstallation complete!"
log_info "Agent data preserved in ~/.chittyos/"
