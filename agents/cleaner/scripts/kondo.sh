#!/bin/bash

##############################################
# ChittyKondo - Proactive Disk Organization Daemon
# "Does this spark joy? If not, let's prevent it."
#
# Analyzes cleanup patterns from sibling daemons and
# makes proactive recommendations for optimization.
##############################################

INSIGHTS_DIR="$HOME/.chittyos/insights"
LOG_FILE="$INSIGHTS_DIR/kondo.log"
RECOMMENDATIONS_FILE="$INSIGHTS_DIR/recommendations.md"
PATTERNS_DB="$INSIGHTS_DIR/patterns.json"
LOCAL_CLEANUP_LOG="$HOME/.cleanup-log.txt"
VOLUME_CLEANUP_LOG="/Volumes/chitty/temp/.cleanup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
TODAY=$(date '+%Y-%m-%d')

# Ensure directories exist
mkdir -p "$INSIGHTS_DIR"

# Initialize patterns DB if not exists
if [ ! -f "$PATTERNS_DB" ]; then
    echo '{"cloudkit_fills":[],"npm_growth":[],"node_modules_recur":[],"critical_events":[],"last_analysis":""}' > "$PATTERNS_DB"
fi

log() {
    echo "[$DATE] $1" >> "$LOG_FILE"
}

notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
}

# Parse cleanup logs and extract metrics
analyze_local_log() {
    if [ ! -f "$LOCAL_CLEANUP_LOG" ]; then
        return
    fi

    # Count critical events in last 7 days
    local critical_count=$(grep -c "CRITICAL" "$LOCAL_CLEANUP_LOG" 2>/dev/null || echo 0)

    # Find CloudKit cleanup frequency
    local cloudkit_cleanups=$(grep -c "CloudKit:" "$LOCAL_CLEANUP_LOG" 2>/dev/null || echo 0)
    local cloudkit_total_mb=$(grep "CloudKit:" "$LOCAL_CLEANUP_LOG" 2>/dev/null | \
        sed 's/.*freed \([0-9]*\)MB.*/\1/' | \
        awk '{sum+=$1} END {print sum+0}')

    # NPX cache patterns
    local npx_cleanups=$(grep -c "NPX cache:" "$LOCAL_CLEANUP_LOG" 2>/dev/null || echo 0)

    # node_modules patterns
    local nm_cleanups=$(grep -c "node_modules:" "$LOCAL_CLEANUP_LOG" 2>/dev/null || echo 0)
    local nm_dirs=$(grep "node_modules:" "$LOCAL_CLEANUP_LOG" 2>/dev/null | \
        sed 's/.*from //' | sort | uniq -c | sort -rn | head -5)

    echo "$critical_count|$cloudkit_cleanups|$cloudkit_total_mb|$npx_cleanups|$nm_cleanups"
}

analyze_volume_log() {
    if [ ! -f "$VOLUME_CLEANUP_LOG" ]; then
        return
    fi

    local wrangler_cleanups=$(grep -c "wrangler" "$VOLUME_CLEANUP_LOG" 2>/dev/null || echo 0)
    local nm_cleanups=$(grep -c "node_modules" "$VOLUME_CLEANUP_LOG" 2>/dev/null || echo 0)

    echo "$wrangler_cleanups|$nm_cleanups"
}

# Detect recurring patterns
detect_patterns() {
    log "Analyzing patterns..."

    local local_stats=$(analyze_local_log)
    local volume_stats=$(analyze_volume_log)

    IFS='|' read -r critical cloudkit_count cloudkit_mb npx_count nm_count <<< "$local_stats"

    # Pattern: CloudKit fills frequently
    if [ "${cloudkit_count:-0}" -gt 5 ] && [ "${cloudkit_mb:-0}" -gt 5000 ]; then
        echo "CLOUDKIT_HEAVY"
    fi

    # Pattern: Frequent critical events
    if [ "${critical:-0}" -gt 3 ]; then
        echo "FREQUENT_CRITICAL"
    fi

    # Pattern: NPX cache grows fast
    if [ "${npx_count:-0}" -gt 3 ]; then
        echo "NPX_HEAVY"
    fi

    # Pattern: Same node_modules dirs keep returning
    if [ "${nm_count:-0}" -gt 5 ]; then
        echo "NODE_MODULES_RECUR"
    fi
}

# Generate recommendations based on patterns
generate_recommendations() {
    local patterns="$1"
    local recs=""

    cat > "$RECOMMENDATIONS_FILE" << 'HEADER'
# ChittyKondo Recommendations
*Last updated: TIMESTAMP*

Based on analysis of cleanup patterns, here are proactive recommendations:

HEADER
    sed -i '' "s/TIMESTAMP/$DATE/" "$RECOMMENDATIONS_FILE"

    if echo "$patterns" | grep -q "CLOUDKIT_HEAVY"; then
        cat >> "$RECOMMENDATIONS_FILE" << 'REC1'
## CloudKit Cache Management

**Pattern Detected:** CloudKit cache repeatedly fills to 10GB+

**Recommendations:**
1. **Reduce iCloud sync scope** - Review what's syncing in System Preferences > Apple ID > iCloud
2. **Disable iCloud Drive for large folders** - Desktop & Documents sync can cause rapid cache growth
3. **Consider adjusting cleanup threshold** - Current cleaner waits until 70% disk usage; CloudKit could be cleaned more aggressively

**Suggested Automation:**
```bash
# Add to crontab: Clean CloudKit if >5GB regardless of disk usage
0 */4 * * * [ $(du -sm ~/Library/Caches/CloudKit 2>/dev/null | cut -f1) -gt 5000 ] && rm -rf ~/Library/Caches/CloudKit/*
```

---
REC1
    fi

    if echo "$patterns" | grep -q "FREQUENT_CRITICAL"; then
        cat >> "$RECOMMENDATIONS_FILE" << 'REC2'
## Frequent Critical Disk Events

**Pattern Detected:** Disk reached >85% full multiple times recently

**Recommendations:**
1. **Lower warning threshold** - Consider triggering cleanup at 60% instead of 70%
2. **Increase cleanup frequency** - Run every 30 minutes instead of hourly during work hours
3. **Add proactive cleanup** - Don't wait for threshold; clean caches daily regardless

**Suggested Config Change:**
```bash
# In ~/.chittycleaner/auto-cleanup-monitor.sh, change:
THRESHOLD=60  # Was 70
CRITICAL=75   # Was 85
```

---
REC2
    fi

    if echo "$patterns" | grep -q "NPX_HEAVY"; then
        cat >> "$RECOMMENDATIONS_FILE" << 'REC3'
## NPX Cache Growth

**Pattern Detected:** NPX cache repeatedly grows to 1GB+

**Recommendations:**
1. **Use global installs** for frequently-used tools instead of npx
2. **Add aliases** for common npx commands to avoid cache buildup:
   ```bash
   alias create-next='npm create next-app'
   alias wrangler='npx wrangler'
   ```
3. **Clear on every cleanup** regardless of size (already implemented)

**Consider Installing Globally:**
- `npm i -g wrangler` (if using Cloudflare frequently)
- `npm i -g create-react-app` (if creating React apps often)

---
REC3
    fi

    if echo "$patterns" | grep -q "NODE_MODULES_RECUR"; then
        cat >> "$RECOMMENDATIONS_FILE" << 'REC4'
## Recurring node_modules

**Pattern Detected:** Same project directories repeatedly accumulate node_modules

**Recommendations:**
1. **Use pnpm** - Shared dependency store, ~60% less disk usage
2. **Use npm workspaces** - Share dependencies across related projects
3. **Archive inactive projects** - Move to /Volumes/chitty/archive with a manifest

**Frequently Cleaned Directories:**
Review these projects - consider archiving or using pnpm:
$(grep "node_modules:" "$LOCAL_CLEANUP_LOG" 2>/dev/null | sed 's/.*from //' | sort | uniq -c | sort -rn | head -5 | sed 's/^/- /')

---
REC4
    fi

    # Add general tips
    cat >> "$RECOMMENDATIONS_FILE" << 'GENERAL'
## General Optimization Tips

1. **Weekly manual review** - Run `du -sh ~/* | sort -hr | head -10` to spot growth
2. **Monitor Docker** - `docker system df` shows reclaimable space
3. **Homebrew cleanup** - `brew cleanup --prune=7` removes old versions
4. **Check Downloads** - Often accumulates unneeded files

## Current Daemon Status

| Daemon | Target | Frequency | Status |
|--------|--------|-----------|--------|
| chittycleaner.auto | Local disk | Hourly | Active |
| chittyos.volume-cleanup | /Volumes/chitty | Hourly | Active |
| chittyos.kondo | Both (analysis) | Daily | Active |

---
*Generated by ChittyKondo - Your proactive disk organizer*
GENERAL

    log "Generated recommendations: $RECOMMENDATIONS_FILE"
}

# Check if action is needed
check_and_recommend() {
    local patterns=$(detect_patterns)

    if [ -n "$patterns" ]; then
        log "Patterns detected: $patterns"
        generate_recommendations "$patterns"

        # Notify if significant patterns found
        local pattern_count=$(echo "$patterns" | wc -w | tr -d ' ')
        if [ "$pattern_count" -gt 1 ]; then
            notify "ChittyKondo Insights" "$pattern_count optimization opportunities found. Check ~/.chittyos/insights/recommendations.md"
        fi
    else
        log "No significant patterns detected"
    fi
}

# Weekly summary
generate_weekly_summary() {
    local week_start=$(date -v-7d '+%Y-%m-%d')
    local summary_file="$INSIGHTS_DIR/weekly-summary-$TODAY.md"

    cat > "$summary_file" << SUMMARY
# ChittyKondo Weekly Summary
*Week of $week_start to $TODAY*

## Cleanup Activity

### Local Disk
- Critical events: $(grep -c "CRITICAL" "$LOCAL_CLEANUP_LOG" 2>/dev/null || echo 0)
- Total cleanups: $(grep -c "Auto-cleanup triggered" "$LOCAL_CLEANUP_LOG" 2>/dev/null || echo 0)
- CloudKit cleaned: $(grep "CloudKit:" "$LOCAL_CLEANUP_LOG" 2>/dev/null | sed 's/.*freed \([0-9]*\)MB.*/\1/' | awk '{sum+=$1} END {print sum+0}')MB

### ChittyOS Volume
- Cleanups triggered: $(grep -c "cleanup" "$VOLUME_CLEANUP_LOG" 2>/dev/null || echo 0)
- Current usage: $(df -h /Volumes/chitty 2>/dev/null | tail -1 | awk '{print $5}')

## Top Space Consumers (Local)
$(du -sh ~/Library/Caches ~/Desktop ~/Downloads ~/.npm 2>/dev/null | sort -hr)

## Recommendations
See: $RECOMMENDATIONS_FILE

---
*Next summary: $(date -v+7d '+%Y-%m-%d')*
SUMMARY

    log "Generated weekly summary: $summary_file"
    notify "ChittyKondo Weekly Summary" "Your disk organization report is ready"
}

# Main execution
log "=== ChittyKondo Analysis Started ==="

# Always check patterns
check_and_recommend

# Generate weekly summary on Sundays
if [ "$(date +%u)" = "7" ]; then
    generate_weekly_summary
fi

# Log current disk status
LOCAL_USAGE=$(df -h ~ | tail -1 | awk '{print $5}')
VOLUME_USAGE=$(df -h /Volumes/chitty 2>/dev/null | tail -1 | awk '{print $5}' || echo "N/A")
log "Current disk status - Local: $LOCAL_USAGE, ChittyOS Volume: $VOLUME_USAGE"

log "=== ChittyKondo Analysis Complete ==="
exit 0
