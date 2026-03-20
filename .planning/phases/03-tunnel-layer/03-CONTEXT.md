# Phase 3: Tunnel Layer - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Pluggable tunnel architecture with ngrok as default provider. Tunnel starts automatically with workspace, auto-reconnects on failure, and exposes a CLI command for checking the current address. Replaces V1's inline ngrok usage and port.sh with a proper abstraction layer.

Requirements: TUN-01, TUN-02, TUN-03, TUN-04

</domain>

<decisions>
## Implementation Decisions

### Tunnel Provider Interface
- Each provider is a sourced bash module in `lib/tunnel/` directory (e.g., `lib/tunnel/ngrok.sh`)
- Active provider configured via `TUNNEL_PROVIDER=ngrok` in `~/.cc-tmux/config.env`
- A `lib/tunnel/provider.sh` sources the configured provider module
- Every provider MUST implement 4 functions: `tunnel_start()`, `tunnel_stop()`, `tunnel_status()`, `tunnel_url()`
- If provider module is missing: error with list of available providers found in `lib/tunnel/`
- ngrok is the only provider shipped in v1 — architecture supports adding more (Tailscale, Cloudflare) later

### Auto-Reconnect Strategy
- Background watchdog loop that checks tunnel health every 30 seconds
- Health check: verify ngrok process is running AND `/api/tunnels` endpoint responds
- On failure: restart tunnel with exponential backoff (30s, 60s, 120s, cap at 5 minutes)
- Unlimited reconnect attempts (ngrok free tier has 2-hour session limits, so this will fire regularly)
- All reconnections logged to `~/.cc-tmux/tunnel.log` with timestamps
- Watchdog runs as a background bash loop (not a systemd service — WSL2 systemd is unreliable)
- Watchdog PID stored in `~/.cc-tmux/tunnel-watchdog.pid` for cleanup

### Status/Address Command
- `cc-tmux tunnel` (or equivalent function) shows: provider name, address, port, status (connected/reconnecting/down)
- Tunnel address persisted to `~/.cc-tmux/tunnel.env` as `TUNNEL_HOST=...` and `TUNNEL_PORT=...`
- Updated on every successful tunnel start and reconnection
- Status works even when tunnel is down — shows "down" with last known address and watchdog status
- Default output is human-readable; `--json` flag for scripting
- Replaces V1's `port.sh` script entirely

### Startup Integration
- `startup.sh` (or equivalent) calls `tunnel_start` after verifying SSH is running
- If tunnel fails on startup: warn but continue — workspace is usable locally without tunnel
- Display tunnel address on every tmux attach for quick reference (write to a tmux status message or display command)
- `tunnel_stop` called during clean shutdown / uninstall

### Claude's Discretion
- Whether to use `nohup` or process substitution for the watchdog
- Exact format of human-readable status output
- Whether to add tunnel address to tmux status bar (may be Phase 4's concern)
- How to handle the case where ngrok isn't authenticated (no token configured)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing tunnel code (V1 reference)
- `V1/startup.sh` — V1's inline ngrok start with curl to /api/tunnels for address
- `V1/port.sh` — V1's address check script (being replaced)

### Phase 1 foundations
- `lib/common.sh` — Utility functions (logging, guards, system checks)
- `lib/config.sh` — Config management (write_config, read_config for tunnel.env)
- `lib/deps.sh` — ngrok installation and token setup (already handled)
- `install.sh` — Entry point for adding tunnel module sourcing

### Research
- `.planning/research/STACK.md` — Tunnel comparison (ngrok vs Tailscale vs Cloudflare), ngrok free tier limits
- `.planning/research/ARCHITECTURE.md` — Pluggable tunnel provider design, tunnel/ directory structure
- `.planning/research/PITFALLS.md` — ngrok 2-hour session limits, snap install failure, address churn

### Project
- `.planning/PROJECT.md` — Core value (non-technical users), constraints (bash-only)
- `.planning/REQUIREMENTS.md` — TUN-01 through TUN-04 acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/deps.sh:install_ngrok()` — ngrok already installed by Phase 1 installer
- `lib/deps.sh:setup_ngrok_token()` — Token already configured during install
- `lib/config.sh:write_config()` — Can write TUNNEL_PROVIDER and tunnel.env values
- `lib/config.sh:read_config()` — Can read provider selection from config.env
- `lib/common.sh:log_*()` — All logging functions available

### Established Patterns
- Sourced modules: `lib/tunnel/provider.sh` follows same pattern as other lib/ files
- Config in `~/.cc-tmux/`: tunnel.env sits alongside config.env and projects.conf
- Idempotent operations: check-before-act pattern (check if tunnel is already running)
- PID file pattern: can follow V1's approach but with proper cleanup

### Integration Points
- `install.sh` — Needs to source `lib/tunnel/provider.sh` and add tunnel step
- `~/.cc-tmux/config.env` — Stores `TUNNEL_PROVIDER=ngrok`
- `~/.cc-tmux/tunnel.env` — New file for persisted tunnel address
- `~/.cc-tmux/tunnel.log` — New file for watchdog logging
- Future `bin/cc-tmux` CLI (Phase 5) — Will wrap tunnel_status as a subcommand

</code_context>

<specifics>
## Specific Ideas

- ngrok free tier now limits sessions to ~2 hours — auto-reconnect is essential, not optional
- V1's `port.sh` was a pain point because users had to exit PowerShell to bash first — the new command should work from anywhere
- Tunnel address changing on reconnect is unavoidable with ngrok free tier — persist and display clearly

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-tunnel-layer*
*Context gathered: 2026-03-20*
