# Phase 3: Tunnel Layer - Research

**Researched:** 2026-03-20
**Domain:** Bash tunnel abstraction layer with ngrok, background process supervision, pluggable provider pattern
**Confidence:** HIGH

## Summary

Phase 3 builds a pluggable tunnel architecture in `lib/tunnel/` that auto-starts an ngrok TCP tunnel with the workspace, monitors its health via a background watchdog, exposes a CLI command for checking the current address, and makes the provider swappable through a single config value. The ngrok free tier in 2026 supports TCP tunnels (5,000 connections/month, 100/min rate limit, up to 3 simultaneous endpoints) with NO session timeout -- endpoints can run indefinitely. However, TCP endpoints on the free plan require adding a valid payment method to the ngrok account (not charged, but must be on file). The tunnel URL format for TCP is `tcp://X.tcp.ngrok.io:PORT` where the port is randomly assigned and changes on restart.

The existing codebase provides strong foundations: `lib/common.sh` (logging, colors, guards), `lib/config.sh` (read/write config.env, subshell get_config), `lib/deps.sh` (ngrok installed via apt, token configured interactively), and `lib/setup.sh` (deploy_file, step patterns). The V1 `startup.sh` shows the basic ngrok start pattern (`nohup ngrok tcp 22`, curl to `/api/tunnels`, grep for URL) which must be replaced with proper jq parsing, a health watchdog, and the provider abstraction. V1's `port.sh` is a simple curl+grep that will be replaced by `tunnel_status()`.

**Primary recommendation:** Create `lib/tunnel/provider.sh` as the interface layer that sources the configured provider module, plus `lib/tunnel/ngrok.sh` as the default implementation. The watchdog should be a background bash loop using `nohup` with PID tracking in `~/.cc-tmux/tunnel-watchdog.pid`. Use both `/api/tunnels` (deprecated but still functional) and `/api/endpoints` (new) with fallback, parsing with `jq`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Each provider is a sourced bash module in `lib/tunnel/` directory (e.g., `lib/tunnel/ngrok.sh`)
- Active provider configured via `TUNNEL_PROVIDER=ngrok` in `~/.cc-tmux/config.env`
- A `lib/tunnel/provider.sh` sources the configured provider module
- Every provider MUST implement 4 functions: `tunnel_start()`, `tunnel_stop()`, `tunnel_status()`, `tunnel_url()`
- If provider module is missing: error with list of available providers found in `lib/tunnel/`
- ngrok is the only provider shipped -- architecture supports adding more later
- Background watchdog loop that checks tunnel health every 30 seconds
- Health check: verify ngrok process is running AND `/api/tunnels` endpoint responds
- On failure: restart tunnel with exponential backoff (30s, 60s, 120s, cap at 5 minutes)
- Unlimited reconnect attempts
- All reconnections logged to `~/.cc-tmux/tunnel.log` with timestamps
- Watchdog runs as a background bash loop (not systemd)
- Watchdog PID stored in `~/.cc-tmux/tunnel-watchdog.pid`
- `cc-tmux tunnel` shows: provider name, address, port, status (connected/reconnecting/down)
- Tunnel address persisted to `~/.cc-tmux/tunnel.env` as `TUNNEL_HOST=...` and `TUNNEL_PORT=...`
- Updated on every successful tunnel start and reconnection
- Status works even when tunnel is down -- shows "down" with last known address
- Default output is human-readable; `--json` flag for scripting
- `startup.sh` (or equivalent) calls `tunnel_start` after verifying SSH is running
- If tunnel fails on startup: warn but continue -- workspace is usable locally
- Display tunnel address on every tmux attach
- `tunnel_stop` called during clean shutdown / uninstall

### Claude's Discretion
- Whether to use `nohup` or process substitution for the watchdog
- Exact format of human-readable status output
- Whether to add tunnel address to tmux status bar (may be Phase 4's concern)
- How to handle the case where ngrok isn't authenticated (no token configured)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TUN-01 | ngrok tunnel starts automatically with workspace and displays connection info | ngrok tcp 22 command, jq-based URL parsing from /api/tunnels or /api/endpoints, provider.sh start integration with startup flow |
| TUN-02 | Tunnel auto-reconnects when connection drops or times out | Background watchdog loop with exponential backoff, PID file management, health check via process existence + API endpoint responsiveness |
| TUN-03 | User can check current tunnel address anytime via CLI command | tunnel_status() reads from tunnel.env for persisted address, queries live API for real-time status, human-readable and --json output modes |
| TUN-04 | Tunnel architecture is pluggable -- ngrok is default, other providers swappable | provider.sh sources lib/tunnel/$TUNNEL_PROVIDER.sh, 4 required functions, config.env stores TUNNEL_PROVIDER |
</phase_requirements>

## Standard Stack

### Core

| Library/Tool | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| ngrok | Latest (apt repo) | TCP tunnel for SSH remote access | Already installed by Phase 1 via apt repository. Free tier supports TCP with 5K connections/month. Default and only shipped provider. |
| jq | 1.6+ (apt) | JSON parsing of ngrok API responses | Already installed by Phase 1. Replaces V1's fragile grep-oP pattern. Critical for reliable URL extraction. |
| bash 5.x | System default | All tunnel scripts | Project constraint. Provides `${!var}` indirect expansion for provider loading, process substitution, etc. |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `nohup` | Background watchdog process | Daemonize the watchdog loop so it survives terminal detach |
| `curl` | Query ngrok local API | Health checks against `localhost:4040/api/tunnels` |
| `pgrep` / `kill` | Process management | Check if ngrok/watchdog processes are alive, send signals |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `/api/tunnels` (deprecated) | `/api/endpoints` (new) | New API has different field names (`url` vs `public_url`). Both work as of 2026. Use `/api/endpoints` first with fallback to `/api/tunnels` for maximum compatibility. |
| `nohup` for watchdog | Process substitution `( while ... ) &` | nohup is more robust across terminal detaches and SSH disconnects. Recommended. |
| PID file tracking | `pgrep -f` pattern matching | PID files are explicit and reliable. pgrep can match wrong processes. Use PID files. |

## Architecture Patterns

### Recommended Project Structure
```
lib/
  tunnel/
    provider.sh     # Interface: sources provider, exports generic functions
    ngrok.sh        # ngrok implementation of 4 required functions
```

### Runtime Files
```
~/.cc-tmux/
  config.env            # TUNNEL_PROVIDER="ngrok" (already written by Phase 1 installer)
  tunnel.env            # TUNNEL_HOST="X.tcp.ngrok.io" TUNNEL_PORT="12345" (persisted)
  tunnel.log            # Watchdog reconnection log with timestamps
  tunnel-watchdog.pid   # Watchdog process PID for cleanup
```

### Pattern 1: Provider Interface (provider.sh)

**What:** A sourcing layer that loads the configured provider module and validates it implements the required interface.

**When to use:** Always -- this is the entry point for all tunnel operations.

**Example:**
```bash
# lib/tunnel/provider.sh
# Sources the configured tunnel provider and validates interface

TUNNEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_tunnel_provider() {
    local provider
    provider=$(get_config "TUNNEL_PROVIDER") || provider="ngrok"

    local provider_file="$TUNNEL_DIR/${provider}.sh"

    if [[ ! -f "$provider_file" ]]; then
        log_error "Tunnel provider '$provider' not found"
        log_hint "Available providers:"
        for f in "$TUNNEL_DIR"/*.sh; do
            [[ "$(basename "$f")" == "provider.sh" ]] && continue
            log_hint "  - $(basename "$f" .sh)"
        done
        return 1
    fi

    source "$provider_file"

    # Validate interface
    local required_funcs=(tunnel_start tunnel_stop tunnel_status tunnel_url)
    for func in "${required_funcs[@]}"; do
        if ! declare -f "$func" &>/dev/null; then
            log_error "Provider '$provider' missing required function: $func"
            return 1
        fi
    done
}
```

### Pattern 2: ngrok Provider Implementation (ngrok.sh)

**What:** The ngrok-specific implementation of the 4 required tunnel functions.

**When to use:** Default provider, sourced by provider.sh when TUNNEL_PROVIDER=ngrok.

**Key implementation details:**
```bash
# lib/tunnel/ngrok.sh

TUNNEL_ENV="$CC_TMUX_DIR/tunnel.env"
TUNNEL_LOG="$CC_TMUX_DIR/tunnel.log"
WATCHDOG_PID_FILE="$CC_TMUX_DIR/tunnel-watchdog.pid"
NGROK_API="http://127.0.0.1:4040/api"

tunnel_start() {
    # Check if already running
    if _ngrok_is_running; then
        log_ok "Tunnel already running"
        tunnel_url
        return 0
    fi

    # Check ngrok auth token
    if ! ngrok config check &>/dev/null; then
        log_error "ngrok not authenticated"
        log_hint "Run: ngrok config add-authtoken YOUR_TOKEN"
        return 1
    fi

    # Start ngrok in background
    nohup ngrok tcp 22 --log=stdout > "$TUNNEL_LOG" 2>&1 &
    local ngrok_pid=$!

    # Wait for API to become available (poll with timeout)
    local attempts=0
    local max_attempts=15
    while (( attempts < max_attempts )); do
        if curl -sf "$NGROK_API/tunnels" &>/dev/null; then
            break
        fi
        sleep 1
        ((attempts++))
    done

    if (( attempts >= max_attempts )); then
        log_error "ngrok failed to start (API not responding after ${max_attempts}s)"
        kill "$ngrok_pid" 2>/dev/null
        return 1
    fi

    # Extract and persist address
    _ngrok_persist_address

    # Start watchdog
    _ngrok_start_watchdog

    log_ok "Tunnel started"
    tunnel_url
}

tunnel_stop() {
    _ngrok_stop_watchdog
    pkill -f "ngrok tcp" 2>/dev/null
    log_ok "Tunnel stopped"
}

tunnel_status() {
    # Returns structured status info
    local provider="ngrok"
    local status="down"
    local host="" port="" watchdog_status="stopped"

    if _ngrok_is_running && _ngrok_api_responds; then
        status="connected"
        _ngrok_persist_address  # Refresh
    fi

    # Read persisted address (works even when down)
    if [[ -f "$TUNNEL_ENV" ]]; then
        source "$TUNNEL_ENV"
        host="${TUNNEL_HOST:-}"
        port="${TUNNEL_PORT:-}"
    fi

    # Check watchdog
    if _watchdog_is_running; then
        watchdog_status="running"
    fi

    # Output format depends on caller
    if [[ "${1:-}" == "--json" ]]; then
        printf '{"provider":"%s","status":"%s","host":"%s","port":"%s","watchdog":"%s"}\n' \
            "$provider" "$status" "$host" "$port" "$watchdog_status"
    else
        echo ""
        echo "  Tunnel Status"
        echo "  ─────────────"
        echo "  Provider:  $provider"
        echo "  Status:    $status"
        echo "  Host:      ${host:-n/a}"
        echo "  Port:      ${port:-n/a}"
        echo "  Watchdog:  $watchdog_status"
        if [[ "$status" == "connected" && -n "$host" ]]; then
            echo ""
            echo "  Connect:   ssh -p $port $USER@$host"
        fi
        echo ""
    fi
}

tunnel_url() {
    if [[ -f "$TUNNEL_ENV" ]]; then
        source "$TUNNEL_ENV"
        if [[ -n "${TUNNEL_HOST:-}" ]]; then
            echo "${TUNNEL_HOST}:${TUNNEL_PORT}"
            return 0
        fi
    fi
    return 1
}
```

### Pattern 3: Watchdog with Exponential Backoff

**What:** A background loop that monitors tunnel health and restarts on failure with increasing delays.

**When to use:** Started automatically after tunnel_start, killed on tunnel_stop.

**Example:**
```bash
_ngrok_start_watchdog() {
    _ngrok_stop_watchdog  # Clean up any existing watchdog

    nohup bash -c '
        backoff=30
        max_backoff=300
        while true; do
            sleep 30  # Check interval

            if ! pgrep -f "ngrok tcp" &>/dev/null || \
               ! curl -sf "http://127.0.0.1:4040/api/tunnels" &>/dev/null; then

                echo "[$(date "+%Y-%m-%d %H:%M:%S")] Tunnel down, restarting (backoff: ${backoff}s)..." \
                    >> "'"$TUNNEL_LOG"'"

                pkill -f "ngrok tcp" 2>/dev/null
                sleep 2
                nohup ngrok tcp 22 --log=stdout >> "'"$TUNNEL_LOG"'" 2>&1 &

                sleep "$backoff"

                # Check if restart succeeded
                if curl -sf "http://127.0.0.1:4040/api/tunnels" &>/dev/null; then
                    # Persist new address
                    # ... (call persist function)
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Tunnel restored" >> "'"$TUNNEL_LOG"'"
                    backoff=30  # Reset backoff on success
                else
                    # Increase backoff
                    backoff=$((backoff * 2))
                    (( backoff > max_backoff )) && backoff=$max_backoff
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Restart failed, next attempt in ${backoff}s" \
                        >> "'"$TUNNEL_LOG"'"
                fi
            fi
        done
    ' >> "$TUNNEL_LOG" 2>&1 &

    echo $! > "$WATCHDOG_PID_FILE"
}
```

### Pattern 4: Address Parsing with jq

**What:** Extract TCP tunnel address from ngrok API using jq instead of grep.

**Why:** V1 uses `grep -oP 'public_url":"tcp://\K[^"]+'` which is fragile and requires Perl regex (not available on all systems). jq is already installed.

**Example:**
```bash
_ngrok_persist_address() {
    local response
    response=$(curl -sf "$NGROK_API/tunnels" 2>/dev/null) || return 1

    local public_url
    public_url=$(echo "$response" | jq -r '.tunnels[0].public_url // empty') || return 1

    if [[ -z "$public_url" ]]; then
        # Fallback to new /api/endpoints format
        response=$(curl -sf "$NGROK_API/endpoints" 2>/dev/null) || return 1
        public_url=$(echo "$response" | jq -r '.endpoints[0].url // empty') || return 1
    fi

    if [[ -z "$public_url" ]]; then
        return 1
    fi

    # Parse tcp://X.tcp.ngrok.io:PORT format
    local host port
    host=$(echo "$public_url" | sed 's|tcp://||' | cut -d: -f1)
    port=$(echo "$public_url" | sed 's|tcp://||' | cut -d: -f2)

    # Persist to tunnel.env
    cat > "$TUNNEL_ENV" <<EOF
# Generated by cc-tmux tunnel -- do not edit manually
# Last updated: $(date "+%Y-%m-%d %H:%M:%S")
TUNNEL_HOST="$host"
TUNNEL_PORT="$port"
TUNNEL_URL="$public_url"
TUNNEL_PROVIDER="ngrok"
EOF
    chmod 600 "$TUNNEL_ENV"
}
```

### Anti-Patterns to Avoid

- **`grep -oP` for JSON parsing:** Perl-compatible regex is not available on all systems. Always use `jq`. This is V1's biggest fragility.
- **`pkill ngrok` without specificity:** Kills ALL ngrok processes including unrelated ones. Use `pkill -f "ngrok tcp"` or PID files.
- **`sleep 3` after ngrok start:** Unreliable on slow connections. Poll the API with a retry loop and timeout instead.
- **Inline watchdog in startup script:** The watchdog must be its own background process, not part of the startup flow. Otherwise it blocks the terminal.
- **Sourcing tunnel.env without quotes:** Values may contain special characters. Always quote: `source "$TUNNEL_ENV"`.
- **Hardcoding API port 4040:** The ngrok web_addr is configurable. However, for simplicity and since we control the ngrok config, 4040 is acceptable as the default.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | regex/grep on JSON output | `jq` | JSON structure can change; nested fields, escaping, arrays all break regex |
| Process supervision | Custom init system or systemd service | Background bash loop with PID file | WSL2 systemd is unreliable; a simple bash loop with exponential backoff is more robust for this use case |
| URL parsing | Manual string splitting | `sed` + `cut` on known format | TCP URL format is simple (`tcp://host:port`) but should still be parsed reliably |
| Config persistence | Custom file format | Source-able KEY="value" (already in config.sh) | Matches existing pattern, zero parsing overhead |

**Key insight:** The tunnel layer should be as simple as possible. The complexity lives in reliability (watchdog, reconnection, address persistence), not in protocol handling or fancy features.

## Common Pitfalls

### Pitfall 1: ngrok API Not Ready Immediately After Start
**What goes wrong:** V1 does `nohup ngrok tcp 22 &` then immediately `curl localhost:4040/api/tunnels`. The API takes 1-5 seconds to become available, so curl fails, and the address is never captured.
**Why it happens:** ngrok needs time to establish the tunnel and start its local API server.
**How to avoid:** Poll with retry loop: `until curl -sf localhost:4040/api/tunnels; do sleep 1; done` with a 15-second timeout.
**Warning signs:** tunnel_url returns empty, tunnel.env is never written, user sees no connection info.

### Pitfall 2: TCP Requires Payment Method on Free Tier
**What goes wrong:** User signs up for ngrok free plan and configures auth token, but `ngrok tcp 22` fails because TCP endpoints require a valid payment method on file (not charged, just verified).
**Why it happens:** ngrok added this requirement to prevent abuse of TCP tunnels.
**How to avoid:** Detect this failure case in `tunnel_start`. When ngrok tcp fails, check the log for payment-related error messages and provide a clear instruction: "Add a payment method at https://dashboard.ngrok.com/settings#id-verification (you won't be charged)".
**Warning signs:** ngrok starts but the API returns no tunnels, or ngrok exits immediately with an error.

### Pitfall 3: Watchdog Orphaned After Unclean Shutdown
**What goes wrong:** WSL2 is shut down (Windows reboot, `wsl --shutdown`), leaving stale PID files. On next start, the code thinks the watchdog is running but the PID belongs to a different process.
**Why it happens:** PID files persist on disk but processes do not survive WSL restarts.
**How to avoid:** Validate PID file contents: check that the PID exists AND the process name matches. `kill -0 $pid 2>/dev/null && grep -q "tunnel" /proc/$pid/cmdline 2>/dev/null`.
**Warning signs:** `tunnel_status` shows "watchdog running" but no actual monitoring is happening.

### Pitfall 4: Address Changes on Reconnect with No Notification
**What goes wrong:** Tunnel drops and watchdog restarts it. The new URL has a different port. User's phone (Termius) is configured with the old port and can't connect.
**Why it happens:** ngrok free tier assigns random ports on each tunnel creation. There is no static TCP endpoint on free tier.
**How to avoid:** Always persist the new address to `tunnel.env` immediately after reconnect. Display it prominently. Consider writing it to the tmux status bar (Phase 4 concern) or a file the user can easily check.
**Warning signs:** Phone SSH fails after a reconnect, but workspace is running fine locally.

### Pitfall 5: Multiple ngrok Processes Conflict
**What goes wrong:** User runs `tunnel_start` twice, or the watchdog restarts ngrok while a previous instance is still listening. Two ngrok processes compete for port 4040, causing API failures.
**Why it happens:** Insufficient check-before-act guards.
**How to avoid:** `tunnel_start` must check if ngrok is already running. `pkill -f "ngrok tcp"` before starting a new instance. The watchdog restart sequence must kill-then-start atomically.
**Warning signs:** `curl localhost:4040/api/tunnels` returns unexpected results or connection refused.

### Pitfall 6: Watchdog Process Substitution Doesn't Survive SSH Disconnect
**What goes wrong:** If the watchdog is started with `( while true; do ...; done ) &` instead of `nohup`, it receives SIGHUP when the SSH session ends and dies.
**Why it happens:** Process substitution creates a child of the current shell. When the shell exits, SIGHUP is sent to all children.
**How to avoid:** Use `nohup bash -c '...' &` or `disown` after backgrounding. Write PID to file after `nohup`.
**Warning signs:** Watchdog dies whenever the user disconnects SSH, leaving the tunnel unmonitored.

## Code Examples

### Verified: V1 ngrok Start Pattern (Being Replaced)
```bash
# V1/startup.sh -- what we're replacing
pkill ngrok 2>/dev/null
sleep 1
nohup ngrok tcp 22 --log=stdout > /tmp/ngrok.log 2>&1 &
sleep 3
ADDR=$(curl -s http://localhost:4040/api/tunnels | grep -oP 'public_url":"tcp://\K[^"]+')
PORT=$(echo "$ADDR" | grep -o '[0-9]*$')
```

### Verified: ngrok API Response Format (deprecated but functional)
```json
{
    "tunnels": [
        {
            "name": "command_line",
            "uri": "/api/tunnels/command_line",
            "public_url": "tcp://0.tcp.ngrok.io:53476",
            "proto": "tcp",
            "config": { "addr": "localhost:22", "inspect": false },
            "metrics": { }
        }
    ],
    "uri": "/api/tunnels"
}
```
Source: ngrok Agent API documentation (https://ngrok.com/docs/agent/api)

### Verified: New /api/endpoints Response Format
```json
{
    "endpoints": [
        {
            "name": "command_line",
            "uri": "/api/endpoints/command_line",
            "url": "tcp://0.tcp.ngrok.io:53476",
            "upstream": { "url": "http://localhost:22", "protocol": "tcp" },
            "inspect": false,
            "traffic_policy": "",
            "pooling_enabled": false
        }
    ]
}
```
Source: ngrok Agent API documentation (https://ngrok.com/docs/agent/api)
Note: Field is `url` not `public_url`. TCP format is the same `tcp://host:port`.

### Verified: Existing Utility Functions Available
```bash
# From lib/common.sh -- available for tunnel code
log_ok "message"          # Green [ok] prefix
log_error "message"       # Red [error] prefix to stderr
log_warn "message"        # Yellow [warn] prefix
log_hint "message"        # Blue indented hint
log_step N "message"      # Bold [N/TOTAL] prefix

# From lib/config.sh -- available for tunnel code
CC_TMUX_DIR="$HOME/.cc-tmux"
get_config "TUNNEL_PROVIDER"   # Read from config.env (subshell, safe)
write_config KEY "value"       # Write to config.env (idempotent upsert)
read_config                    # Source entire config.env into current shell
```

### Verified: deploy_file Pattern
```bash
# From lib/common.sh -- for deploying tunnel scripts
deploy_file "$src" "$dst" "$perms"
# Creates parent dirs, copies file, sets permissions
```

## State of the Art

| Old Approach (V1) | Current Approach (V2) | When Changed | Impact |
|---|---|---|---|
| `grep -oP` Perl regex for JSON | `jq` for JSON parsing | Phase 1 (jq installed) | Reliable, portable, handles edge cases |
| `/api/tunnels` endpoint | `/api/endpoints` endpoint (with fallback) | ngrok agent update 2025 | `/api/tunnels` deprecated but still works; use both |
| `sleep 3` after ngrok start | Poll API with retry loop | V2 design | Faster on fast connections, reliable on slow ones |
| No reconnection (tunnel dies silently) | Watchdog with exponential backoff | V2 design | Tunnel survives free tier disconnects and network flaps |
| `port.sh` as standalone script | `tunnel_status()` function | V2 design | Integrated, works from any context, --json support |
| Single hardcoded provider | Pluggable provider via config | V2 design | Future-proofs for Tailscale, Cloudflare, etc. |

**Deprecated/outdated:**
- ngrok 2-hour session timeout: Official docs now state "free tier does NOT have timeouts on endpoints." The CONTEXT.md mentions 2-hour limits -- this appears to be outdated information. Watchdog is still essential for network flaps and other failures, but the 2-hour forced restart is no longer a concern.
- `snap install ngrok`: Already addressed in Phase 1 -- using apt repository instead.

## Open Questions

1. **TCP Tunnel Payment Method Requirement**
   - What we know: ngrok official docs state TCP endpoints on free plan require "adding a valid payment method." This was not mentioned in prior project research.
   - What's unclear: Whether this is strictly enforced or if there are workarounds. The user may have already configured this during Phase 1 token setup.
   - Recommendation: Handle gracefully in `tunnel_start`. Detect the specific error, log a clear instruction. This does NOT block architecture -- it's a runtime error handling concern.

2. **Watchdog Log Rotation**
   - What we know: The watchdog writes to `~/.cc-tmux/tunnel.log` with timestamps. Over days/weeks this could grow.
   - What's unclear: Whether to implement log rotation now or defer.
   - Recommendation: Keep it simple -- truncate log to last 500 lines on each watchdog start. Defer proper rotation to Phase 5 (robustness).

3. **Tunnel Address in tmux Status Bar**
   - What we know: CONTEXT.md says "Display tunnel address on every tmux attach." Claude's discretion on whether to add to tmux status bar.
   - What's unclear: Whether this belongs in Phase 3 or Phase 4 (workspace).
   - Recommendation: Phase 3 should write to tunnel.env only. Phase 4 tmux config can read tunnel.env and display in status bar. For Phase 3, display address to stdout when tunnel starts.

4. **Installer Integration Scope**
   - What we know: install.sh needs to source provider.sh and the deploy step needs to deploy lib/tunnel/ files.
   - What's unclear: Whether Phase 3 should modify install.sh or whether that's Phase 4/5 territory.
   - Recommendation: Phase 3 should ensure lib/tunnel/ files are deployed by the existing `step_deploy` in setup.sh (which already deploys all `lib/*.sh` files). The tunnel/ subdirectory needs to be handled -- either by extending the deploy loop to recurse, or by deploying tunnel files explicitly.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash manual verification (no automated test framework) |
| Config file | none -- pure bash project |
| Quick run command | `bash -n lib/tunnel/provider.sh && bash -n lib/tunnel/ngrok.sh` (syntax check) |
| Full suite command | Manual: start tunnel, check status, kill ngrok, verify watchdog restarts, check tunnel.env persisted |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TUN-01 | Tunnel starts and displays address | integration | `source lib/tunnel/provider.sh && load_tunnel_provider && tunnel_start` | Wave 0 |
| TUN-02 | Watchdog restarts tunnel after kill | integration | `pkill -f "ngrok tcp" && sleep 35 && curl -sf localhost:4040/api/tunnels` | Wave 0 |
| TUN-03 | Status command shows address | smoke | `source lib/tunnel/provider.sh && load_tunnel_provider && tunnel_status` | Wave 0 |
| TUN-04 | Provider is swappable | unit | `TUNNEL_PROVIDER=nonexistent source lib/tunnel/provider.sh && load_tunnel_provider` (should error) | Wave 0 |

### Sampling Rate
- **Per task commit:** `bash -n lib/tunnel/provider.sh && bash -n lib/tunnel/ngrok.sh` (syntax validation)
- **Per wave merge:** Full manual test: start, check status, kill, verify restart, check persisted address
- **Phase gate:** All 4 TUN requirements manually verified

### Wave 0 Gaps
- [ ] `lib/tunnel/provider.sh` -- provider interface (to be created)
- [ ] `lib/tunnel/ngrok.sh` -- ngrok implementation (to be created)
- [ ] Extend `step_deploy` in setup.sh to handle `lib/tunnel/` subdirectory
- [ ] Verify ngrok token is configured before attempting tunnel start
- [ ] No automated test framework -- all validation is manual bash execution

## Sources

### Primary (HIGH confidence)
- [ngrok Agent API documentation](https://ngrok.com/docs/agent/api) -- `/api/tunnels` and `/api/endpoints` response formats, deprecation notice, no auth required
- [ngrok Free Plan Limits](https://ngrok.com/docs/pricing-limits/free-plan-limits) -- NO session timeout, 5K TCP connections/month, 100/min rate, up to 3 endpoints, 1GB bandwidth
- [ngrok SSH documentation](https://ngrok.com/docs/using-ngrok-with/ssh) -- TCP tunnel for SSH setup, payment method requirement for free tier TCP
- V1/startup.sh -- existing ngrok start pattern being replaced
- V1/port.sh -- existing address check being replaced
- lib/common.sh, lib/config.sh, lib/deps.sh -- existing utility functions verified by reading source code

### Secondary (MEDIUM confidence)
- [Exponential backoff in bash](https://gist.github.com/nathforge/62456d9b18e276954f58eb61bf234c17) -- backoff pattern reference
- [Watchdog script patterns](http://kb.ictbanking.net/article.php?id=342) -- background monitoring loop patterns
- [Baeldung: Background Jobs in Bash](https://www.baeldung.com/linux/bash-background-jobs-loop) -- nohup vs process substitution behavior

### Tertiary (LOW confidence)
- Multiple search results about ngrok 2-hour timeout -- appears to be OUTDATED as of 2026. Official docs explicitly state no timeouts. Prior research (PITFALLS.md, CONTEXT.md) references this limit, but it may have been removed.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools already installed by Phase 1, API formats verified against official docs
- Architecture: HIGH -- provider pattern is well-defined in CONTEXT.md, matches existing lib/ sourcing pattern
- Pitfalls: HIGH -- verified against official docs, V1 code, and project research. One correction: 2-hour timeout appears removed.
- ngrok free tier TCP payment requirement: MEDIUM -- stated in official docs, not previously accounted for in project planning

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable -- bash patterns don't change, ngrok API deprecated endpoint still works)

---
*Phase 3: Tunnel Layer research*
*Researched: 2026-03-20*
