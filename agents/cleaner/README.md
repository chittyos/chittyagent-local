# ChittyAgent-Cleaner

Automated disk cleanup agent for the ChittyOS ecosystem. Manages disk space across local macOS and the ChittyOS development volume.

## Components

| Agent | Function | Interval |
|-------|----------|----------|
| **local-cleanup** | Cleans local macOS caches, logs, temp files | 30 min |
| **volume-cleanup** | Cleans /Volumes/chitty dev volume | 1 hour |
| **kondo** | Analyzes patterns, generates recommendations | 6 hours |

## Installation

```bash
/Volumes/chitty/github.com/CHITTYOS/chittyagent-cleaner/scripts/install.sh
```

## Uninstallation

```bash
/Volumes/chitty/github.com/CHITTYOS/chittyagent-cleaner/scripts/uninstall.sh
```

## What Gets Cleaned

### Local Disk (local-cleanup)
- CloudKit cache (can grow to 20GB+)
- Browser caches (Chrome, Safari, Firefox)
- npm/pnpm caches
- NPX cache
- Claude logs/debug files
- Xcode DerivedData
- Wrangler logs
- Docker unused resources

### ChittyOS Volume (volume-cleanup)
- Stale node_modules (>7 days inactive)
- .wrangler caches (>3 days old)
- Temp files (>14 days old)
- Orphaned lockfiles

### Kondo (Analysis)
- Pattern detection (frequent critical events, recurring cleanups)
- Proactive recommendations
- Weekly summaries

## Configuration

Thresholds in `manifest.json`:

```json
{
  "config": {
    "local": {
      "threshold": 60,
      "critical": 75
    },
    "volume": {
      "threshold": 70,
      "critical": 85
    }
  }
}
```

## Logs

| Log | Location |
|-----|----------|
| Local cleanup | `/tmp/chittyos-cleaner-local.out` |
| Volume cleanup | `/tmp/chittyos-cleaner-volume.out` |
| Kondo | `/tmp/chittyos-cleaner-kondo.out` |
| Activity log | `~/.cleanup-log.txt` |
| Volume log | `/Volumes/chitty/temp/.cleanup.log` |
| Recommendations | `~/.chittyos/insights/recommendations.md` |

## LaunchAgent Labels

- `com.chittyos.cleaner.local`
- `com.chittyos.cleaner.volume`
- `com.chittyos.cleaner.kondo`

## Manual Trigger

```bash
# Local cleanup
/Volumes/chitty/github.com/CHITTYOS/chittyagent-cleaner/scripts/local-cleanup.sh

# Volume cleanup
/Volumes/chitty/github.com/CHITTYOS/chittyagent-cleaner/scripts/volume-cleanup.sh

# Kondo analysis
/Volumes/chitty/github.com/CHITTYOS/chittyagent-cleaner/scripts/kondo.sh
```

## Service Info

- **Tier**: 3 (Operational)
- **Category**: Operations
- **Domain**: cleaner.chitty.cc
- **Repository**: https://github.com/CHITTYOS/chittyagent-cleaner
