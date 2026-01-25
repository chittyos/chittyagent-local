# ChittyAgent Local

Local system agents for macOS, running via launchd.

## Agents

| Agent | Description | Status |
|-------|-------------|--------|
| [cleaner](./agents/cleaner/) | Automated disk cleanup | Active |

## Quick Start

```bash
# Install all agents
./scripts/install.sh

# Test cleaner (dry-run)
./agents/cleaner/scripts/local-cleanup.sh --dry-run

# View logs
tail -f ~/.chittyos/logs/cleaner.log
```

## Architecture

This repo is the local counterpart to [`chittyagent`](https://github.com/CHITTYOS/chittyagent) (cloud agents):

| Repo | Runtime | Agents |
|------|---------|--------|
| `chittyagent` | Cloudflare Workers | Cloud AI agents |
| `chittyagent-local` | macOS launchd | Local system agents |

## Structure

```
├── agents/           # Individual agents
│   └── cleaner/      # Disk cleanup agent
├── shared/           # Common bash functions
├── launchd/          # LaunchAgent plists
└── scripts/          # Install/uninstall
```

## Adding an Agent

See [CLAUDE.md](./CLAUDE.md) for the full agent creation guide.

## License

MIT - ChittyOS
