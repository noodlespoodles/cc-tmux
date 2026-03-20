# CC × TMUX v2

## What This Is

A toolkit that lets Windows users run Claude Code (or any CLI tool) in persistent tmux sessions across devices. You launch a tabbed terminal workspace on your PC, walk away, and pick it up on your Android phone via SSH tunnel — same sessions, same state. V2 is a ground-up refactor of the existing V1 scripts to maximize robustness, security, ease of install, cross-device usability, and mobile experience.

## Core Value

Non-technical users can install this in minutes and seamlessly access their Claude Code sessions from PC and phone without understanding WSL, SSH, or tmux internals.

## Requirements

### Validated

- One-command installer that handles all dependencies — Validated in Phase 1
- Automatic Windows username detection — Validated in Phase 1
- Idempotent installer (re-run safe) — Validated in Phase 1
- Interactive project folder setup — Validated in Phase 1
- ngrok auth token guided setup — Validated in Phase 1
- LF line endings enforced via .gitattributes — Validated in Phase 1

### Active
- [ ] Robust SSH configuration with proper security defaults (key-based auth, fail2ban or equivalent)
- [ ] ngrok tunnel with automatic reconnection and persistent endpoint when possible
- [ ] tmux configuration with mobile-optimized mode that auto-detects device type
- [ ] Workspace management: add/remove/rename project tabs without editing scripts
- [ ] Cross-device session continuity — attach from any device, detach gracefully
- [ ] Desktop shortcut creation (Windows) fully automated
- [ ] Termius-friendly connection info display and easy phone setup guide
- [ ] Responsive tmux status bar that adapts to screen width
- [ ] Input validation and error handling throughout all scripts
- [ ] Graceful degradation when dependencies are unavailable
- [ ] Uninstall script that cleanly removes everything
- [ ] Self-updating mechanism or version checking
- [ ] Comprehensive but approachable README for non-technical users
- [ ] Health check / diagnostics command to troubleshoot issues

### Out of Scope

- GUI installer (Windows native) — complexity not justified for shell-based tool
- iOS support — Termius exists on iOS but testing infeasible without device
- Custom tmux plugin system — keep it simple, one config
- Multi-user / shared workspace — single user tool

## Context

V1 is a working proof of concept with ~7 shell scripts and a tmux config. It works but has friction points:
- Users must manually replace `YOURUSERNAME` in multiple files
- No error handling — scripts assume everything succeeds
- ngrok tunnel address changes on every reboot (free tier limitation)
- No input validation — wrong paths silently break things
- SSH config uses password auth only (less secure)
- No way to manage projects without editing shell scripts
- Mobile mode requires manual keyboard shortcut toggle
- No health check or diagnostics
- README is thorough but copy-paste heavy (13 steps)

The target audience is people who use Claude Code daily but aren't sysadmins. They should be able to clone a repo, run one command, answer a few questions, and be up and running.

## Constraints

- **Platform**: WSL2 on Windows 10/11 — all scripts must work in this environment
- **Dependencies**: tmux, openssh-server, ngrok (or alternative tunnel) — must be installable via apt/snap
- **Shell**: Bash scripts only (no Python/Node dependencies for the tool itself)
- **Phone client**: Termius on Android is the primary mobile client
- **Tunnel**: ngrok free tier is baseline — must work without paid plans
- **License**: MIT (maintain from V1)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep bash-only (no Python/Node) | Minimizes dependencies for non-technical users | — Pending |
| ngrok as default tunnel | Most accessible for beginners, free tier available | — Pending |
| WSL2 only (no native Linux) | Target audience is Windows users with Claude Code | — Pending |
| Interactive installer over config file | Non-technical users prefer guided setup over editing YAML | — Pending |

---
*Last updated: 2026-03-20 after Phase 1 completion*
