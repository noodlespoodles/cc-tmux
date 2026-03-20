---
phase: 02-ssh-security
plan: 01
subsystem: security
tags: [ssh, ed25519, fail2ban, sshd, key-auth, hardening]

# Dependency graph
requires:
  - phase: 01-foundation-installer
    provides: "lib/common.sh (logging), lib/config.sh (write_config), lib/setup.sh (Phase 1 SSH config)"
provides:
  - "lib/ssh-hardening.sh with 6 functions: generate_ssh_keys, install_public_key, display_key_instructions, write_hardened_ssh_config, configure_fail2ban, step_harden_ssh"
affects: [02-ssh-security, 03-tunnel-layer]

# Tech tracking
tech-stack:
  added: [ssh-keygen, sshd_config.d drop-in, fail2ban jail.d drop-in]
  patterns: [idempotent key generation, config-validate-before-restart, fail2ban backend auto-detection]

key-files:
  created: [lib/ssh-hardening.sh]
  modified: []

key-decisions:
  - "Dedicated lib/ssh-hardening.sh module rather than extending lib/setup.sh -- clean separation of Phase 1 basic and Phase 2 hardened config"
  - "Drop-in renamed from cc-tmux.conf to 00-cc-tmux.conf for alphabetical precedence over other sshd_config.d files"
  - "Protocol 2 omitted -- removed from OpenSSH 7.6, causes parse errors on modern systems"
  - "Match Address block placed last in config -- sshd treats it as a context switch until EOF"
  - "fail2ban backend auto-detected: auth.log -> auto, systemd-journald -> systemd"

patterns-established:
  - "Config validation pattern: write config, validate with tool -t, rollback on failure"
  - "Interactive confirmation: check NONINTERACTIVE flag before destructive changes"
  - "Phase upgrade pattern: new drop-in filename replaces old, rm -f old file for cleanup"

requirements-completed: [SEC-01, SEC-02, SEC-03, SEC-04]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 2 Plan 1: SSH Hardening Module Summary

**Ed25519 key generation with idempotent authorized_keys install, hardened sshd drop-in (key-only + localhost fallback), fail2ban jail, and Termius import guide**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T15:05:49Z
- **Completed:** 2026-03-20T15:08:09Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Created lib/ssh-hardening.sh with all 6 SSH security functions ready for integration
- Ed25519 key generation with correct permissions (600 private, 644 public, 700 directories)
- Hardened sshd config with key-only auth, localhost password fallback, and sshd -t validation before restart
- fail2ban jail with auto-detected backend and configurable retry/ban thresholds
- Interactive confirmation flow before disabling password auth (respects NONINTERACTIVE flag)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/ssh-hardening.sh with key generation, public key install, and key display** - `f84dbc0` (feat)
2. **Task 2: Add SSH hardening, fail2ban, and orchestrator functions** - `f029fb0` (feat)

## Files Created/Modified
- `lib/ssh-hardening.sh` - Complete SSH hardening module with 6 functions: generate_ssh_keys, install_public_key, display_key_instructions, write_hardened_ssh_config, configure_fail2ban, step_harden_ssh

## Decisions Made
- Dedicated module (lib/ssh-hardening.sh) keeps Phase 2 logic separate from Phase 1's lib/setup.sh
- Drop-in renamed to 00-cc-tmux.conf for alphabetical precedence in sshd_config.d
- Protocol 2 intentionally omitted (removed from OpenSSH 7.6, causes parse errors)
- Match Address block placed as last section in config (sshd treats it as context switch until EOF)
- fail2ban backend auto-detected: checks for /var/log/auth.log first, falls back to systemd journal
- Rollback on sshd -t failure restores minimal safe config (password auth enabled) to prevent lockout

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- lib/ssh-hardening.sh is complete and ready for Plan 02 to wire into install.sh
- Plan 02 needs to: source ssh-hardening.sh in install.sh, call step_harden_ssh, update sudoers for fail2ban commands, add verification checks
- The step_harden_ssh orchestrator function handles the full sequence including interactive confirmation

## Self-Check: PASSED

- lib/ssh-hardening.sh: FOUND
- 02-01-SUMMARY.md: FOUND
- Commit f84dbc0: FOUND
- Commit f029fb0: FOUND

---
*Phase: 02-ssh-security*
*Completed: 2026-03-20*
