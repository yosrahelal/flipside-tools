# Flipside CLI

Build and deploy AI agents for blockchain analytics. Query 40+ chains, analyze wallets, track DeFi protocols, and more.

## Install

**Mac/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/FlipsideCrypto/flipside-tools/main/install.sh | sh
```

**Windows:** Download the latest exe from [releases](https://github.com/flipsidecrypto/flipside-cli/releases) or use `wsl`

## Quick Start

```bash
# 1. Initialize with your API key (get one at flipsidecrypto.xyz/chat/settings/mcp-keys)
flipside init

# 2. Generate example agents in current directory
flipside quickstart ./flipside-agents && cd flipside-agents

# 3. Deploy and run an example
flipside agent push defi_analyst.agent.yaml
flipside agent run defi_analyst --message "What's the TVL on Aave?"
```

That's it! You now have a DeFi analyst agent ready to query blockchain data.

---

## Example Agents

After running `flipside quickstart`, you'll have these example agents:

| Agent | Type | What it does |
|-------|------|--------------|
| `defi_analyst` | chat | Analyze DeFi protocols - TVL, liquidity, DEX volume |
| `top_tokens` | sub | Fetch top tokens by trading volume as structured JSON |
| `ethereum_lending_csv` | sub | Export CSV snapshots for Ethereum lending protocols (Aave v1–v3, Compound v2/v3, MakerDAO) |

```bash
# Chat agent - natural language
flipside agent run defi_analyst --message "Top DEX protocols by volume this week"

# Sub agent - structured JSON input
flipside agent run top_tokens --data-json '{"chain": "ethereum", "limit": 10}'
```

### Test the `ethereum_lending_csv` example

The lending CSV agent ships in `examples/ethereum_lending_csv.agent.yaml` and expects Ethereum mainnet data. To try it:

```bash
# Validate and deploy the agent definition
flipside agent validate examples/ethereum_lending_csv.agent.yaml
flipside agent push examples/ethereum_lending_csv.agent.yaml

# Run it with optional date filters (sub agent uses JSON input)
flipside agent run ethereum_lending_csv \
  --data-json '{"start_date": "2024-01-01", "end_date": "2024-01-07"}' \
  --json > lending_csv_output.json

# Write the returned CSV payloads to files under ./csv/
python - <<'PY'
import json, os
payload = json.load(open('lending_csv_output.json'))
os.makedirs('csv', exist_ok=True)
for item in payload.get('csv_outputs', []):
    path = os.path.join('csv', item['filename'])
    with open(path, 'w') as f:
        f.write(item['csv'])
        print(f"wrote {path}")
PY
```

The agent produces one CSV per protocol (Aave v1/v2/v3, Compound v2/v3, MakerDAO) with the standardized columns described in the YAML.

---

## Build Your Own Agent

### Create a new agent
```bash
flipside agent init my_agent              # Chat agent (conversational)
flipside agent init my_parser --kind sub  # Sub agent (structured I/O)
```

### Edit the YAML file
```yaml
name: my_agent
kind: chat
description: "What this agent does"

systemprompt: |
  You are an expert at... [customize this]

tools:
  - name: run_sql_query    # Query blockchain data
  - name: find_tables      # Discover available tables
  - name: search_web       # Web search for context

maxturns: 10
metadata:
  model: claude-4-5-haiku
```

### Deploy and run
```bash
flipside agent validate my_agent.agent.yaml
flipside agent push my_agent.agent.yaml
flipside agent run my_agent --message "Hello!"
```

---

## Available Tools

Your agents can use these tools:

| Tool | Description |
|------|-------------|
| `run_sql_query` | Execute SQL against 40+ blockchain datasets |
| `find_tables` | Semantic search to discover relevant tables |
| `get_table_schema` | Get column details for a table |
| `search_web` | Search the web for context |
| `get_swap_quote` | Get cross-chain swap quotes |
| `execute_swap` | Execute a cross-chain swap |
| `get_swap_status` | Check swap status |
| `get_swap_tokens` | List available swap tokens |
| `find_workflow` | Find pre-built analysis workflows |
| `publish_html` | Publish visualizations to a public URL |

List all tools: `flipside tools list`

---

## Run SQL Directly

Don't need an agent? Query data directly:

```bash
flipside query "SELECT * FROM ethereum.core.fact_blocks LIMIT 5"
```

---

## Use Catalog Agents

Flipside maintains pre-built agents you can use immediately:

```bash
# List available agents
flipside catalog agents list

# Run one
flipside catalog agents run data_analyst --message "What's trending in DeFi?"
```

---

## Interactive Chat

Start a REPL for continuous conversation:

```bash
flipside chat repl
```

---

## Stay Up to Date

```bash
flipside update
```

---

## Command Reference

```bash
# Setup
flipside init                        # Configure API key (interactive)
flipside quickstart [path]           # Generate example agents

# Agents
flipside agent init <name>           # Create new agent
flipside agent validate <file>       # Validate YAML
flipside agent push <file>           # Deploy agent
flipside agent run <name> --message  # Run chat agent
flipside agent run <name> --data-json # Run sub agent
flipside agent list                  # List your agents
flipside agent describe <name>       # View agent details
flipside agent delete <name>         # Delete agent

# Catalog
flipside catalog agents list         # List Flipside agents
flipside catalog agents run <name>   # Run catalog agent

# Tools
flipside tools list                  # List available tools
flipside tools execute <tool> <json> # Execute a tool directly

# Config
flipside config show                 # Show current config
flipside config set <key> <value>   # Update config value
```

### Global Flags

| Flag | Description |
|------|-------------|
| `-j, --json` | Output as JSON (for scripting) |
| `-v, --verbose` | Show request/response details |
| `--api-key` | Override API key for this command |

---

## API Reference

The CLI is a wrapper around Flipside's public REST API. For building your own integrations, see the [API Reference](./docs/API.md).

---

## Troubleshooting

**"API key not found"** → Run `flipside init`

**"Agent not found"** → Check `flipside agent list` for your agents

**Validation errors** → Run `flipside agent validate <file>` for details

**Debug mode** → Add `-v` flag to see full request/response

---

## Links

- [API Reference](./docs/API.md)
- [Flipside Docs](https://docs.flipsidecrypto.xyz)
