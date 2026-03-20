---
phase: 03-tunnel-layer
plan: 01
subsystem: infra
tags: [ngrok, tunnel, bash, watchdog, jq, process-management]

# Dependency graph
requires:
  - phase: 01-foundation-installer
    provides: "lib/common.sh logging, lib/config.sh config management, ngrok apt install, jq"
provides:
  - "Pluggable tunnel provider interface (lib/tunnel/provider.sh)"
  - "ngrok provider with start/stop/status/url (lib/tunnel/ngrok.sh)"
  - "Background watchdog with exponential backoff auto-reconnect"
  - "Tunnel address persistence to tunnel.env"
affects: [03-tunnel-layer, 04-workspace-mobile]

# Tech tracking
tech-stack:
  added: []
  patterns: [provider-interface-pattern, nohup-watchdog-with-pid, jq-api-parsing, inlined-subshell-logic]

key-files:
  created:
    - lib/tunnel/provider.sh
    - lib/tunnel/ngrok.sh
  modified: []

key-decisions:
  - "Watchdog inlines address persistence logic in nohup subshell since parent shell functions are inaccessible"
  - "Uses dash separators (-----) in status output rather than unicode box drawing for WSL2 terminal compatibility"
  - "ngrok.sh is 323 lines (above 250 guidance) due to required duplication of persistence logic in watchdog subshell"

patterns-established:
  - "Provider interface: TUNNEL_DIR-based module loading with 4-function contract validation via declare -f"
  - "Watchdog pattern: nohup bash -c with PID file, exponential backoff (30s-300s), log truncation on start"
  - "API fallback: try /api/tunnels first, fallback to /api/endpoints for future ngrok versions"

requirements-completed: [TUN-01, TUN-02, TUN-03, TUN-04]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 03 Plan 01: Tunnel Provider Architecture Summary

**Pluggable tunnel provider interface with full ngrok implementation including background watchdog auto-reconnect and jq-based address parsing**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T15:40:13Z
- **Completed:** 2026-03-20T15:42:29Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments
- Provider interface layer that sources configured provider module and validates the 4-function contract
- Full ngrok implementation with start, stop, status (human-readable + JSON), and url functions
- Background watchdog with exponential backoff (30s initial, 300s cap) for auto-reconnect
- Address persistence to tunnel.env via jq parsing of /api/tunnels with /api/endpoints fallback
- Payment method error detection with user-friendly guidance on tunnel start failure
- Stale PID file detection and cleanup for robustness after WSL2 restarts

## Task Commits

Each task was committed atomically:

1. **Task 1: Create provider interface (lib/tunnel/provider.sh)** - `52a0fa7` (feat)
2. **Task 2: Create ngrok provider implementation (lib/tunnel/ngrok.sh)** - `78612be` (feat)

## Files Created/Modified
- `lib/tunnel/provider.sh` - Tunnel provider interface: load_tunnel_provider() sources configured provider and validates 4-function contract
- `lib/tunnel/ngrok.sh` - ngrok implementation: tunnel_start/stop/status/url, watchdog with exponential backoff, address persistence via jq

## Decisions Made
- Watchdog subshell inlines address persistence logic (curl+jq+write) rather than trying to call parent shell functions -- this is correct since nohup bash -c runs in an isolated subshell
- Used ASCII dash separators in status output instead of unicode box-drawing characters for maximum terminal compatibility
- ngrok.sh ended at 323 lines (above the 200-250 guidance) because the plan explicitly required inlining the address persistence sequence in the watchdog subshell, which is necessary duplication

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- lib/tunnel/provider.sh and ngrok.sh are ready for integration into installer flow (Plan 03-02)
- Plan 02 will wire tunnel module into install.sh deployment, startup.sh sourcing, and cc-tmux CLI
- All 4 TUN requirements addressed at code level; Plan 02 handles integration

## Self-Check: PASSED

- lib/tunnel/provider.sh: FOUND
- lib/tunnel/ngrok.sh: FOUND
- 03-01-SUMMARY.md: FOUND
- Commit 52a0fa7: FOUND
- Commit 78612be: FOUND

---
*Phase: 03-tunnel-layer*
*Completed: 2026-03-20*
