#!/bin/bash
# ChittyAgent Local - Common Functions
# Shared utilities for all local agents

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Get disk usage percentage for a path
get_disk_usage() {
  local path="${1:-/}"
  df -h "$path" | awk 'NR==2 {print $5}' | tr -d '%'
}

# Format bytes to human readable
format_bytes() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    echo "$(( bytes / 1073741824 ))GB"
  elif (( bytes >= 1048576 )); then
    echo "$(( bytes / 1048576 ))MB"
  elif (( bytes >= 1024 )); then
    echo "$(( bytes / 1024 ))KB"
  else
    echo "${bytes}B"
  fi
}

# Get directory size in bytes
get_dir_size() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    du -sk "$dir" 2>/dev/null | cut -f1 | awk '{print $1 * 1024}'
  else
    echo "0"
  fi
}

# Safe delete with dry-run support
safe_delete() {
  local path="$1"
  local dry_run="${2:-true}"

  if [[ ! -e "$path" ]]; then
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    log_info "[DRY-RUN] Would delete: $path"
  else
    rm -rf "$path"
    log_success "Deleted: $path"
  fi
}

# Load agent config
load_agent_config() {
  local agent_name="$1"
  local config_file="$HOME/.chittyos/agents/${agent_name}/config.json"

  if [[ -f "$config_file" ]]; then
    cat "$config_file"
  else
    echo "{}"
  fi
}

# Save agent state
save_agent_state() {
  local agent_name="$1"
  local state="$2"
  local state_dir="$HOME/.chittyos/agents/${agent_name}"

  mkdir -p "$state_dir"
  echo "$state" > "${state_dir}/state.json"
}

# ChittyOS paths
CHITTYOS_HOME="${CHITTYOS_HOME:-$HOME/.chittyos}"
CHITTYOS_LOGS="${CHITTYOS_HOME}/logs"
CHITTYOS_INSIGHTS="${CHITTYOS_HOME}/insights"
CHITTYOS_AGENTS="${CHITTYOS_HOME}/agents"

# Ensure directories exist
ensure_chittyos_dirs() {
  mkdir -p "$CHITTYOS_LOGS" "$CHITTYOS_INSIGHTS" "$CHITTYOS_AGENTS"
}
