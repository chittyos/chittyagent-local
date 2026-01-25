#!/bin/bash
# Install all ChittyAgent Local agents

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
source "$REPO_DIR/shared/common.sh"

ensure_chittyos_dirs

log_info "Installing ChittyAgent Local agents..."

# Install each agent's launchd plists
for plist in "$REPO_DIR"/launchd/*.plist; do
  if [[ -f "$plist" ]]; then
    name=$(basename "$plist")
    dest="$HOME/Library/LaunchAgents/$name"

    # Update paths in plist to point to actual script locations
    cp "$plist" "$dest"
    log_success "Installed: $name"

    # Load the agent
    launchctl load "$dest" 2>/dev/null || true
    log_info "Loaded: $name"
  fi
done

log_success "Installation complete!"
log_info "View logs: tail -f ~/.chittyos/logs/*.log"
