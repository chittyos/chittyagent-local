# ChittyAgent Local

Local system agents for macOS, running via launchd. This is the counterpart to `chittyagent` (cloud agents on Cloudflare Workers).

## Architecture

| Repo | Runtime | Purpose |
|------|---------|---------|
| `chittyagent` | Cloudflare Workers | Cloud AI agents |
| `chittyagent-local` | macOS launchd | Local system agents |

## Directory Structure

```
chittyagent-local/
├── agents/                    # Individual agents
│   ├── cleaner/               # Disk cleanup agent
│   │   ├── scripts/           # Bash scripts
│   │   ├── skills/            # Skill definitions
│   │   ├── config/            # Agent-specific config
│   │   ├── manifest.json      # Agent manifest
│   │   └── README.md          # Agent documentation
│   └── {future-agent}/        # Future agents follow same pattern
├── shared/                    # Common bash functions
│   └── common.sh              # Logging, utilities, ChittyOS paths
├── launchd/                   # LaunchAgent plist templates
├── scripts/                   # Repo-level install/uninstall
└── CLAUDE.md                  # This file
```

## Agent Pattern

Each agent in `agents/` follows this structure:

```
agents/{name}/
├── scripts/           # Executable scripts
│   ├── {skill-1}.sh   # One script per skill
│   └── {skill-2}.sh
├── skills/            # Skill metadata (optional)
├── config/            # Default configuration
├── manifest.json      # Agent definition
└── README.md          # Documentation
```

### manifest.json Schema

```json
{
  "name": "chittyagent-{name}",
  "version": "1.0.0",
  "description": "What this agent does",
  "tier": 3,
  "category": "operations|monitoring|backup|...",
  "status": "active",
  "skills": [
    {
      "name": "skill-name",
      "description": "What this skill does",
      "script": "scripts/skill-name.sh",
      "triggers": ["interval:1800", "threshold:60%"],
      "targets": ["what it operates on"]
    }
  ],
  "launchAgents": [
    {
      "label": "com.chittyos.{name}.{skill}",
      "skill": "skill-name",
      "interval": 1800,
      "script": "scripts/skill-name.sh",
      "priority": 10
    }
  ],
  "config": {}
}
```

## Creating a New Agent

1. Create directory: `agents/{name}/`
2. Add scripts to `agents/{name}/scripts/`
3. Source common functions: `source "$(dirname "$0")/../../shared/common.sh"`
4. Create `manifest.json` following schema above
5. Add launchd plist to `launchd/` if needed
6. Document in `agents/{name}/README.md`

## Shared Functions

All scripts should source `shared/common.sh` for:

- `log_info`, `log_success`, `log_warn`, `log_error` - Colored logging
- `get_disk_usage` - Disk usage percentage
- `format_bytes` - Human-readable byte formatting
- `safe_delete` - Delete with dry-run support
- `load_agent_config` - Load agent configuration
- `save_agent_state` - Persist agent state
- `ensure_chittyos_dirs` - Create ~/.chittyos directories

## ChittyOS Paths

| Path | Purpose |
|------|---------|
| `~/.chittyos/` | ChittyOS home directory |
| `~/.chittyos/logs/` | Agent logs |
| `~/.chittyos/insights/` | Recommendations, reports |
| `~/.chittyos/agents/{name}/` | Per-agent state and config |

## Development

```bash
# Test a script directly
./agents/cleaner/scripts/local-cleanup.sh --dry-run

# Install launchd agents
./scripts/install.sh

# Uninstall launchd agents
./scripts/uninstall.sh

# View agent logs
tail -f ~/.chittyos/logs/cleaner.log
```

## Relationship to Cloud Agents

Local agents complement cloud agents:

| Local Agent | Cloud Agent | Integration |
|-------------|-------------|-------------|
| `agents/cleaner/` | `chittyagent-cleaner` (kondo.chitty.cc) | Local executes, cloud analyzes |

Local agents can POST results to cloud agents for aggregation and AI-powered insights.
