# Phase 4: Workspace & Mobile - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Complete tmux workspace with managed project tabs, session persistence, and mobile-adaptive layout. Creates the tmux config, workspace initialization logic, project management CLI (`cc-tmux` entry point), and mobile auto-detection via terminal width. Builds on Phase 1's projects.conf system and Phase 3's startup.sh.

Requirements: WRK-01, WRK-02, WRK-03, WRK-04, WRK-05, MOB-01, MOB-02, MOB-03

</domain>

<decisions>
## Implementation Decisions

### Workspace Session Management
- Session name: `work` (same as V1 — familiar to existing users)
- On startup: read `~/.cc-tmux/projects.conf`, create one tmux window per project
- Each window: named after project, cd to project path, then launch `powershell.exe`
- If projects.conf is empty: create single window named "default" in user's Documents folder
- If session already exists: attach to it (don't create duplicate)
- Create as `lib/workspace.sh` module with `workspace_init()` and `workspace_attach()` functions
- startup.sh (Phase 3) already handles attach — workspace.sh handles session creation

### Project CLI Commands
- Entry point: `bin/cc-tmux` — bash script with subcommand routing
- `cc-tmux project add <name> <path>` — adds to projects.conf AND creates tmux window if session active
- `cc-tmux project remove <name>` — removes from projects.conf AND kills tmux window if session active
- `cc-tmux project list` — shows all configured projects with paths
- `cc-tmux start` — runs startup.sh (SSH + tunnel + workspace)
- `cc-tmux tunnel` — shows tunnel status (delegates to tunnel_status from Phase 3)
- lib/config.sh already has `add_project()`, `remove_project()`, `list_projects()` — CLI wraps these with live tmux window management
- Installed to `~/.cc-tmux/bin/cc-tmux` with PATH export in .bashrc

### tmux Configuration
- Template file: `templates/tmux.conf.tpl` with `__USERNAME__` placeholder
- Variable substitution at deploy time via `sed` (same as .gitattributes pattern)
- Style: V1's Catppuccin-inspired theme (blue #89b4fa on dark #1e1e2e)
- Mouse support enabled, clickable tabs, scroll history 50000 lines
- Keybindings from V1: `|` split horizontal, `-` split vertical, `R` reload, `c` new window, Alt+arrows to switch
- Clickable `+` button in status-right creates new PowerShell tab in user's Documents
- New window base index 1, renumber on close
- Mobile/desktop toggle keybindings: Ctrl+B, Shift+M / Ctrl+B, Shift+N (same as V1)

### Mobile Auto-Detection
- Use tmux `client-session-changed` hook to check `#{client_width}`
- If width < 80 columns: apply mobile layout automatically
- Mobile mode changes: hide session name (status-left = ""), wider tab labels with spacing, minimal status-right (just + button), larger window-status-separator for tap targets
- Desktop mode: full status bar with session name, time, date (V1 default)
- Auto-detect fires on every attach — no persistence needed
- Manual toggle overrides auto-detect for current session only
- Ctrl+B, Shift+M → mobile mode with display message "Mobile mode"
- Ctrl+B, Shift+N → reload tmux.conf (back to desktop defaults) with display message "Desktop mode"

### Claude's Discretion
- Exact subcommand routing pattern in bin/cc-tmux (case statement vs function dispatch)
- Whether to add `cc-tmux stop` command (stop tunnel + kill session)
- Tab completion for cc-tmux subcommands
- Whether workspace_init should wait for powershell.exe to be ready before creating next window

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### V1 Reference
- `V1/tmux.conf` — V1 tmux config with Catppuccin theme, mobile mode, keybindings
- `V1/workspace-init.sh` — V1 workspace creation logic (project loop, powershell.exe)
- `V1/attach.sh` — V1 attach/create logic

### Phase 1-3 Foundations
- `lib/config.sh` — add_project(), remove_project(), list_projects(), project_count() already implemented
- `lib/common.sh` — Utility functions (logging, guards)
- `lib/detect.sh` — detect_windows_username() for tmux.conf template
- `startup.sh` — Phase 3 entry point that Phase 4 workspace_init integrates with
- `install.sh` — Needs to deploy tmux.conf template and bin/cc-tmux

### Research
- `.planning/research/FEATURES.md` — tmux wrapper tool feature comparison
- `.planning/research/ARCHITECTURE.md` — CLI entry point design, bin/ directory pattern

### Project
- `.planning/PROJECT.md` — Core value, constraints
- `.planning/REQUIREMENTS.md` — WRK-01 through WRK-05, MOB-01 through MOB-03

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/config.sh:add_project()` — Already validates path, checks duplicates, appends to projects.conf
- `lib/config.sh:remove_project()` — Already removes by name with sed
- `lib/config.sh:list_projects()` — Already formats output with name → path
- `lib/config.sh:project_count()` — Already counts entries
- `lib/detect.sh:detect_windows_username()` — For tmux.conf template substitution
- `startup.sh` — Already starts SSH, tunnel, and attaches to tmux — needs workspace_init call added

### Established Patterns
- Sourced modules: `lib/workspace.sh` follows same pattern as other lib/ files
- Template substitution: `sed -i "s/__PLACEHOLDER__/$VALUE/g"` used by installer
- Deploy pattern: `lib/setup.sh:step_deploy()` copies files to `~/.cc-tmux/`
- Config in `~/.cc-tmux/`: projects.conf already exists from Phase 1

### Integration Points
- `startup.sh` — Needs to call `workspace_init` before `exec tmux attach`
- `install.sh` — Needs to deploy tmux.conf template and bin/cc-tmux
- `lib/setup.sh:step_deploy()` — Needs to handle templates/ and bin/ subdirectories
- `~/.bashrc` — PATH export for `~/.cc-tmux/bin/`

</code_context>

<specifics>
## Specific Ideas

- V1's tmux config is already good — preserve the look and feel, just make it template-based
- The `+` button creating a new PowerShell tab was a nice V1 touch — keep it
- Mobile mode from V1 worked well — auto-detection makes it seamless
- "inter-device operability" was a key user goal — the attach/reattach flow must be bulletproof

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-workspace-mobile*
*Context gathered: 2026-03-20*
