---
phase: 05-robustness-lifecycle
plan: 01
subsystem: infra
tags: [bash, error-handling, diagnostics, health-check]

# Dependency graph
requires:
  - phase: 04-workspace-mobile
    provides: CLI entry point (bin/cc-tmux), workspace module, tunnel provider files
provides:
  - "Error-to-file logging in log_error (timestamped to ~/.cc-tmux/error.log)"
  - "Error log truncation (truncate_error_log with 5000/1000 threshold)"
  - "Bashrc block removal (remove_bashrc_block counterpart)"
  - "Doctor output helpers (log_check_pass, log_check_fail)"
  - "13-check health diagnostic (run_doctor in lib/doctor.sh)"
affects: [05-robustness-lifecycle, 06-user-experience-documentation]

# Tech tracking
tech-stack:
  added: []
  patterns: [diagnose-only health checks with fix hints, error log rotation]

key-files:
  created: [lib/doctor.sh]
  modified: [lib/common.sh]

key-decisions:
  - "Doctor is diagnose-only -- never auto-fixes, each failure includes a Fix: hint"
  - "Error log guarded by directory existence check to avoid failure before installation"
  - "log_check_fail uses uppercase [FAIL] for visual prominence vs lowercase [pass]"
  - "check_ngrok treats missing auth token as pass (binary present) with advisory hint"

patterns-established:
  - "Health check pattern: check_X returns 0/1, uses log_check_pass/fail, includes log_hint on failure"
  - "Error log rotation pattern: tail -n 1000 + mv (same as tunnel watchdog)"

requirements-completed: [ROB-01, ROB-02, ROB-03]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 5 Plan 1: Error Handling & Doctor Diagnostics Summary

**Error-to-file logging with log rotation in common.sh, plus 13-check health diagnostic command in new lib/doctor.sh**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T16:47:03Z
- **Completed:** 2026-03-20T16:48:57Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Enhanced log_error to append timestamped entries to ~/.cc-tmux/error.log alongside stderr output
- Added truncate_error_log, remove_bashrc_block, log_check_pass, and log_check_fail utilities
- Created lib/doctor.sh with 13 modular check functions covering WSL, tmux, SSH, fail2ban, ngrok, tunnel files, config, projects, directories, tmux.conf, and CLI
- run_doctor orchestrator tallies pass/fail with proper exit code (0 = all pass, 1 = any fail)

## Task Commits

Each task was committed atomically:

1. **Task 1: Enhance lib/common.sh with error logging, bashrc removal, and doctor output helpers** - `cbb253e` (feat)
2. **Task 2: Create lib/doctor.sh with modular diagnostic checks** - `eafeb23` (feat)

## Files Created/Modified
- `lib/common.sh` - Added log_error file logging, truncate_error_log, remove_bashrc_block, log_check_pass, log_check_fail
- `lib/doctor.sh` - New file with 13 check functions and run_doctor orchestrator

## Decisions Made
- Doctor is diagnose-only -- never auto-fixes, each failure includes a Fix: hint (locked user decision from plan)
- Error log guarded by directory existence check to avoid failure before installation
- log_check_fail uses uppercase [FAIL] for visual prominence vs lowercase [pass]
- check_ngrok treats missing auth token as pass (binary present) with advisory hint rather than failure

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Error handling foundation ready for Plan 02 to wire truncate_error_log into bin/cc-tmux
- lib/doctor.sh ready for Plan 02 to add `cc-tmux doctor` CLI command
- remove_bashrc_block ready for uninstall module in Plan 02

## Self-Check: PASSED

- lib/common.sh: FOUND
- lib/doctor.sh: FOUND
- 05-01-SUMMARY.md: FOUND
- Commit cbb253e: FOUND
- Commit eafeb23: FOUND

---
*Phase: 05-robustness-lifecycle*
*Completed: 2026-03-20*
