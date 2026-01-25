#!/bin/bash

##############################################
# ChittyOS Development Volume Cleanup
# Automatically manages disk space on /Volumes/chitty
##############################################

VOLUME="/Volumes/chitty"
LOG_FILE="$VOLUME/temp/.cleanup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Configuration
NODE_MODULES_AGE_DAYS=7      # Remove node_modules not accessed in 7 days
WRANGLER_CACHE_AGE_DAYS=3    # Remove .wrangler caches older than 3 days
TEMP_FILE_AGE_DAYS=14        # Remove temp files older than 14 days
THRESHOLD_PERCENT=70         # Start cleanup when >70% full
CRITICAL_PERCENT=85          # Aggressive cleanup when >85% full

# Ensure volume is mounted
if [ ! -d "$VOLUME" ]; then
    echo "[$DATE] Volume $VOLUME not mounted, skipping" >> "$LOG_FILE"
    exit 0
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Get current disk usage
DISK_INFO=$(df "$VOLUME" | tail -1)
DISK_USAGE=$(echo "$DISK_INFO" | awk '{print $5}' | sed 's/%//')
DISK_AVAIL=$(echo "$DISK_INFO" | awk '{gsub(/Gi?/, "G"); print $4}')

notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
}

log() {
    echo "[$DATE] $1" >> "$LOG_FILE"
}

get_size_mb() {
    du -sm "$1" 2>/dev/null | cut -f1 || echo 0
}

# Clean node_modules not accessed recently
clean_node_modules() {
    local age_days=$1
    local total_freed=0

    log "Scanning for stale node_modules (>$age_days days)..."

    while IFS= read -r -d '' dir; do
        # Skip if inside another node_modules (nested)
        if [[ "$dir" == *"node_modules/node_modules"* ]]; then
            continue
        fi

        # Check last access time of the directory
        if [ "$(find "$dir" -maxdepth 0 -atime +$age_days 2>/dev/null)" ]; then
            size=$(get_size_mb "$dir")
            if [ "$size" -gt 10 ]; then  # Only log if >10MB
                log "  Removing: $dir (${size}MB)"
            fi
            rm -rf "$dir" 2>/dev/null
            total_freed=$((total_freed + size))
        fi
    done < <(find "$VOLUME/github.com" -name "node_modules" -type d -prune -print0 2>/dev/null)

    echo $total_freed
}

# Clean .wrangler cache directories
clean_wrangler_caches() {
    local age_days=$1
    local total_freed=0

    log "Cleaning .wrangler caches (>$age_days days)..."

    while IFS= read -r -d '' dir; do
        if [ "$(find "$dir" -maxdepth 0 -mtime +$age_days 2>/dev/null)" ]; then
            size=$(get_size_mb "$dir")
            rm -rf "$dir" 2>/dev/null
            total_freed=$((total_freed + size))
        fi
    done < <(find "$VOLUME" -name ".wrangler" -type d -print0 2>/dev/null)

    echo $total_freed
}

# Clean temp directory
clean_temp() {
    local age_days=$1
    local total_freed=0

    if [ -d "$VOLUME/temp" ]; then
        log "Cleaning temp files (>$age_days days)..."

        # Remove old log files
        while IFS= read -r -d '' file; do
            size=$(du -sk "$file" 2>/dev/null | cut -f1)
            rm -f "$file" 2>/dev/null
            total_freed=$((total_freed + size/1024))
        done < <(find "$VOLUME/temp" -type f \( -name "*.log" -o -name "*.tmp" \) -mtime +$age_days -print0 2>/dev/null)

        # Remove empty directories
        find "$VOLUME/temp" -type d -empty -delete 2>/dev/null
    fi

    echo $total_freed
}

# Clean package-lock.json files (can be regenerated)
clean_lockfiles() {
    local total_freed=0

    log "Cleaning stale lockfiles..."

    while IFS= read -r -d '' file; do
        # Only remove if corresponding node_modules doesn't exist
        dir=$(dirname "$file")
        if [ ! -d "$dir/node_modules" ]; then
            size=$(du -sk "$file" 2>/dev/null | cut -f1)
            rm -f "$file" 2>/dev/null
            total_freed=$((total_freed + size/1024))
        fi
    done < <(find "$VOLUME/github.com" -name "package-lock.json" -type f -mtime +30 -print0 2>/dev/null)

    echo $total_freed
}

# Main cleanup logic
run_cleanup() {
    local mode=$1  # "normal" or "aggressive"
    local total_freed=0

    log "=== Starting $mode cleanup ==="

    if [ "$mode" = "aggressive" ]; then
        # Aggressive: shorter age thresholds
        freed=$(clean_node_modules 3)
        total_freed=$((total_freed + freed))

        freed=$(clean_wrangler_caches 1)
        total_freed=$((total_freed + freed))

        freed=$(clean_temp 7)
        total_freed=$((total_freed + freed))

        freed=$(clean_lockfiles)
        total_freed=$((total_freed + freed))
    else
        # Normal cleanup
        freed=$(clean_node_modules $NODE_MODULES_AGE_DAYS)
        total_freed=$((total_freed + freed))

        freed=$(clean_wrangler_caches $WRANGLER_CACHE_AGE_DAYS)
        total_freed=$((total_freed + freed))

        freed=$(clean_temp $TEMP_FILE_AGE_DAYS)
        total_freed=$((total_freed + freed))
    fi

    # Get new disk usage
    NEW_INFO=$(df "$VOLUME" | tail -1)
    NEW_USAGE=$(echo "$NEW_INFO" | awk '{print $5}' | sed 's/%//')
    NEW_AVAIL=$(echo "$NEW_INFO" | awk '{gsub(/Gi?/, "G"); print $4}')

    log "=== Cleanup complete ==="
    log "  Freed: ${total_freed}MB"
    log "  Usage: ${DISK_USAGE}% -> ${NEW_USAGE}%"
    log "  Available: $NEW_AVAIL"

    if [ "$total_freed" -gt 100 ]; then
        notify "ChittyOS Cleanup" "Freed ${total_freed}MB on dev volume. Now $NEW_AVAIL free."
    fi
}

# Check disk and decide action
log "Checking /Volumes/chitty: ${DISK_USAGE}% used ($DISK_AVAIL available)"

if [ "$DISK_USAGE" -gt "$CRITICAL_PERCENT" ]; then
    log "CRITICAL: Disk >$CRITICAL_PERCENT% full!"
    notify "ChittyOS Volume Critical" "Dev volume is ${DISK_USAGE}% full! Running aggressive cleanup..."
    run_cleanup "aggressive"
elif [ "$DISK_USAGE" -gt "$THRESHOLD_PERCENT" ]; then
    log "WARNING: Disk >$THRESHOLD_PERCENT% full"
    run_cleanup "normal"
else
    log "OK: Disk usage acceptable"

    # Still do light maintenance daily
    if [ "$(date +%H)" = "03" ]; then  # Run at 3 AM
        log "Running scheduled maintenance..."
        clean_wrangler_caches $WRANGLER_CACHE_AGE_DAYS > /dev/null
    fi
fi

exit 0
