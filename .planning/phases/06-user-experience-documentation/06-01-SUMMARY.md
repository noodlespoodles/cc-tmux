---
phase: 06-user-experience-documentation
plan: 01
subsystem: installer
tags: [qrencode, powershell, desktop-shortcut, qr-code, wsl-interop]

# Dependency graph
requires:
  - phase: 01-foundation-installer
    provides: install.sh step sequence, lib/deps.sh, lib/setup.sh, lib/common.sh logging
  - phase: 03-tunnel-lifecycle
    provides: tunnel_url() function and startup.sh connection info display
  - phase: 05-robustness-maintenance
    provides: lib/uninstall.sh with phased teardown
provides:
  - create_desktop_shortcut() function in lib/setup.sh
  - show_qr_code() function in startup.sh
  - qrencode apt dependency in lib/deps.sh
  - Desktop shortcut removal in lib/uninstall.sh
affects: [06-02-readme-documentation]

# Tech tracking
tech-stack:
  added: [qrencode, WScript.Shell COM via powershell.exe]
  patterns: [PowerShell interop from WSL with dollar-sign escaping, graceful feature degradation]

key-files:
  created: []
  modified: [lib/deps.sh, lib/setup.sh, install.sh, startup.sh, lib/uninstall.sh]

key-decisions:
  - "PowerShell command inlined as semicolon-separated statements rather than multi-line for simpler escaping"
  - "QR code uses ANSIUTF8 output type with margin 1 for compact terminal display"
  - "Shortcut removal placed in Phase 2 (system configs) of uninstall, alongside other PowerShell-dependent operations"

patterns-established:
  - "PowerShell interop: escape all $ as \\$ in double-quoted bash strings, guard with command -v powershell.exe check"
  - "Optional feature degradation: check dependency availability, warn and skip with return 0 on absence"

requirements-completed: [INST-08, MOB-04]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 06 Plan 01: Desktop Shortcut & QR Code Summary

**Automated Windows desktop shortcut creation via PowerShell interop and QR code phone onboarding via qrencode in startup.sh**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T17:15:11Z
- **Completed:** 2026-03-20T17:17:15Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Desktop shortcut "Claude Workspace" created automatically during install step 11 of 11
- QR code encoding ssh://user@host:port displayed after tunnel connects in startup.sh
- Uninstall extended to remove desktop shortcut via PowerShell
- All three features degrade gracefully when dependencies unavailable

## Task Commits

Each task was committed atomically:

1. **Task 1: Add qrencode dependency and desktop shortcut function** - `8c63694` (feat)
2. **Task 2: Wire shortcut into installer, add QR to startup, extend uninstall** - `7f201e5` (feat)

**Plan metadata:** (pending) (docs: complete plan)

## Files Created/Modified
- `lib/deps.sh` - Added qrencode to apt dependency list (5th install_package call)
- `lib/setup.sh` - Added create_desktop_shortcut() function with PowerShell COM interop
- `install.sh` - Bumped TOTAL_STEPS to 11, wired shortcut creation as step 11
- `startup.sh` - Added show_qr_code() function with ANSIUTF8 QR display after tunnel info
- `lib/uninstall.sh` - Added desktop shortcut to removal list and PowerShell Remove-Item in Phase 2

## Decisions Made
- PowerShell command inlined as semicolon-separated single line rather than multi-line heredoc -- simpler escaping, fewer quoting edge cases
- QR code uses ANSIUTF8 output with -m 1 (margin 1) for the most compact terminal rendering
- Shortcut removal grouped with system config removal (Phase 2 of uninstall) since both require PowerShell interop

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All UX automation features complete, ready for README documentation (Plan 02)
- cc-tmux subcommand reference available from bin/cc-tmux for quick reference card
- QR code and shortcut features provide content for README "Phone Setup" and "Setup" sections

## Self-Check: PASSED

All files found, all commits verified.

---
*Phase: 06-user-experience-documentation*
*Completed: 2026-03-20*
