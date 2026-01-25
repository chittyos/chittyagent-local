#!/bin/bash

##############################################
# Auto Disk Cleanup Monitor for Mac
# Runs cleanup automatically when disk gets full
# Shows native macOS notifications
##############################################

LOG_FILE="$HOME/.cleanup-log.txt"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Configuration
THRESHOLD=70  # Run cleanup when disk is >70% full
CRITICAL=85   # Show warning when >85% full

# Get current disk usage percentage
DISK_USAGE=$(df -h ~ | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h ~ | tail -1 | awk '{print $4}')

# Function to show native Mac notification
notify() {
    local title="$1"
    local message="$2"
    local sound="$3"  # Glass, Blow, Bottle, Frog, Funk, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

    osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
}

# Function to show dialog with buttons
show_dialog() {
    local message="$1"
    local button1="$2"
    local button2="$3"

    result=$(osascript -e "button returned of (display dialog \"$message\" buttons {\"$button1\", \"$button2\"} default button 2)")
    echo "$result"
}

# Function to get directory size safely
get_size() {
    du -sk "$1" 2>/dev/null | cut -f1 || echo 0
}

# Function to run cleanup
run_cleanup() {
    echo "[$DATE] Auto-cleanup triggered at ${DISK_USAGE}% usage" >> "$LOG_FILE"

    total_freed=0

    # 1. CloudKit cache (can grow to 20GB+)
    if [ -d "$HOME/Library/Caches/CloudKit" ]; then
        before=$(get_size "$HOME/Library/Caches/CloudKit")
        # Remove all CloudKit cache - it rebuilds automatically
        rm -rf "$HOME/Library/Caches/CloudKit"/* 2>/dev/null
        after=$(get_size "$HOME/Library/Caches/CloudKit")
        freed=$((before - after))
        total_freed=$((total_freed + freed))
        echo "  CloudKit: freed $((freed / 1024))MB" >> "$LOG_FILE"
    fi

    # 2. Browser caches
    for cache in "Google/Chrome" "com.apple.Safari" "Firefox"; do
        cache_path="$HOME/Library/Caches/$cache"
        if [ -d "$cache_path" ]; then
            before=$(get_size "$cache_path")
            rm -rf "$cache_path"/* 2>/dev/null
            after=$(get_size "$cache_path")
            freed=$((before - after))
            total_freed=$((total_freed + freed))
            [ "$freed" -gt 102400 ] && echo "  Browser cache: freed $((freed / 1024))MB from $cache" >> "$LOG_FILE"
        fi
    done

    # 3. Claude logs
    if [ -d "$HOME/.claude/logs" ]; then
        before=$(get_size "$HOME/.claude/logs")
        find "$HOME/.claude/logs" -type f -mtime +7 -delete 2>/dev/null
        after=$(get_size "$HOME/.claude/logs")
        freed=$((before - after))
        total_freed=$((total_freed + freed))
    fi

    # 4. Claude debug
    if [ -d "$HOME/.claude/debug" ]; then
        before=$(get_size "$HOME/.claude/debug")
        rm -rf "$HOME/.claude/debug"/*.txt 2>/dev/null
        after=$(get_size "$HOME/.claude/debug")
        freed=$((before - after))
        total_freed=$((total_freed + freed))
    fi

    # 5. NPM cache
    if [ -d "$HOME/.npm/_cacache" ]; then
        before=$(get_size "$HOME/.npm/_cacache")
        rm -rf "$HOME/.npm/_cacache"/* 2>/dev/null
        after=$(get_size "$HOME/.npm/_cacache")
        freed=$((before - after))
        total_freed=$((total_freed + freed))
    fi

    # 5b. NPX cache (can grow to 1GB+)
    if [ -d "$HOME/.npm/_npx" ]; then
        before=$(get_size "$HOME/.npm/_npx")
        rm -rf "$HOME/.npm/_npx"/* 2>/dev/null
        after=$(get_size "$HOME/.npm/_npx")
        freed=$((before - after))
        total_freed=$((total_freed + freed))
        [ "$freed" -gt 10240 ] && echo "  NPX cache: freed $((freed / 1024))MB" >> "$LOG_FILE"
    fi

    # 5c. Local node_modules not accessed in 7 days
    for proj_dir in "$HOME/Desktop/Projects" "$HOME/codex" "$HOME/temp"; do
        if [ -d "$proj_dir" ]; then
            while IFS= read -r -d '' nm_dir; do
                if [ "$(find "$nm_dir" -maxdepth 0 -atime +7 2>/dev/null)" ]; then
                    before=$(get_size "$nm_dir")
                    rm -rf "$nm_dir" 2>/dev/null
                    freed=$before
                    total_freed=$((total_freed + freed))
                    [ "$freed" -gt 51200 ] && echo "  node_modules: freed $((freed / 1024))MB from $(dirname "$nm_dir")" >> "$LOG_FILE"
                fi
            done < <(find "$proj_dir" -name "node_modules" -type d -prune -print0 2>/dev/null)
        fi
    done

    # 6. Homebrew
    if command -v brew >/dev/null 2>&1; then
        brew cleanup -s >/dev/null 2>&1
    fi

    # 7. Xcode
    if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
        find "$HOME/Library/Developer/Xcode/DerivedData" -type d -maxdepth 1 -mtime +3 -exec rm -rf {} \; 2>/dev/null
    fi

    # 8. Temporary files
    find "$HOME/Library/Caches" -type f -name "*.tmp" -mtime +3 -delete 2>/dev/null

    # 9. Wrangler logs (can grow large)
    if [ -d "$HOME/Library/Preferences/.wrangler/logs" ]; then
        before=$(get_size "$HOME/Library/Preferences/.wrangler/logs")
        find "$HOME/Library/Preferences/.wrangler/logs" -type f -mtime +3 -delete 2>/dev/null
        after=$(get_size "$HOME/Library/Preferences/.wrangler/logs")
        freed=$((before - after))
        total_freed=$((total_freed + freed))
    fi

    # 10. OpenAI/ChatGPT caches
    for app_cache in "com.openai.atlas" "com.openai.chat"; do
        if [ -d "$HOME/Library/Caches/$app_cache" ]; then
            before=$(get_size "$HOME/Library/Caches/$app_cache")
            rm -rf "$HOME/Library/Caches/$app_cache"/* 2>/dev/null
            after=$(get_size "$HOME/Library/Caches/$app_cache")
            freed=$((before - after))
            total_freed=$((total_freed + freed))
        fi
    done

    # 11. pnpm store (if over 2GB)
    if [ -d "$HOME/.pnpm-store" ]; then
        store_size=$(get_size "$HOME/.pnpm-store")
        if [ "$store_size" -gt 2097152 ]; then  # > 2GB
            pnpm store prune 2>/dev/null
        fi
    fi

    # 12. Docker (if installed and using lots of space)
    if command -v docker >/dev/null 2>&1; then
        docker system prune -f 2>/dev/null
    fi

    # Convert to GB
    total_gb=$((total_freed / 1024 / 1024))
    total_mb=$((total_freed / 1024))

    # Get new disk usage
    NEW_USAGE=$(df -h ~ | tail -1 | awk '{print $5}' | sed 's/%//')
    NEW_AVAIL=$(df -h ~ | tail -1 | awk '{print $4}')

    if [ $total_gb -gt 0 ]; then
        echo "  Freed: ${total_gb}GB" >> "$LOG_FILE"
        notify "Cleanup Complete" "Freed ${total_gb}GB of disk space!\nNow ${NEW_AVAIL} available (${NEW_USAGE}% used)" "Hero"
    elif [ $total_mb -gt 0 ]; then
        echo "  Freed: ${total_mb}MB" >> "$LOG_FILE"
        notify "Cleanup Complete" "Freed ${total_mb}MB of disk space!\nNow ${NEW_AVAIL} available (${NEW_USAGE}% used)" "Ping"
    else
        echo "  Nothing to clean" >> "$LOG_FILE"
    fi

    echo "  New usage: ${NEW_USAGE}% (${NEW_AVAIL} available)" >> "$LOG_FILE"
}

# Main monitoring logic
echo "[$DATE] Checking disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available)" >> "$LOG_FILE"

# CRITICAL: >85% full - Show urgent notification and clean aggressively
if [ "$DISK_USAGE" -gt "$CRITICAL" ]; then
    echo "  ⚠️  CRITICAL: Disk >${CRITICAL}% full!" >> "$LOG_FILE"

    # Show urgent notification
    notify "⚠️ Disk Almost Full!" "Your disk is ${DISK_USAGE}% full (only ${DISK_AVAIL} left)!\nCleaning up now..." "Sosumi"

    # Run cleanup automatically
    run_cleanup

# WARNING: >80% full - Run cleanup automatically
elif [ "$DISK_USAGE" -gt "$THRESHOLD" ]; then
    echo "  ⚠️  WARNING: Disk >${THRESHOLD}% full, auto-cleaning..." >> "$LOG_FILE"

    # Show notification
    notify "Auto Cleanup Starting" "Disk is ${DISK_USAGE}% full. Running cleanup..." "Tink"

    # Run cleanup
    run_cleanup

# OK: <80% full - All good
else
    echo "  ✓ Disk usage OK" >> "$LOG_FILE"
fi

exit 0
