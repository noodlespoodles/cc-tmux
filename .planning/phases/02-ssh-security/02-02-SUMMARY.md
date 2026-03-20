---
phase: 02-ssh-security
plan: 02
subsystem: infra
tags: [ssh, fail2ban, sudoers, bash, installer]

# Dependency graph
requires:
  - phase: 02-ssh-security/plan-01
    provides: lib/ssh-hardening.sh module with step_harden_ssh orchestrator
provides:
  - SSH hardening wired into installer main sequence as step 7 of 8
  - Extended sudoers with fail2ban and sshd validation commands
  - Phase 2 verification checks (SSH key, hardened config, fail2ban jail)
affects: [03-tunnel-exposure, 04-workspace-mobile]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "log_step called in install.sh before external step functions that lack internal log_step"
    - "Sudoers uses service wildcards (service ssh *, service fail2ban *) for start/stop/restart/status"

key-files:
  created: []
  modified:
    - install.sh
    - lib/setup.sh

key-decisions:
  - "log_step 7 called in install.sh before step_harden_ssh rather than modifying Plan 01's ssh-hardening.sh"
  - "Sudoers uses service wildcards instead of listing each subcommand individually"
  - "Verification expanded to 10 checks (7 Phase 1 + 3 Phase 2)"

patterns-established:
  - "External step functions without internal log_step get a log_step call at the call site in install.sh"

requirements-completed: [SEC-01, SEC-02, SEC-03, SEC-04]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 02 Plan 02: Installer Integration Summary

**SSH hardening wired into installer as step 7/8 with extended sudoers and 10-point verification**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T15:11:21Z
- **Completed:** 2026-03-20T15:13:47Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- install.sh sources lib/ssh-hardening.sh and calls step_harden_ssh as step 7 of 8
- Sudoers extended with passwordless fail2ban service management and sshd validation commands
- step_verify expanded from 7 to 10 checks with SSH key pair, hardened config, and fail2ban jail checks
- step_deploy log_step updated to 8 to accommodate new step 7

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire ssh-hardening.sh into install.sh** - `cacfa9f` (feat)
2. **Task 2: Update sudoers and verification in lib/setup.sh** - `9e4fc53` (feat)

## Files Created/Modified
- `install.sh` - Sources ssh-hardening.sh, TOTAL_STEPS=8, step_harden_ssh as step 7
- `lib/setup.sh` - Extended sudoers, step_deploy log_step 8, 3 new verification checks

## Decisions Made
- log_step 7 called directly in install.sh main() before step_harden_ssh, avoiding modification of Plan 01's ssh-hardening.sh module. This keeps the step numbering in the file that owns TOTAL_STEPS.
- Sudoers uses `service ssh *` and `service fail2ban *` wildcards rather than listing start/restart/status individually -- cleaner and covers all service subcommands.
- Verification expanded to 10 checks total: the 3 new Phase 2 checks (SSH key pair exists, hardened config at 00-cc-tmux.conf, fail2ban jail at jail.d/cc-tmux.conf) are appended after the 7 existing Phase 1 checks.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Full SSH hardening flow now executes during `bash install.sh`
- Phase 2 (ssh-security) complete: key generation, hardened config, fail2ban, and installer integration all done
- Ready for Phase 3 (tunnel-exposure) which will build on the secured SSH foundation

---
*Phase: 02-ssh-security*
*Completed: 2026-03-20*
