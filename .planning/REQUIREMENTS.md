# Requirements: CC x TMUX v2

**Defined:** 2026-03-20
**Core Value:** Non-technical users can install this in minutes and seamlessly access their Claude Code sessions from PC and phone without understanding WSL, SSH, or tmux internals.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Installation

- [ ] **INST-01**: User can install everything with a single command (`bash install.sh`) that handles all dependencies
- [ ] **INST-02**: Installer auto-detects Windows username without manual placeholder replacement
- [ ] **INST-03**: Installer is idempotent — re-running it doesn't break or duplicate anything
- [ ] **INST-04**: Installer provides clear progress indicators and error messages at each step
- [ ] **INST-05**: Installer interactively asks user for project folders (guided setup, not config file editing)
- [ ] **INST-06**: Installer handles ngrok auth token setup with clear instructions
- [ ] **INST-07**: User can uninstall cleanly with a single command that reverses all changes
- [ ] **INST-08**: Installer creates Windows desktop shortcut automatically (no manual PowerShell step)

### Security

- [ ] **SEC-01**: SSH uses Ed25519 key-based authentication by default (not password-only)
- [ ] **SEC-02**: SSH daemon runs with hardened configuration (no root login, limited auth attempts)
- [ ] **SEC-03**: fail2ban or equivalent protects against brute-force SSH attempts
- [ ] **SEC-04**: SSH keys are generated during install and displayed for easy phone setup

### Tunnel

- [ ] **TUN-01**: ngrok tunnel starts automatically with workspace and displays connection info
- [ ] **TUN-02**: Tunnel auto-reconnects when connection drops or times out
- [ ] **TUN-03**: User can check current tunnel address anytime via CLI command
- [ ] **TUN-04**: Tunnel architecture is pluggable — ngrok is default, other providers can be swapped in

### Workspace

- [ ] **WRK-01**: tmux workspace creates project tabs from configured project list on startup
- [ ] **WRK-02**: User can add/remove/list projects via CLI commands without editing scripts
- [ ] **WRK-03**: Workspace sessions persist — closing terminal window doesn't kill sessions
- [ ] **WRK-04**: Attaching from any terminal (PC or phone) reconnects to existing workspace seamlessly
- [ ] **WRK-05**: tmux config includes mouse support, clickable tabs, sensible keybindings

### Mobile

- [ ] **MOB-01**: tmux auto-detects mobile device (narrow terminal) and switches to mobile-optimized layout
- [ ] **MOB-02**: Mobile mode has larger tap targets, minimal status bar, essential info only
- [ ] **MOB-03**: User can manually toggle mobile/desktop mode via keybinding
- [ ] **MOB-04**: QR code displayed at startup for easy phone SSH connection setup

### Robustness

- [ ] **ROB-01**: All scripts validate inputs and provide clear error messages for invalid paths/values
- [ ] **ROB-02**: Scripts handle edge cases gracefully (missing dependencies, network failures, WSL quirks)
- [ ] **ROB-03**: Health check command (`cc-tmux doctor`) diagnoses common issues with pass/fail per component
- [ ] **ROB-04**: `.gitattributes` ensures LF line endings — cloning on Windows doesn't break scripts
- [ ] **ROB-05**: Self-update mechanism checks for new versions and applies updates via `cc-tmux update`

### Documentation

- [ ] **DOC-01**: README provides complete setup guide written for non-technical users
- [ ] **DOC-02**: README includes quick reference card for daily usage
- [ ] **DOC-03**: Troubleshooting section covers common failure modes with solutions

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Alternative Tunnels

- **ATUN-01**: Tailscale integration for persistent tunnel endpoints (runs on Windows host)
- **ATUN-02**: Cloudflare Tunnel integration for free stable URLs
- **ATUN-03**: Mosh support as SSH alternative for unreliable networks

### Advanced Features

- **ADV-01**: Workspace templates (pre-built project configurations for common setups)
- **ADV-02**: Configuration backup/export and import across machines
- **ADV-03**: Auto-start workspace on Windows login via Task Scheduler
- **ADV-04**: Session persistence across WSL restarts via tmux-resurrect/continuum

## Out of Scope

| Feature | Reason |
|---------|--------|
| GUI installer (Windows native) | Massive complexity; terminal is the GUI for a terminal tool |
| Custom tmux plugin system | TPM already exists; keep config opinionated |
| Multi-user / shared workspaces | Single-user tool by design; pair programming has dedicated tools |
| Full dotfile management | Scope creep into chezmoi/yadm territory |
| iOS support | Can't test without hardware; likely works but unsupported |
| Docker/container approach | Adds complexity for non-technical users |
| Web-based terminal UI | Termius already solves mobile access |
| Auto-start Claude Code in tabs | Wastes API credits; users want control |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INST-01 | Phase 1 | Pending |
| INST-02 | Phase 1 | Pending |
| INST-03 | Phase 1 | Pending |
| INST-04 | Phase 1 | Pending |
| INST-05 | Phase 1 | Pending |
| INST-06 | Phase 1 | Pending |
| INST-07 | Phase 5 | Pending |
| INST-08 | Phase 6 | Pending |
| SEC-01 | Phase 2 | Pending |
| SEC-02 | Phase 2 | Pending |
| SEC-03 | Phase 2 | Pending |
| SEC-04 | Phase 2 | Pending |
| TUN-01 | Phase 3 | Pending |
| TUN-02 | Phase 3 | Pending |
| TUN-03 | Phase 3 | Pending |
| TUN-04 | Phase 3 | Pending |
| WRK-01 | Phase 4 | Pending |
| WRK-02 | Phase 4 | Pending |
| WRK-03 | Phase 4 | Pending |
| WRK-04 | Phase 4 | Pending |
| WRK-05 | Phase 4 | Pending |
| MOB-01 | Phase 4 | Pending |
| MOB-02 | Phase 4 | Pending |
| MOB-03 | Phase 4 | Pending |
| MOB-04 | Phase 6 | Pending |
| ROB-01 | Phase 5 | Pending |
| ROB-02 | Phase 5 | Pending |
| ROB-03 | Phase 5 | Pending |
| ROB-04 | Phase 1 | Pending |
| ROB-05 | Phase 5 | Pending |
| DOC-01 | Phase 6 | Pending |
| DOC-02 | Phase 6 | Pending |
| DOC-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 33 total
- Mapped to phases: 33
- Unmapped: 0

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after roadmap creation*
