---
phase: 05-robustness-lifecycle
plan: 02
subsystem: cli
tags: [bash, git, update, uninstall, lifecycle, cli-router]

# Dependency graph
requires:
  - phase: 05-01
    provides: "doctor.sh module, remove_bashrc_block, truncate_error_log, log_check_pass/fail"
  - phase: 01-foundation-installer
    provides: "lib/common.sh, lib/config.sh, lib/setup.sh (step_deploy), bashrc block management"
provides:
  - "lib/update.sh with git-based self-update, dirty repo handling, config backup/restore"
  - "lib/uninstall.sh with ordered teardown, confirmation prompt, --yes bypass"
  - "CLI routing for doctor, update, uninstall, version subcommands"
  - "File-existence guards on lazy-loaded library modules"
  - "Input validation with clear error messages for invalid commands"
affects: [06-documentation]

# Tech tracking
tech-stack:
  added: []
  patterns: [file-existence-guard-before-source, ordered-teardown-phases, config-backup-restore]

key-files:
  created: [lib/update.sh, lib/uninstall.sh]
  modified: [bin/cc-tmux]

key-decisions:
  - "Update sources step_deploy from repo directory (not ~/.cc-tmux/) to pick up new files"
  - "Uninstall echo of apt remove command is informational only -- script never removes system packages"
  - "set -euo pipefail already present in all entry-point scripts from prior phases -- no changes needed"
  - "Path existence check in project add is a warning, not an error -- path may be created later or be a Windows mount"

patterns-established:
  - "File-existence guard before sourcing optional libs: if [[ ! -f ... ]]; then log_error + exit; fi"
  - "Ordered teardown phases: stop services, sudo rm, bashrc cleanup, user files, ~/.cc-tmux last"
  - "Config backup/restore around re-deploy: backup before, restore after step_deploy"

requirements-completed: [ROB-01, ROB-02, ROB-05, INST-07]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 05 Plan 02: Update, Uninstall, and CLI Wiring Summary

**Git-based self-update with config backup/restore, ordered uninstall with confirmation prompt, and CLI routing for all lifecycle subcommands with file-existence guards**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T16:51:17Z
- **Completed:** 2026-03-20T16:53:56Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created lib/update.sh with git-based version check (network timeout), dirty repo handling (stash or abort), config backup/restore, and re-deploy via step_deploy from the repo directory
- Created lib/uninstall.sh with 5-phase ordered teardown, confirmation prompt, and --yes bypass that removes all cc-tmux artifacts without touching system packages
- Wired doctor, update, uninstall, and version subcommands into bin/cc-tmux with file-existence guards on all lazy-loaded modules
- Added error log truncation at CLI startup, path existence warning in project add, and "Unknown command" error for invalid subcommands

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/update.sh and lib/uninstall.sh** - `c346264` (feat)
2. **Task 2: Wire doctor/update/uninstall/version into bin/cc-tmux** - `a78e5ab` (feat)

## Files Created/Modified
- `lib/update.sh` - Self-update: check_for_updates, handle_dirty_repo, run_update with config backup and repo-sourced step_deploy
- `lib/uninstall.sh` - Clean uninstall: run_uninstall with 5-phase ordered teardown and confirmation prompt
- `bin/cc-tmux` - CLI entry point: added doctor/update/uninstall/version branches, file-existence guards, truncate_error_log, improved error messages

## Decisions Made
- Update sources step_deploy from the repo directory (`$repo_dir/lib/setup.sh`) rather than from `~/.cc-tmux/` because the running script is the deployed copy and step_deploy needs to find the newly pulled files
- Uninstall's final message includes `sudo apt remove` as user guidance only -- the script itself never removes system packages
- Confirmed all three entry-point scripts (bin/cc-tmux, startup.sh, install.sh) already have `set -euo pipefail` from prior phases -- no changes needed
- Path existence check in project add is a warning (not error) because the path might be a Windows mount temporarily unavailable

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All robustness and lifecycle management features are complete
- Doctor diagnoses installation health, update manages versions, uninstall performs clean teardown
- CLI now routes all 10 subcommands (start, stop, project, tunnel, doctor, update, uninstall, version, help, fallthrough) with input validation
- Ready for Phase 06 documentation

---
*Phase: 05-robustness-lifecycle*
*Completed: 2026-03-20*
