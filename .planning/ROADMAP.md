# Roadmap: CC x TMUX v2

## Overview

CC x TMUX v2 transforms a working-but-fragile proof-of-concept into a robust, secure toolkit that any Windows user can install in minutes to run Claude Code in persistent tmux sessions accessible from PC and phone. The roadmap moves from foundational infrastructure (installer, SSH, tunnels) through workspace management to final polish and documentation, with each phase delivering a verifiable capability that the next phase builds on.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & Installer** - Idempotent one-command installer with dependency management, auto-detection, and config system
- [ ] **Phase 2: SSH & Security** - Hardened SSH with key-based auth, fail2ban, and systemd service management
- [ ] **Phase 3: Tunnel Layer** - Pluggable tunnel architecture with ngrok default, auto-reconnect, and status commands
- [ ] **Phase 4: Workspace & Mobile** - tmux workspace with project management, session persistence, and mobile-adaptive layout
- [ ] **Phase 5: Robustness & Lifecycle** - Input validation, health diagnostics, self-update, and clean uninstall
- [ ] **Phase 6: User Experience & Documentation** - Desktop shortcut, QR code setup, and comprehensive user documentation

## Phase Details

### Phase 1: Foundation & Installer
**Goal**: User can clone the repo and run one command to get a fully configured cc-tmux installation with all dependencies resolved
**Depends on**: Nothing (first phase)
**Requirements**: INST-01, INST-02, INST-03, INST-04, INST-05, INST-06, ROB-04
**Success Criteria** (what must be TRUE):
  1. User can run `bash install.sh` and all dependencies (tmux, openssh-server, ngrok, jq, fail2ban) are installed without manual intervention
  2. Installer detects the Windows username automatically and configures all paths without placeholder replacement
  3. Re-running the installer on an already-configured system completes successfully without duplicating config or breaking existing setup
  4. Installer prompts the user for project folders and ngrok auth token with clear instructions at each step
  5. Cloning the repo on Windows produces working scripts (no CRLF line ending breakage)
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md -- Repository foundation (.gitattributes) and core library modules (common.sh, detect.sh, config.sh)
- [x] 01-02-PLAN.md -- Installer entry point (install.sh), dependency management (deps.sh), system setup (setup.sh), and bashrc hook

### Phase 2: SSH & Security
**Goal**: User's SSH service runs with defense-in-depth security that is safe to expose through a public tunnel
**Depends on**: Phase 1
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04
**Success Criteria** (what must be TRUE):
  1. SSH authenticates via Ed25519 keys by default -- password authentication is disabled
  2. SSH daemon runs with hardened settings (no root login, limited auth attempts, protocol 2 only)
  3. fail2ban is active and bans IPs after repeated failed SSH login attempts
  4. During install, the SSH key pair is generated and the private key is displayed with clear instructions for importing into Termius on phone
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Tunnel Layer
**Goal**: User's local SSH is accessible from anywhere via an auto-managed tunnel with a pluggable provider architecture
**Depends on**: Phase 2
**Requirements**: TUN-01, TUN-02, TUN-03, TUN-04
**Success Criteria** (what must be TRUE):
  1. Starting the workspace automatically starts an ngrok tunnel and displays the connection address (host:port)
  2. If the tunnel drops or times out, it reconnects automatically without user intervention
  3. User can run a CLI command (e.g., `cc-tmux tunnel`) to check the current tunnel address at any time
  4. Tunnel provider is implemented as a swappable module -- replacing ngrok with another provider requires changing one config value and adding one script file
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Workspace & Mobile
**Goal**: Users have a complete tmux workspace with managed project tabs that adapts its layout for phone access
**Depends on**: Phase 3
**Requirements**: WRK-01, WRK-02, WRK-03, WRK-04, WRK-05, MOB-01, MOB-02, MOB-03
**Success Criteria** (what must be TRUE):
  1. Launching the workspace creates tmux windows for each configured project, pre-navigated to project directories
  2. User can add, remove, and list projects via CLI commands (`cc-tmux project add/remove/list`) without editing any files manually
  3. Closing the terminal window does not kill tmux sessions -- reopening or SSHing in reattaches to the same workspace
  4. When a phone connects via SSH (narrow terminal), tmux automatically switches to a mobile-optimized layout with larger tap targets and minimal status bar
  5. User can manually toggle between mobile and desktop mode via a tmux keybinding
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Robustness & Lifecycle
**Goal**: All scripts handle errors gracefully, and the toolkit provides diagnostics, updates, and clean removal
**Depends on**: Phase 4
**Requirements**: ROB-01, ROB-02, ROB-03, ROB-05, INST-07
**Success Criteria** (what must be TRUE):
  1. Running any cc-tmux command with invalid inputs produces a clear, actionable error message instead of cryptic failures
  2. Scripts degrade gracefully when optional dependencies are missing or network is unavailable (e.g., tunnel fails but workspace still launches)
  3. Running `cc-tmux doctor` produces a pass/fail checklist for each component (WSL, tmux, SSH, tunnel, config)
  4. Running `cc-tmux update` checks for new versions and applies updates from the repository
  5. Running `cc-tmux uninstall` cleanly reverses all changes made by the installer (configs, services, shortcuts)
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: User Experience & Documentation
**Goal**: The toolkit is complete with Windows integration, easy phone onboarding, and documentation that a non-technical user can follow
**Depends on**: Phase 5
**Requirements**: INST-08, MOB-04, DOC-01, DOC-02, DOC-03
**Success Criteria** (what must be TRUE):
  1. Installer creates a Windows desktop shortcut that launches the cc-tmux workspace in one click (no manual PowerShell step)
  2. Startup displays a QR code that the user can scan to configure their phone SSH client
  3. README provides a complete setup guide from git clone to working phone access, written for users who don't know what WSL or SSH are
  4. README includes a quick reference card for daily commands (start, stop, add project, check tunnel, etc.)
  5. README has a troubleshooting section covering common failure modes with step-by-step solutions
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Installer | 2/2 | Complete | 2026-03-20 |
| 2. SSH & Security | 0/? | Not started | - |
| 3. Tunnel Layer | 0/? | Not started | - |
| 4. Workspace & Mobile | 0/? | Not started | - |
| 5. Robustness & Lifecycle | 0/? | Not started | - |
| 6. User Experience & Documentation | 0/? | Not started | - |
