# Phase 4: Workspace & Mobile - Research

**Researched:** 2026-03-20
**Domain:** tmux workspace management, CLI entry point, mobile-adaptive layout
**Confidence:** HIGH

## Summary

Phase 4 builds the core workspace experience: tmux session creation from projects.conf, a `cc-tmux` CLI entry point with subcommand routing, tmux.conf template with Catppuccin-inspired theme, and mobile auto-detection via terminal width. The existing codebase already has the config layer (lib/config.sh with add_project/remove_project/list_projects), the startup flow (startup.sh), and the deployment pipeline (lib/setup.sh step_deploy). Phase 4 creates four new artifacts: `lib/workspace.sh` (workspace creation logic), `templates/tmux.conf.tpl` (tmux config template), `bin/cc-tmux` (CLI entry point), and a `templates/mobile-check.sh` helper script for auto-detection. It also modifies three existing files: `startup.sh` (add workspace_init call), `install.sh` (deploy bin/ and PATH setup), and `templates/bashrc-hook.sh` (integrate workspace_init before attach).

The V1 reference code already contains proven patterns for every piece -- workspace-init.sh shows the project loop with `new-session`/`new-window`/`send-keys`, tmux.conf has the Catppuccin theme and mobile toggle keybindings, and attach.sh has the create-or-attach logic. The V2 implementation mainly converts these from hardcoded scripts to config-driven, template-based equivalents.

**Primary recommendation:** Use `set-hook -g client-attached` to run a width-check shell script on every attach. The script reads `#{client_width}` via `tmux display -p` and applies mobile or desktop settings accordingly. Manual toggle keybindings (Ctrl+B, Shift+M/N) override auto-detect for the current session.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Session name: `work` (same as V1)
- On startup: read `~/.cc-tmux/projects.conf`, create one tmux window per project
- Each window: named after project, cd to project path, then launch `powershell.exe`
- If projects.conf is empty: create single window named "default" in user's Documents folder
- If session already exists: attach to it (don't create duplicate)
- Create as `lib/workspace.sh` module with `workspace_init()` and `workspace_attach()` functions
- startup.sh (Phase 3) already handles attach -- workspace.sh handles session creation
- Entry point: `bin/cc-tmux` -- bash script with subcommand routing
- `cc-tmux project add <name> <path>` -- adds to projects.conf AND creates tmux window if session active
- `cc-tmux project remove <name>` -- removes from projects.conf AND kills tmux window if session active
- `cc-tmux project list` -- shows all configured projects with paths
- `cc-tmux start` -- runs startup.sh (SSH + tunnel + workspace)
- `cc-tmux tunnel` -- shows tunnel status (delegates to tunnel_status from Phase 3)
- lib/config.sh already has `add_project()`, `remove_project()`, `list_projects()` -- CLI wraps these with live tmux window management
- Installed to `~/.cc-tmux/bin/cc-tmux` with PATH export in .bashrc
- Template file: `templates/tmux.conf.tpl` with `__USERNAME__` placeholder
- Variable substitution at deploy time via `sed`
- Style: V1's Catppuccin-inspired theme (blue #89b4fa on dark #1e1e2e)
- Mouse support enabled, clickable tabs, scroll history 50000 lines
- Keybindings from V1: `|` split horizontal, `-` split vertical, `R` reload, `c` new window, Alt+arrows to switch
- Clickable `+` button in status-right creates new PowerShell tab in user's Documents
- New window base index 1, renumber on close
- Mobile/desktop toggle keybindings: Ctrl+B, Shift+M / Ctrl+B, Shift+N
- Use tmux `client-attached` hook (not `client-session-changed`) to check `#{client_width}`
- If width < 80 columns: apply mobile layout automatically
- Mobile mode changes: hide session name, wider tab labels with spacing, minimal status-right, larger window-status-separator for tap targets
- Desktop mode: full status bar with session name, time, date (V1 default)
- Auto-detect fires on every attach -- no persistence needed
- Manual toggle overrides auto-detect for current session only

### Claude's Discretion
- Exact subcommand routing pattern in bin/cc-tmux (case statement vs function dispatch)
- Whether to add `cc-tmux stop` command (stop tunnel + kill session)
- Tab completion for cc-tmux subcommands
- Whether workspace_init should wait for powershell.exe to be ready before creating next window

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| WRK-01 | tmux workspace creates project tabs from configured project list on startup | V1 workspace-init.sh pattern (new-session + new-window loop), projects.conf format already defined in lib/config.sh |
| WRK-02 | User can add/remove/list projects via CLI commands without editing scripts | lib/config.sh already has add_project/remove_project/list_projects; bin/cc-tmux wraps these with live tmux window management |
| WRK-03 | Workspace sessions persist -- closing terminal window doesn't kill sessions | tmux sessions persist by design; startup.sh uses `tmux has-session` check before creating; bashrc-hook.sh uses `exec tmux attach` |
| WRK-04 | Attaching from any terminal (PC or phone) reconnects to existing workspace seamlessly | bashrc-hook.sh auto-attach pattern already works; workspace_init only runs if session doesn't exist |
| WRK-05 | tmux config includes mouse support, clickable tabs, sensible keybindings | V1 tmux.conf already has all of these; convert to template with __USERNAME__ substitution |
| MOB-01 | tmux auto-detects mobile device (narrow terminal) and switches to mobile-optimized layout | tmux `set-hook -g client-attached` with `run-shell` script checking `#{client_width}` via `tmux display -p` |
| MOB-02 | Mobile mode has larger tap targets, minimal status bar, essential info only | V1 mobile mode bind M command provides exact styling; auto-detect script applies same settings |
| MOB-03 | User can manually toggle mobile/desktop mode via keybinding | V1 bind M/N pattern preserved; N reloads tmux.conf (desktop defaults), M applies mobile overrides |

</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| tmux | 3.4+ (apt default on Ubuntu 24.04 LTS) | Terminal multiplexer, session management | Already installed as Phase 1 dependency; provides hooks, format variables, scripted session creation |
| bash | 5.0+ | Shell scripting for all modules | Already validated in install.sh preflight; only dependency for CLI and workspace scripts |
| sed | GNU sed (apt default) | Template variable substitution | Already used throughout project for config file manipulation |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| powershell.exe | Default shell in tmux windows | Launched via `send-keys` after window creation; Windows host shell for Claude Code |
| tmux display -p | Query runtime format variables | Used by mobile-check.sh to read `#{client_width}` at attach time |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `set-hook client-attached` + script | `%if #{<:#{client_width},80}` in tmux.conf | Conditional formats only evaluate at conf load time, not dynamically on attach; hook+script is the only way to get per-attach behavior |
| External mobile-check.sh script | Inline shell in set-hook run-shell | Inline shell is fragile with quoting; external script is testable and maintainable |
| case statement for CLI routing | getopts / function dispatch table | Case statement is the established bash pattern, matches project style, simplest for nested subcommands like `project add` |

## Architecture Patterns

### New File Structure
```
bin/
  cc-tmux                    # CLI entry point (subcommand router)
lib/
  workspace.sh               # workspace_init(), workspace_attach()
templates/
  tmux.conf.tpl              # tmux config template (__USERNAME__ placeholder)
  mobile-check.sh            # Auto-detect mobile width on attach
```

### Modified Files
```
startup.sh                   # Add: source workspace.sh, call workspace_init before attach
install.sh                   # Add: deploy bin/, PATH setup in bashrc, tmux.conf template substitution
templates/bashrc-hook.sh     # Add: call workspace_init before attach (for SSH auto-attach path)
lib/setup.sh                 # Add: deploy bin/ directory, tmux.conf template processing
```

### Pattern 1: Workspace Creation (lib/workspace.sh)
**What:** Reads projects.conf, creates tmux session with one window per project
**When to use:** Called from startup.sh and bashrc-hook.sh when session doesn't exist
**Example:**
```bash
# Source: V1/workspace-init.sh adapted to config-driven approach
workspace_init() {
    local session_name
    session_name=$(get_config "SESSION_NAME" 2>/dev/null) || session_name="work"

    # Already running -- skip
    if tmux has-session -t "$session_name" 2>/dev/null; then
        return 0
    fi

    local projects_file="$CC_TMUX_DIR/projects.conf"

    # Fallback if no projects configured
    if [[ ! -f "$projects_file" ]] || [[ ! -s "$projects_file" ]]; then
        local win_home
        win_home=$(get_config "WIN_HOME" 2>/dev/null) || win_home="/mnt/c/Users/$USER/Documents"
        tmux new-session -d -s "$session_name" -n "default" -c "$win_home"
        tmux send-keys -t "$session_name:default" "powershell.exe" Enter
        return 0
    fi

    # Read first project -- create session with it
    local first=true
    while IFS='|' read -r name path; do
        [[ -z "$name" ]] && continue
        if [[ "$first" == true ]]; then
            tmux new-session -d -s "$session_name" -n "$name" -c "$path"
            tmux send-keys -t "$session_name:$name" "powershell.exe" Enter
            first=false
        else
            tmux new-window -t "$session_name" -n "$name" -c "$path"
            tmux send-keys -t "$session_name:$name" "powershell.exe" Enter
        fi
    done < "$projects_file"

    # Select first window
    tmux select-window -t "$session_name:1"
}
```

### Pattern 2: CLI Entry Point (bin/cc-tmux)
**What:** Bash script with case-based subcommand routing
**When to use:** All user-facing commands go through this single entry point
**Example:**
```bash
#!/usr/bin/env bash
# bin/cc-tmux -- CLI entry point for cc-tmux
set -euo pipefail

CC_TMUX_DIR="$HOME/.cc-tmux"
source "$CC_TMUX_DIR/lib/common.sh"
source "$CC_TMUX_DIR/lib/config.sh"
source "$CC_TMUX_DIR/lib/workspace.sh"

case "${1:-}" in
    start)
        exec bash "$HOME/startup.sh"
        ;;
    project)
        shift
        case "${1:-}" in
            add)    # validate args, call add_project, live-add tmux window ;;
            remove) # validate args, call remove_project, live-kill tmux window ;;
            list)   list_projects ;;
            *)      echo "Usage: cc-tmux project {add|remove|list}" ;;
        esac
        ;;
    tunnel)
        # delegate to tunnel_status from Phase 3
        ;;
    *)
        echo "Usage: cc-tmux {start|project|tunnel}"
        ;;
esac
```

### Pattern 3: Live tmux Window Management
**What:** When user adds/removes a project via CLI, also create/kill the tmux window if session is active
**When to use:** `cc-tmux project add` and `cc-tmux project remove` commands
**Example:**
```bash
# After add_project succeeds, also create live window
cmd_project_add() {
    local name="$1" path="$2"
    add_project "$name" "$path" || return $?

    local session_name
    session_name=$(get_config "SESSION_NAME" 2>/dev/null) || session_name="work"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux new-window -t "$session_name" -n "$name" -c "$path"
        tmux send-keys -t "$session_name:$name" "powershell.exe" Enter
        log_ok "Window '$name' created in active session"
    fi
}

# After remove_project succeeds, also kill live window
cmd_project_remove() {
    local name="$1"
    remove_project "$name" || return $?

    local session_name
    session_name=$(get_config "SESSION_NAME" 2>/dev/null) || session_name="work"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        if tmux list-windows -t "$session_name" -F '#{window_name}' | grep -qx "$name"; then
            tmux kill-window -t "$session_name:$name"
            log_ok "Window '$name' killed in active session"
        fi
    fi
}
```

### Pattern 4: tmux.conf Template Substitution
**What:** Template file with `__USERNAME__` placeholder, replaced at deploy time
**When to use:** install.sh step_deploy processes templates before copying to ~/.tmux.conf
**Example:**
```bash
# In step_deploy or a new template processing step
deploy_tmux_conf() {
    local template="$CC_TMUX_DIR/templates/tmux.conf.tpl"
    local target="$HOME/.tmux.conf"
    local win_username
    win_username=$(get_config "WIN_USERNAME")

    cp "$template" "$target"
    sed -i "s/__USERNAME__/$win_username/g" "$target"
    chmod 644 "$target"
    log_ok "tmux.conf deployed with username: $win_username"
}
```

### Pattern 5: Mobile Auto-Detection via Hook
**What:** tmux hook runs a shell script on every attach to check terminal width
**When to use:** Configured in tmux.conf.tpl, runs automatically
**Example:**
```bash
# In tmux.conf.tpl:
set-hook -g client-attached 'run-shell "~/.cc-tmux/templates/mobile-check.sh"'

# templates/mobile-check.sh:
#!/usr/bin/env bash
WIDTH=$(tmux display -p '#{client_width}')
if [ "$WIDTH" -lt 80 ]; then
    tmux set status-left "" \; \
         set status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + " \; \
         set status-right-length 5 \; \
         setw window-status-format "#[bg=#45475a,fg=#cdd6f4]  #I: #W  " \; \
         setw window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold]  #I: #W  " \; \
         setw window-status-separator " " \; \
         display-message "Mobile mode"
else
    tmux source-file ~/.tmux.conf
fi
```

### Anti-Patterns to Avoid
- **Inline complex shell in tmux hooks:** Quoting hell. Use an external script file for the mobile-check logic instead of inlining multi-line shell in the tmux.conf set-hook command.
- **Using `%if` for mobile detection:** The `%if` conditional in tmux.conf evaluates only at config load time, not dynamically on each attach. It cannot detect the attaching client's width.
- **Creating windows without checking session exists:** Always guard `tmux new-window` with `tmux has-session` check. If session doesn't exist, the command fails silently or creates errors.
- **Hardcoding session name:** Always read from config (`get_config "SESSION_NAME"`) with fallback to "work". Makes the code testable and consistent.
- **Using `tmux attach` instead of `exec tmux attach`:** Without `exec`, the parent shell remains running, consuming resources. The `exec` replaces the shell process.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Project config storage | Custom config parser | Existing `lib/config.sh` add_project/remove_project/list_projects | Already tested, handles validation, uses simple pipe-delimited format |
| Template substitution | Custom template engine | `sed -i "s/__PLACEHOLDER__/$VALUE/g"` | One-liner, established project pattern, handles the single `__USERNAME__` placeholder |
| Session persistence | tmux-resurrect/continuum plugins | tmux native persistence + config-driven rebuild | Sessions survive terminal close natively; workspace_init recreates from config if WSL restarts |
| CLI argument parsing | getopt/getopts framework | Simple case statement with shift | Only 3 top-level commands, 3 subcommands under project; doesn't justify a framework |
| Mobile detection polling | Background daemon checking width | tmux `set-hook client-attached` | Hook fires exactly when needed (on attach), zero overhead between attaches |
| .bashrc PATH management | Manual echo >> .bashrc | Existing `add_bashrc_block` from lib/common.sh | Idempotent, uses sentinel markers, handles re-runs safely |

**Key insight:** Almost every building block for Phase 4 already exists in the codebase or in V1 reference. The work is integration, not invention.

## Common Pitfalls

### Pitfall 1: tmux send-keys Race Condition
**What goes wrong:** Creating a new window and immediately sending `powershell.exe` can fail if the window's shell hasn't initialized yet.
**Why it happens:** `tmux new-window` returns before the default shell (bash) is ready to receive input.
**How to avoid:** Add a small `sleep 0.1` between `new-window` and `send-keys`, or accept that bash receives the keystrokes and buffers them (which works in practice on WSL2 because bash starts fast). V1 does NOT sleep and works fine -- the send-keys approach is buffered.
**Warning signs:** powershell.exe not launching in some windows, especially on slower machines.

### Pitfall 2: Template Substitution with Special Characters
**What goes wrong:** Windows usernames containing special regex characters (`.`, `+`, etc.) break sed substitution.
**Why it happens:** `sed "s/__USERNAME__/$win_username/g"` treats `$win_username` as a regex replacement string.
**How to avoid:** Use a different sed delimiter (`|` or `#`) and escape the replacement string, or use `awk` for literal replacement. Windows usernames rarely have special chars, but defend against it.
**Warning signs:** Corrupted tmux.conf after deployment.

### Pitfall 3: Mobile-Check Script Infinite Loop
**What goes wrong:** If mobile-check.sh calls `tmux source-file ~/.tmux.conf` and that file has the `set-hook client-attached` directive, it could theoretically re-trigger.
**Why it happens:** `source-file` reprocesses hooks but does NOT trigger `client-attached` (that only fires on actual client attachment, not config reload).
**How to avoid:** This is NOT actually a problem -- `source-file` does not trigger `client-attached`. But the Shift+N desktop toggle should reload the conf directly, which is safe.
**Warning signs:** None expected, but worth noting for future maintainers.

### Pitfall 4: PATH Not Available in Non-Interactive Shells
**What goes wrong:** `cc-tmux` command not found when running from cron, systemd, or non-login shells.
**Why it happens:** `.bashrc` is only sourced for interactive shells. PATH additions in bashrc don't apply to non-interactive contexts.
**How to avoid:** For the current use case this is fine -- users run `cc-tmux` from interactive terminals. The bashrc-hook.sh also runs in interactive context (SSH login). If future phases add systemd integration, use full paths.
**Warning signs:** `command not found: cc-tmux` in automated contexts.

### Pitfall 5: Window Name Collision on Project Add
**What goes wrong:** User adds a project with a name that matches an existing window, `tmux new-window -n` silently creates a duplicate name.
**Why it happens:** tmux allows duplicate window names; it uses window index internally.
**How to avoid:** `add_project()` already checks for duplicate names in projects.conf. The live tmux `kill-window -t "$session:$name"` targets by name, which kills the first match if duplicates exist. Keep the config-level dedup as the source of truth.
**Warning signs:** Multiple windows with the same name appearing.

### Pitfall 6: Quoting Windows Paths with Spaces
**What goes wrong:** Project paths like `/mnt/c/Users/Ben/Trading dev` break if not quoted.
**Why it happens:** Bash word splitting on unquoted variables.
**How to avoid:** Always double-quote `"$path"` in tmux commands: `tmux new-window -c "$path"`. The existing `add_project()` stores paths with the pipe delimiter, and `IFS='|' read -r name path` correctly handles spaces in paths.
**Warning signs:** tmux windows opening in wrong directory or failing to create.

## Code Examples

### tmux.conf.tpl (Full Template)
```bash
# Source: V1/tmux.conf adapted with __USERNAME__ placeholder and mobile hook
# ============================================
# CC x TMUX -- tmux configuration
# Auto-generated from template. Do not hand-edit.
# ============================================

# --- Mouse support ---
set -g mouse on

# --- Quality of life ---
set -g history-limit 50000
set -g display-time 3000
set -g status-interval 5
set -g default-terminal "tmux-256color"
set -g focus-events on
set -s escape-time 0

# --- Window numbering ---
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# --- Status bar (Catppuccin-inspired) ---
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left "#[bg=#89b4fa,fg=#1e1e2e,bold]  #S "
set -g status-left-length 30
set -g status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + #[default] #[fg=#a6adc8]%H:%M  %d-%b "
set -g status-right-length 30

# --- Tab styling ---
setw -g window-status-format " #I:#W "
setw -g window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold] #I:#W "
setw -g window-status-separator ""

# --- Keybindings ---
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind R source-file ~/.tmux.conf \; display-message "Config reloaded"
bind c new-window -c "#{pane_current_path}"
bind -n M-Left previous-window
bind -n M-Right next-window

# --- Clickable + button ---
bind -n MouseDown1StatusRight new-window -c "/mnt/c/Users/__USERNAME__/Documents" \; send-keys "powershell.exe" Enter

# --- Mobile auto-detect on attach ---
set-hook -g client-attached 'run-shell "~/.cc-tmux/templates/mobile-check.sh"'

# --- Mobile mode toggle (Ctrl+B, Shift+M) ---
bind M set status-left "" \; set status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + " \; set status-right-length 5 \; setw window-status-format "#[bg=#45475a,fg=#cdd6f4]  #I: #W  " \; setw window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold]  #I: #W  " \; setw window-status-separator " " \; display-message "Mobile mode"

# --- Desktop mode toggle (Ctrl+B, Shift+N) ---
bind N source-file ~/.tmux.conf \; display-message "Desktop mode"
```

### mobile-check.sh (Auto-Detection Script)
```bash
#!/usr/bin/env bash
# Mobile auto-detection for tmux
# Called by set-hook client-attached in tmux.conf

WIDTH=$(tmux display -p '#{client_width}')

if [ "$WIDTH" -lt 80 ]; then
    # Mobile mode: minimal status bar, larger tap targets
    tmux set status-left "" \; \
         set status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + " \; \
         set status-right-length 5 \; \
         setw window-status-format "#[bg=#45475a,fg=#cdd6f4]  #I: #W  " \; \
         setw window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold]  #I: #W  " \; \
         setw window-status-separator " " \; \
         display-message "Mobile mode"
fi
# If width >= 80, do nothing -- desktop is the default from tmux.conf
```

### bin/cc-tmux Subcommand Router
```bash
#!/usr/bin/env bash
set -euo pipefail

CC_TMUX_DIR="$HOME/.cc-tmux"

# Source libraries
source "$CC_TMUX_DIR/lib/common.sh"
source "$CC_TMUX_DIR/lib/config.sh"

show_usage() {
    echo "Usage: cc-tmux <command>"
    echo ""
    echo "Commands:"
    echo "  start              Start workspace (SSH + tunnel + tmux)"
    echo "  project add        Add a project tab"
    echo "  project remove     Remove a project tab"
    echo "  project list       List configured projects"
    echo "  tunnel             Show tunnel status"
    echo ""
}

case "${1:-}" in
    start)
        exec bash "$HOME/startup.sh"
        ;;
    project)
        source "$CC_TMUX_DIR/lib/workspace.sh"
        shift
        case "${1:-}" in
            add)
                shift
                # ... validate $1=name $2=path, call add_project + live window
                ;;
            remove)
                shift
                # ... validate $1=name, call remove_project + kill window
                ;;
            list)
                list_projects
                ;;
            *)
                echo "Usage: cc-tmux project {add|remove|list}"
                exit 1
                ;;
        esac
        ;;
    tunnel)
        source "$CC_TMUX_DIR/lib/tunnel/provider.sh"
        load_tunnel_provider && tunnel_status
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
```

## State of the Art

| Old Approach (V1) | Current Approach (V2) | When Changed | Impact |
|--------------------|-----------------------|--------------|--------|
| Hardcoded project list in workspace-init.sh | Config-driven from projects.conf | Phase 1 (config.sh) | No script editing to change projects |
| YOURUSERNAME placeholder in tmux.conf | __USERNAME__ in template, auto-substituted at install | Phase 1 (detect.sh) | Zero manual replacement |
| Manual `~/workspace-init.sh` then `~/attach.sh` | Single `cc-tmux start` or auto-attach via bashrc hook | Phase 4 | One command or zero commands (SSH auto-attach) |
| Manual Ctrl+B, Shift+M for mobile | Auto-detect on attach + manual override | Phase 4 | Phone users get mobile layout automatically |
| Separate tmux.conf file to copy manually | Template deployed by installer | Phase 4 | Install-once, works correctly |

**Deprecated/outdated:**
- V1's `workspace-init.sh` hardcoded PROJECTS array -- replaced by projects.conf
- V1's `attach.sh` as separate script -- replaced by bashrc-hook.sh and startup.sh
- Manual username replacement in tmux.conf -- replaced by template substitution

## Open Questions

1. **Should workspace_init wait between window creation?**
   - What we know: V1 does NOT sleep between `new-window` and `send-keys`. tmux buffers keystrokes for windows that haven't finished initializing their shell.
   - What's unclear: Whether this is reliable on very slow machines or when creating many windows (10+).
   - Recommendation: Don't sleep. V1 proves it works. If issues arise, add `sleep 0.1` as a future fix. This is Claude's discretion per CONTEXT.md.

2. **Should cc-tmux have a `stop` command?**
   - What we know: Users can `tmux kill-session -t work` and `tunnel_stop` manually.
   - What's unclear: Whether non-technical users would benefit from `cc-tmux stop` as a convenience.
   - Recommendation: Add it -- it's trivial (kill session + stop tunnel) and matches the `start` command symmetry. This is Claude's discretion per CONTEXT.md.

3. **Tab completion for cc-tmux?**
   - What we know: Bash completion scripts use `complete -W` or `_complete` functions.
   - What's unclear: Whether this is worth the complexity for 3 top-level commands.
   - Recommendation: Skip for Phase 4. Only 6 total commands; users can use `cc-tmux help`. Add in Phase 5 (robustness) if desired. This is Claude's discretion per CONTEXT.md.

4. **Mobile-check.sh and the desktop reload question**
   - What we know: When client_width >= 80, the auto-detect script does nothing (desktop is the tmux.conf default). But if a user manually toggled to mobile mode and then resizes their terminal wider, the auto-detect only fires on `client-attached`, not on resize.
   - What's unclear: Whether users will expect the layout to auto-switch when they resize their terminal (not just when attaching).
   - Recommendation: Keep `client-attached` only. Adding `client-resized` would cause constant re-evaluation on every terminal resize, which could be disruptive. Manual Ctrl+B,N handles the edge case.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash + tmux scripting (manual verification) |
| Config file | none -- shell scripts tested by execution |
| Quick run command | `tmux has-session -t work && echo "Session exists"` |
| Full suite command | `bash install.sh --yes && bash startup.sh` (end-to-end) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WRK-01 | Workspace creates project tabs from config | smoke | `bash -c 'source lib/workspace.sh; workspace_init' && tmux list-windows -t work` | No -- Wave 0 |
| WRK-02 | CLI add/remove/list projects | smoke | `cc-tmux project list` | No -- Wave 0 |
| WRK-03 | Session persists after terminal close | manual-only | Close terminal, reopen, check `tmux has-session -t work` | N/A (manual) |
| WRK-04 | Reattach from any terminal | manual-only | SSH from phone, verify same session | N/A (manual) |
| WRK-05 | Mouse support, clickable tabs, keybindings | manual-only | Visual inspection of tmux behavior | N/A (manual) |
| MOB-01 | Auto-detect narrow terminal on attach | manual-only | Resize terminal < 80 cols, detach, reattach, verify mobile mode | N/A (manual) |
| MOB-02 | Mobile mode has larger tap targets | manual-only | Visual inspection on narrow terminal | N/A (manual) |
| MOB-03 | Manual toggle via keybinding | manual-only | Press Ctrl+B,M then Ctrl+B,N, verify display messages | N/A (manual) |

### Sampling Rate
- **Per task commit:** `tmux has-session -t work && tmux list-windows -t work -F '#{window_name}'`
- **Per wave merge:** Full startup flow: `bash install.sh --yes && bash ~/startup.sh` (in test environment)
- **Phase gate:** All 8 requirements verified via smoke tests and manual checks

### Wave 0 Gaps
- [ ] `lib/workspace.sh` -- new file, covers WRK-01
- [ ] `templates/tmux.conf.tpl` -- new file, covers WRK-05, MOB-01, MOB-02, MOB-03
- [ ] `templates/mobile-check.sh` -- new file, covers MOB-01
- [ ] `bin/cc-tmux` -- new file, covers WRK-02

*(All files are new creations in this phase -- no existing test infrastructure to leverage)*

## Sources

### Primary (HIGH confidence)
- V1/tmux.conf -- Catppuccin theme, keybindings, mobile toggle (direct file read)
- V1/workspace-init.sh -- Project loop, new-session/new-window/send-keys pattern (direct file read)
- V1/attach.sh -- Create-or-attach logic (direct file read)
- lib/config.sh -- add_project, remove_project, list_projects, project_count (direct file read)
- startup.sh -- Current startup flow with Phase 3 tunnel integration (direct file read)
- [tmux Formats wiki](https://github.com/tmux/tmux/wiki/Formats) -- `client_width` format variable, conditional `#{?}` syntax
- [tmux man page](https://man7.org/linux/man-pages/man1/tmux.1.html) -- set-hook, client-attached, run-shell, if-shell

### Secondary (MEDIUM confidence)
- [Responsive tmux status bar (Coderwall)](https://coderwall.com/p/trgyrq/make-your-tmux-status-bar-responsive) -- `tmux display -p '#{client_width}'` technique for responsive layouts
- [tmux hooks guide (devel.tech)](https://devel.tech/tips/n/tMuXz2lj/the-power-of-tmux-hooks/) -- client-attached, client-resized, session-created hook examples
- [tmux hooks issue #1083](https://github.com/tmux/tmux/issues/1083) -- Complete hook list reference

### Tertiary (LOW confidence)
- None -- all findings verified against official tmux documentation or direct codebase inspection

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- tmux and bash are already dependencies; no new tools needed
- Architecture: HIGH -- all patterns directly derived from V1 reference code and existing lib/ modules
- Pitfalls: HIGH -- identified from V1 experience and established tmux scripting patterns
- Mobile detection: MEDIUM -- tmux hooks are well-documented, but real-device testing with Termius needed to confirm width thresholds

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable domain, tmux API rarely changes)
