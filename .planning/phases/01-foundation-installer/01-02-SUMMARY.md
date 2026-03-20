---
phase: 01-foundation-installer
plan: 02
subsystem: infra
tags: [bash, installer, apt, ngrok, ssh, sudoers, tmux, idempotent]

# Dependency graph
requires:
  - phase: 01-foundation-installer/01
    provides: lib/common.sh (logging, colors, guards), lib/detect.sh (username detection), lib/config.sh (config CRUD)
provides:
  - install.sh single-entry-point installer with 7 numbered steps
  - lib/deps.sh for apt package and ngrok installation
  - lib/setup.sh for SSH config, sudoers, bashrc hook, file deployment, verification
  - templates/bashrc-hook.sh for auto-attach on SSH login
affects: [02-SSH-Security, 03-Tunnel-Layer, 04-Workspace-Mobile]

# Tech tracking
tech-stack:
  added: [apt, curl, ngrok-apt-repo, sudoers, ssh-keygen, visudo]
  patterns: [modular-installer, crlf-self-healing, noninteractive-flag, validated-sudoers, step-wizard]

key-files:
  created:
    - install.sh
    - lib/deps.sh
    - lib/setup.sh
    - templates/bashrc-hook.sh
  modified: []

key-decisions:
  - "ngrok installed via apt repository, not snap -- snap fails on WSL2 without systemd"
  - "Sudoers validated with visudo -c before deployment -- prevents lockout from syntax errors"
  - "bashrc-hook.sh includes SSH_CONNECTION guard as belt-and-suspenders defense"
  - "step_configure in setup.sh exported for reuse; install.sh defines its own step_setup_system wrapper"

patterns-established:
  - "CRLF self-healing: install.sh detects \\r in first line and auto-fixes all .sh files before re-executing"
  - "Non-interactive mode: NONINTERACTIVE=true exported, all interactive functions check before prompting"
  - "Step wizard: TOTAL_STEPS=7, each step function calls log_step with its number for [N/7] display"
  - "Validated sudoers: write to temp file, visudo -c validates, only then copy to /etc/sudoers.d/"

requirements-completed: [INST-01, INST-03, INST-04, INST-05, INST-06]

# Metrics
duration: 4min
completed: 2026-03-20
---

# Phase 1 Plan 2: Installer Entry Point and System Setup Summary

**Complete 7-step installer (install.sh) with apt dependency management, ngrok via apt repo, interactive project/token setup, validated sudoers, SSH config, and bashrc auto-attach hook**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-20T14:32:26Z
- **Completed:** 2026-03-20T14:36:50Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- install.sh provides a single `bash install.sh` entry point that orchestrates 7 numbered steps: preflight, deps, ngrok, detect, configure, system setup, and deploy
- lib/deps.sh installs tmux, openssh-server, jq, fail2ban via apt and ngrok via apt repository (not snap), with interactive auth token setup
- lib/setup.sh configures SSH (drop-in config), deploys validated sudoers (restricted commands, visudo-checked), installs bashrc auto-attach hook, deploys runtime files, and runs verification
- templates/bashrc-hook.sh provides SSH login auto-attach to tmux workspace with built-in SSH_CONNECTION guard
- Full --yes flag support for non-interactive mode with sensible defaults throughout

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/deps.sh, lib/setup.sh, and templates/bashrc-hook.sh** - `fc757ef` (feat)
2. **Task 2: Create install.sh entry point** - `408ce14` (feat)

## Files Created/Modified
- `install.sh` - Single entry point: CRLF self-healing, sources 5 lib modules, --yes flag, 7-step wizard, interactive project setup, summary
- `lib/deps.sh` - apt package installation (4 packages) and ngrok via apt repository with interactive token setup
- `lib/setup.sh` - SSH config drop-in, validated sudoers, bashrc hook, runtime file deployment, installation verification
- `templates/bashrc-hook.sh` - Auto-attach to tmux workspace on SSH login with SSH_CONNECTION guard

## Decisions Made
- ngrok installed via apt repository (not snap) -- snap fails without systemd on WSL2, apt is reliable and provides auto-updates
- Sudoers validated with `visudo -c -f` before copying to `/etc/sudoers.d/cc-tmux` -- prevents catastrophic lockout from syntax errors
- Added SSH_CONNECTION guard directly in bashrc-hook.sh template as defense-in-depth (the .bashrc block also guards, but the template protects against direct sourcing)
- step_configure exported from setup.sh for reuse; install.sh wraps SSH/sudoers/bashrc calls in its own step_setup_system

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added SSH_CONNECTION guard to bashrc-hook.sh template**
- **Found during:** Task 1 (bashrc-hook.sh creation)
- **Issue:** Plan's template code did not include SSH_CONNECTION check, but acceptance criteria required it. Without it, sourcing the template directly (outside .bashrc context) would attempt tmux attach unconditionally.
- **Fix:** Added guard at top of template: `if [ -z "$SSH_CONNECTION" ] || [ -n "$TMUX" ]; then return 0; fi`
- **Files modified:** templates/bashrc-hook.sh
- **Verification:** `grep SSH_CONNECTION templates/bashrc-hook.sh` confirms presence
- **Committed in:** fc757ef (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Defensive guard adds safety without scope creep. Template now self-protects against misuse.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 1 is fully complete: all lib modules, installer, and templates are in place
- Running `bash install.sh` on a clean WSL2 instance will install all dependencies and configure the system
- Phase 2 (SSH & Security) can build on the SSH config drop-in at `/etc/ssh/sshd_config.d/cc-tmux.conf` to harden settings
- Phase 3 (Tunnel Layer) can use the ngrok installation and config.env values
- Phase 4 (Workspace & Mobile) can extend the bashrc-hook.sh template with workspace-init logic

---
*Phase: 01-foundation-installer*
*Completed: 2026-03-20*
