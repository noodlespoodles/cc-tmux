# Phase 6: User Experience & Documentation - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Final polish: automate Windows desktop shortcut creation, display QR code for phone SSH setup, and write comprehensive README for non-technical users. This phase wraps the fully-functional toolkit (Phases 1-5) with user-facing convenience and documentation.

Requirements: INST-08, MOB-04, DOC-01, DOC-02, DOC-03

</domain>

<decisions>
## Implementation Decisions

### Desktop Shortcut (INST-08)
- Installer calls `powershell.exe` from WSL to create desktop shortcut automatically (no manual PowerShell step)
- Shortcut target: `wsl.exe -d Ubuntu -- bash -lc '~/startup.sh'` (same as V1)
- Shortcut name: "Claude Workspace"
- Icon: wsl.exe default icon (no custom icon)
- Shortcut creation as a function in lib/setup.sh: `create_desktop_shortcut()`
- Wired into install.sh as a step (after deploy, before verify)
- Uninstall.sh (Phase 5) extended to remove the desktop shortcut via `powershell.exe`
- If powershell.exe not available: warn and skip (graceful degradation)

### QR Code Display (MOB-04)
- Install `qrencode` package via apt (add to deps.sh dependency list)
- Generate QR code encoding `ssh://user@host:port` connection string
- Display as ANSI art in terminal after tunnel starts in startup.sh
- Show alongside text connection info (address, port, username)
- If qrencode not installed: skip QR, show text-only with hint to install
- QR display function in startup.sh or a small helper

### README Structure (DOC-01, DOC-02, DOC-03)
- Written for non-technical users — assume zero knowledge of WSL, SSH, or tmux
- Friendly, direct tone — no jargon, explain concepts when first introduced
- Structure:
  1. **What This Does** — one paragraph + V1-style ASCII architecture diagram
  2. **What You Need** — prerequisites list (Windows 10/11, WSL2, Android phone, ngrok account)
  3. **Setup** — 3 steps: install WSL, clone repo, run install.sh (down from V1's 13 steps)
  4. **Phone Setup** — how to import SSH key into Termius and connect
  5. **Daily Usage** — PC usage, phone usage, when you leave/return
  6. **Quick Reference** — table of cc-tmux commands (start, stop, project add/remove/list, tunnel, doctor, update, uninstall)
  7. **Troubleshooting** — problem → solution format
  8. **Uninstalling** — brief `cc-tmux uninstall` section
  9. **Files Reference** — what's installed where
  10. **License** — MIT

### Troubleshooting Section (DOC-03)
- First step for ANY issue: "Run `cc-tmux doctor`"
- Cover these issues (from V1 + new):
  - Can't connect from Termius (port changed, VPN interference, PC sleeping)
  - SSH won't start
  - ngrok isn't running
  - tmux session disappeared
  - PowerShell won't start in tab
  - Closed window by accident
  - PC went to sleep
  - "Permission denied" on SSH (key not imported)
- Format: problem heading → 2-3 line solution with exact commands

### Claude's Discretion
- Exact README wording and length
- Whether to add badges to README (build status, license, etc.)
- Whether to include a "Contributing" section
- QR code size/error correction level
- Whether to add a CHANGELOG.md

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### V1 Reference
- `V1/README.md` — V1 documentation (preserve good parts, simplify 13-step setup)
- `V1/setup-shortcut.ps1` — V1 PowerShell shortcut creation (adapt for automated call from WSL)

### Existing codebase
- `startup.sh` — Entry point to add QR code display after tunnel starts
- `install.sh` — Add shortcut creation step
- `lib/setup.sh` — Add create_desktop_shortcut() function, extend step_verify
- `lib/deps.sh` — Add qrencode to dependency list
- `lib/uninstall.sh` — Extend with desktop shortcut removal
- `bin/cc-tmux` — All subcommands documented (reference for quick reference card)
- `lib/tunnel/ngrok.sh` — tunnel_url() for QR code data

### Project
- `.planning/PROJECT.md` — Core value (non-technical users)
- `.planning/REQUIREMENTS.md` — INST-08, MOB-04, DOC-01 through DOC-03

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `V1/setup-shortcut.ps1` — PowerShell script for shortcut creation (can be called inline)
- `V1/README.md` — Good structure, ASCII diagram, troubleshooting section to adapt
- `lib/common.sh:log_ok/error/warn/hint()` — For shortcut creation output
- `lib/tunnel/ngrok.sh:tunnel_url()` — Returns host:port for QR encoding
- `lib/detect.sh:detect_windows_username()` — For shortcut path

### Established Patterns
- Install step functions: `step_*()` pattern in install.sh
- Graceful degradation: warn and skip when optional tools unavailable
- Deploy pattern: lib/setup.sh:step_deploy() handles file copying

### Integration Points
- `install.sh` — New step for shortcut creation (TOTAL_STEPS increment)
- `startup.sh` — QR code display after tunnel connection info
- `lib/deps.sh` — Add qrencode to package list
- `lib/setup.sh` — create_desktop_shortcut() function + verify check
- `lib/uninstall.sh` — Desktop shortcut removal

</code_context>

<specifics>
## Specific Ideas

- V1's README was thorough but 13 steps was too many — V2 should be 3 steps max
- V1's ASCII architecture diagram was effective — keep something similar
- The user specifically said "ease of install" and "not very technical" — README tone matters
- Quick reference card should be copy-paste friendly

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-user-experience-documentation*
*Context gathered: 2026-03-20*
