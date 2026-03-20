# Phase 5: Robustness & Lifecycle - Research

**Researched:** 2026-03-20
**Domain:** Bash error handling, CLI diagnostics, self-update, clean uninstall
**Confidence:** HIGH

## Summary

Phase 5 hardens every existing script with consistent error handling and adds three new CLI subcommands: `doctor` (diagnostics), `update` (self-update via git), and `uninstall` (clean removal). The codebase is pure Bash targeting WSL2 Ubuntu, so there are no external frameworks -- just well-established shell patterns.

The existing code already has good foundations: `set -euo pipefail` in entry points, color-coded logging in `lib/common.sh`, sentinel-marked bashrc blocks for clean add/remove, and a comprehensive `step_verify()` function with 15 checks that can be directly adapted for the doctor command. The main work is (a) adding a `remove_bashrc_block()` counterpart to the existing `add_bashrc_block()`, (b) building a doctor command that reuses verification logic with fix suggestions, (c) implementing git-based self-update, and (d) writing an uninstall that reverses `install.sh` step by step.

**Primary recommendation:** Build doctor/update/uninstall as separate library files (`lib/doctor.sh`, `lib/update.sh`, `lib/uninstall.sh`) sourced lazily by `bin/cc-tmux`, following the established pattern of lazy loading used for `workspace.sh` and `tunnel/provider.sh`.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Doctor Diagnostics (cc-tmux doctor):**
- Check these components: WSL environment, tmux installed, SSH service running, sshd config valid, SSH keys exist, fail2ban active, ngrok installed and configured, tunnel provider files deployed, config.env exists, projects.conf valid, ~/.cc-tmux/ directory structure
- Output: color-coded pass/fail checklist (green checkmark / red X) with fix suggestion for each failure
- Diagnose only -- do NOT attempt auto-fix (suggest commands instead)
- Exit code: 0 if all pass, 1 if any fail
- Add as `cc-tmux doctor` subcommand in bin/cc-tmux

**Self-Update (cc-tmux update):**
- Mechanism: `git pull` from origin in the repo clone directory, then re-run deploy step
- Version check: compare local `git rev-parse HEAD` with `git ls-remote origin HEAD`
- Only runs on explicit `cc-tmux update` -- no auto-check on startup
- If local modifications exist: warn about uncommitted changes, offer to stash or abort
- After pull: re-run `step_deploy` to copy updated files to `~/.cc-tmux/`
- Store repo clone path in config.env as `CC_TMUX_REPO` during install

**Uninstall (cc-tmux uninstall):**
- Show what will be removed, require explicit "yes" confirmation (or `--yes` flag)
- Remove: `~/.cc-tmux/` directory, bashrc hooks (sentinel-based removal), sudoers file, sshd drop-in, fail2ban jail config
- Do NOT remove system packages (tmux, ngrok, fail2ban, openssh-server) -- may be used by other things
- Before removal: stop tunnel (tunnel_stop), kill tmux session, remove fail2ban jail
- Desktop shortcut removal deferred to Phase 6 (INST-08) -- uninstall handles server-side only
- Add as `cc-tmux uninstall` subcommand

**Error Handling Patterns:**
- All scripts: `set -e -o pipefail` at top (set -u already in use from Phase 1)
- Invalid inputs: specific error message + usage hint for the current command
- bin/cc-tmux: validate subcommand exists, validate required arguments (e.g., project add needs name + path)
- Graceful degradation: core functions (workspace, attach) work offline; tunnel and update degrade with warnings
- Errors output to stderr AND appended to `~/.cc-tmux/error.log` with timestamps
- Path validation: check paths exist before adding projects, check files exist before sourcing

### Claude's Discretion

- Whether to add a `cc-tmux version` command (trivial, nice to have)
- Error log rotation strategy (simple truncation vs proper rotation)
- Whether doctor should check ngrok auth token validity (requires network)
- Whether update should backup config.env before overwriting

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ROB-01 | All scripts validate inputs and provide clear error messages for invalid paths/values | Error handling patterns section: `trap ERR` handler with `log_error_to_file()`, input validation patterns for cc-tmux subcommands, path existence checks |
| ROB-02 | Scripts handle edge cases gracefully (missing dependencies, network failures, WSL quirks) | Graceful degradation patterns: offline-safe core commands, try/warn/continue for network-dependent features, guard functions for optional deps |
| ROB-03 | Health check command (`cc-tmux doctor`) diagnoses common issues with pass/fail per component | Doctor implementation section: reuse step_verify() checks, add fix suggestions, modular check functions, exit code logic |
| ROB-05 | Self-update mechanism checks for new versions and applies updates via `cc-tmux update` | Update implementation section: git rev-parse comparison, stash/abort for dirty repos, re-run step_deploy after pull |
| INST-07 | User can uninstall cleanly with a single command that reverses all changes | Uninstall implementation section: sentinel-based bashrc removal via sed, sudo rm for system configs, confirmation prompt, ordered teardown |

</phase_requirements>

## Standard Stack

### Core

This phase introduces no new external dependencies. Everything is pure Bash using tools already available in the WSL2 Ubuntu environment.

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 5.x (already required) | All scripts | Project requires bash 5+ (checked in install.sh preflight) |
| git | system | Version comparison and self-update | Already installed in WSL2, used for CC_TMUX_REPO management |
| sed | GNU sed (system) | Bashrc sentinel block removal | Already used in config.sh and setup.sh |
| grep | GNU grep (system) | Pattern matching for sentinel blocks | Already used throughout codebase |

### Supporting

No new supporting packages are needed. All diagnostic checks use tools already installed by Phases 1-4 (`tmux`, `ssh`, `ngrok`, `fail2ban-client`, `jq`, `curl`).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| git pull for updates | GitHub API release check | Git pull is simpler, no API token needed, user already has the repo cloned |
| sed for bashrc removal | awk (like add_bashrc_block uses) | sed `/START/,/END/d` is more readable for deletion; awk is used for replacement in add_bashrc_block but sed is cleaner for pure deletion |

## Architecture Patterns

### New Files

```
lib/
  doctor.sh          # Diagnostic checks, sourced lazily by cc-tmux doctor
  update.sh          # Self-update logic, sourced lazily by cc-tmux update
  uninstall.sh       # Clean removal logic, sourced lazily by cc-tmux uninstall
```

No new directories. No new templates. The three new files follow the existing `lib/*.sh` pattern.

### Pattern 1: Lazy Library Loading (Established)

**What:** Source library files only in the case branch that needs them, not at the top of `bin/cc-tmux`.
**When to use:** For every new subcommand (doctor, update, uninstall).
**Why:** Already established in Phase 4 -- `workspace.sh` and `tunnel/provider.sh` are only sourced in the `project` and `tunnel` branches respectively.

```bash
# In bin/cc-tmux case statement
doctor)
    source "$CC_TMUX_DIR/lib/doctor.sh"
    run_doctor
    ;;

update)
    source "$CC_TMUX_DIR/lib/update.sh"
    run_update "$@"
    ;;

uninstall)
    source "$CC_TMUX_DIR/lib/uninstall.sh"
    run_uninstall "$@"
    ;;
```

### Pattern 2: Modular Check Functions for Doctor

**What:** Each diagnostic check is a standalone function returning 0/1 with a standard output format.
**When to use:** Doctor command implementation.
**Why:** Makes it easy to add/remove checks, and each check is independently testable.

```bash
check_tmux() {
    if command -v tmux &>/dev/null; then
        log_check_pass "tmux installed ($(tmux -V 2>/dev/null || echo 'unknown'))"
        return 0
    else
        log_check_fail "tmux not found"
        log_hint "Fix: sudo apt install tmux"
        return 1
    fi
}
```

The doctor runner calls each check function and tallies pass/fail:

```bash
run_doctor() {
    local pass=0 fail=0

    echo ""
    echo "${BOLD}CC-TMUX Health Check${RESET}"
    echo ""

    check_wsl         && ((pass++)) || ((fail++))
    check_tmux        && ((pass++)) || ((fail++))
    check_ssh_service && ((pass++)) || ((fail++))
    # ... more checks ...

    echo ""
    echo "  Results: ${GREEN}$pass passed${RESET}, ${RED}$fail failed${RESET}"

    [[ $fail -eq 0 ]]  # Exit code: 0 if all pass, 1 if any fail
}
```

### Pattern 3: Sentinel Block Removal

**What:** A `remove_bashrc_block()` function that mirrors `add_bashrc_block()` using sed to delete between sentinel markers.
**When to use:** Uninstall command.
**Why:** The add function already uses `# CC-TMUX:${name}:START` / `# CC-TMUX:${name}:END` sentinels. Removal is the inverse operation.

```bash
remove_bashrc_block() {
    local name="$1"
    local bashrc="$HOME/.bashrc"
    local start_marker="# CC-TMUX:${name}:START"
    local end_marker="# CC-TMUX:${name}:END"

    if grep -qF "$start_marker" "$bashrc" 2>/dev/null; then
        sed -i "/$start_marker/,/$end_marker/d" "$bashrc"
        log_ok "bashrc block '$name' removed"
    else
        log_warn "bashrc block '$name' not found (already removed?)"
    fi
}
```

### Pattern 4: Error Logging to File

**What:** A wrapper function that logs errors to both stderr and `~/.cc-tmux/error.log` with timestamps.
**When to use:** Throughout all scripts where `log_error` is currently used.
**Why:** User decision requires errors output to stderr AND appended to error.log.

```bash
log_error() {
    local msg="$*"
    echo "  ${RED}[error]${RESET} $msg" >&2
    # Append to error log with timestamp
    local log_file="$HOME/.cc-tmux/error.log"
    if [[ -d "$HOME/.cc-tmux" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$log_file"
    fi
}
```

### Pattern 5: Confirmation Prompt with --yes Bypass

**What:** Standard confirmation pattern used by uninstall.
**When to use:** Destructive operations (uninstall).
**Why:** Mirrors the `--yes` flag pattern already used in `install.sh`.

```bash
run_uninstall() {
    local force=false
    if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
        force=true
    fi

    # Show what will be removed
    echo "The following will be removed:"
    echo "  - ~/.cc-tmux/ directory"
    echo "  - bashrc hooks (auto-attach, path)"
    echo "  - /etc/sudoers.d/cc-tmux"
    echo "  - /etc/ssh/sshd_config.d/00-cc-tmux.conf"
    echo "  - /etc/fail2ban/jail.d/cc-tmux.conf"
    echo ""

    if [[ "$force" != true ]]; then
        read -rp "  Type 'yes' to confirm: " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "  Aborted."
            return 0
        fi
    fi

    # Proceed with removal...
}
```

### Anti-Patterns to Avoid

- **Auto-fix in doctor:** Doctor diagnoses only. Suggesting commands is fine; running `apt install` or modifying configs is not. This is a locked user decision.
- **Removing system packages in uninstall:** tmux, ngrok, fail2ban, openssh-server must NOT be removed. They may be used by other things. Only cc-tmux-specific files are removed.
- **Global trap ERR in library files:** The `trap` command should only be set in entry-point scripts (`bin/cc-tmux`, `install.sh`, `startup.sh`), not in library files that are sourced. Setting traps in libraries can interfere with the caller's error handling.
- **Using `set -e` in library files:** Library files should NOT include `set -euo pipefail` -- that belongs in the entry script only. Libraries already follow this convention (see `lib/common.sh` header comment).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bashrc block removal | Custom regex parser | `sed -i '/MARKER_START/,/MARKER_END/d'` | Sed's range addressing handles this in one line; custom parsers get edge cases wrong (empty lines, special chars) |
| Version comparison | String comparison of git hashes | `git rev-parse HEAD` vs `git ls-remote origin HEAD` | Git provides exact commit comparison; no need to parse version strings |
| Dirty repo detection | Manual file diffing | `git status --porcelain` | Git status is authoritative; returns empty string when clean |
| Service status checking | Parsing ps output | `service ssh status`, `fail2ban-client status sshd` | Service management commands return proper exit codes |
| Error log rotation | logrotate config or custom rotation | Simple truncation: `tail -n 1000 error.log > error.log.tmp && mv ...` | Same pattern already used for tunnel.log watchdog (tail -n 500). No need for logrotate complexity for a single-user CLI tool |

**Key insight:** Every "hard problem" in this phase already has a well-tested pattern somewhere in the existing codebase or standard Unix tools. The doctor is a restructured `step_verify()`, the update is `git pull` + `step_deploy()`, and the uninstall is `install.sh` in reverse with `sed` for sentinel removal.

## Common Pitfalls

### Pitfall 1: sed Special Characters in Sentinel Markers

**What goes wrong:** If sentinel markers contain characters special to sed regex (`/`, `.`, `*`), the sed deletion command breaks.
**Why it happens:** The existing markers use `# CC-TMUX:name:START` which contains no special chars, but a future block name with `/` or `.` would break `sed "/$start_marker/,/$end_marker/d"`.
**How to avoid:** Use `grep -F` (fixed string) for detection (already done) and `sed` with escaped markers or alternative delimiters. Since existing block names are `auto-attach` and `path` (no special chars), this is safe now but worth noting.
**Warning signs:** sed errors during uninstall.

### Pitfall 2: CC_TMUX_REPO Path Not Set in Older Installs

**What goes wrong:** Users who installed before Phase 5 won't have `CC_TMUX_REPO` in their config.env. Running `cc-tmux update` would fail with a missing config error.
**Why it happens:** Phase 5 adds `CC_TMUX_REPO` to config.env during install, but existing installs predate this.
**How to avoid:** The update command must handle the missing `CC_TMUX_REPO` case gracefully -- either prompt the user for the repo path, or attempt to detect it (e.g., check if the script's own path resolves to a git repo).
**Warning signs:** `get_config "CC_TMUX_REPO"` returns empty.

### Pitfall 3: Uninstall Running from ~/.cc-tmux/bin/cc-tmux

**What goes wrong:** The uninstall command runs from `~/.cc-tmux/bin/cc-tmux`, but it deletes `~/.cc-tmux/`. This means the running script deletes itself mid-execution.
**Why it happens:** Bash reads scripts line by line from disk, so deleting the directory while the script is running can cause errors on some systems.
**How to avoid:** Load the entire uninstall logic into memory before deleting files. Since `lib/uninstall.sh` is `source`d at the start of the case branch, all functions are already in memory. The key is to ensure the `rm -rf` of `~/.cc-tmux/` happens as one of the final operations, and no further file reads from that directory occur after deletion.
**Warning signs:** "No such file or directory" errors during uninstall.

### Pitfall 4: Stale Sudo Credentials During Uninstall

**What goes wrong:** Uninstall needs `sudo` to remove `/etc/sudoers.d/cc-tmux`, `/etc/ssh/sshd_config.d/00-cc-tmux.conf`, and `/etc/fail2ban/jail.d/cc-tmux.conf`. If sudo times out between prompts, the user gets interrupted.
**How to avoid:** Do all sudo operations together at the beginning of the uninstall sequence, before removing `~/.cc-tmux/` and bashrc blocks (which don't need sudo).
**Warning signs:** Partial uninstall -- user files removed but system configs remain.

### Pitfall 5: Error Log Grows Without Bound

**What goes wrong:** Every error appended to `error.log` means the file grows indefinitely for long-running installations.
**Why it happens:** No rotation or truncation mechanism.
**How to avoid:** Truncate error.log to last N lines (e.g., 500) at the start of each `cc-tmux` invocation, or during doctor. Same pattern as the tunnel watchdog log.
**Warning signs:** error.log grows to megabytes over months.

### Pitfall 6: git ls-remote Hangs on Network Failure

**What goes wrong:** `cc-tmux update` runs `git ls-remote origin HEAD` to check for updates. If the network is down, this hangs for 30+ seconds.
**Why it happens:** Git's default network timeout is long.
**How to avoid:** Wrap in a timeout: `timeout 10 git ls-remote origin HEAD 2>/dev/null`. If it times out, inform user that version check failed due to network and suggest trying again later.
**Warning signs:** Update command appears to hang.

## Code Examples

Verified patterns from the existing codebase:

### Doctor Check: SSH Service Running

```bash
check_ssh_service() {
    if sudo -n service ssh status &>/dev/null; then
        log_check_pass "SSH service running"
        return 0
    else
        log_check_fail "SSH service not running"
        log_hint "Fix: sudo service ssh start"
        return 1
    fi
}
```

### Update: Git Version Comparison

```bash
check_for_updates() {
    local repo_dir="$1"

    if [[ ! -d "$repo_dir/.git" ]]; then
        log_error "Not a git repository: $repo_dir"
        return 1
    fi

    local local_head remote_head
    local_head=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)
    remote_head=$(timeout 10 git -C "$repo_dir" ls-remote origin HEAD 2>/dev/null | cut -f1)

    if [[ -z "$remote_head" ]]; then
        log_warn "Could not reach remote -- check your internet connection"
        return 1
    fi

    if [[ "$local_head" == "$remote_head" ]]; then
        log_ok "Already up to date"
        return 0
    else
        log_warn "Update available"
        echo "  Local:  ${local_head:0:8}"
        echo "  Remote: ${remote_head:0:8}"
        return 2  # Signal: update available
    fi
}
```

### Update: Dirty Repo Detection and Stash

```bash
handle_dirty_repo() {
    local repo_dir="$1"

    if [[ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]]; then
        log_warn "Uncommitted changes detected in $repo_dir"
        echo ""
        echo "  Options:"
        echo "    1. Stash changes and continue (git stash)"
        echo "    2. Abort update"
        echo ""
        read -rp "  Choice [1/2]: " choice
        case "$choice" in
            1)
                git -C "$repo_dir" stash
                log_ok "Changes stashed"
                return 0  # Continue
                ;;
            *)
                echo "  Update aborted."
                return 1  # Abort
                ;;
        esac
    fi
    return 0  # Clean -- continue
}
```

### Uninstall: Ordered Teardown

```bash
run_uninstall() {
    # Phase 1: Stop running services (needs ~/.cc-tmux files)
    log_warn "Stopping workspace..."
    local session_name
    session_name=$(get_config "SESSION_NAME" 2>/dev/null) || session_name="work"

    # Stop tunnel
    if [[ -f "$CC_TMUX_DIR/lib/tunnel/provider.sh" ]]; then
        source "$CC_TMUX_DIR/lib/tunnel/provider.sh"
        if load_tunnel_provider 2>/dev/null; then
            tunnel_stop 2>/dev/null || true
        fi
    fi

    # Kill tmux session
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # Phase 2: Remove system configs (requires sudo -- do together)
    log_warn "Removing system configurations..."
    sudo rm -f /etc/sudoers.d/cc-tmux
    sudo rm -f /etc/ssh/sshd_config.d/00-cc-tmux.conf
    sudo rm -f /etc/fail2ban/jail.d/cc-tmux.conf
    sudo service ssh restart 2>/dev/null || true
    sudo service fail2ban restart 2>/dev/null || true

    # Phase 3: Remove bashrc blocks (no sudo needed)
    log_warn "Removing bashrc hooks..."
    remove_bashrc_block "auto-attach"
    remove_bashrc_block "path"

    # Phase 4: Remove tmux.conf
    rm -f "$HOME/.tmux.conf"
    rm -f "$HOME/startup.sh"

    # Phase 5: Remove ~/.cc-tmux/ (LAST -- we were sourcing from here)
    log_warn "Removing ~/.cc-tmux/..."
    rm -rf "$CC_TMUX_DIR"

    log_ok "cc-tmux has been uninstalled"
    echo ""
    echo "  System packages (tmux, ngrok, fail2ban, openssh-server)"
    echo "  were NOT removed. Uninstall them manually if desired."
    echo ""
}
```

### Graceful Degradation: Offline-Safe Commands

```bash
# In startup.sh -- tunnel failure is non-blocking (already implemented)
if load_tunnel_provider; then
    if tunnel_start; then
        tunnel_available=true
    else
        log_warn "Tunnel failed to start -- workspace will run locally"
    fi
fi

# Same pattern for update: network failure is informational
update)
    source "$CC_TMUX_DIR/lib/update.sh"
    run_update || {
        log_warn "Update check failed -- you can try again later"
    }
    ;;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `set -e` only | `set -euo pipefail` | Bash 4.4+ | Catches pipeline failures and unset variables |
| Manual error checking | `trap 'handler' ERR` | Long established | Centralized error reporting with line numbers |
| No error logging | Append to file with timestamps | Standard practice | Post-mortem debugging for user support |
| Ad-hoc health checks | Modular check functions with pass/fail | brew doctor pattern | Extensible, consistent output |

**Deprecated/outdated:**
- `set -e` alone without `-o pipefail`: Misses errors in piped commands. Already using pipefail in entry points.
- `set -u` without proper `${var:-}` defaults: Causes immediate exit on unset vars. The codebase already handles this correctly with `${1:-}` patterns.

## Discretion Recommendations

### cc-tmux version -- RECOMMEND YES

Add a `version` subcommand. It costs ~5 lines of code, is trivially implemented by reading `CC_TMUX_VERSION` from config.env, and helps with debugging/support. Also useful for update to display "current version" vs "available version."

```bash
version)
    local ver
    ver=$(get_config "CC_TMUX_VERSION" 2>/dev/null) || ver="unknown"
    echo "cc-tmux $ver"
    ;;
```

### Error log rotation -- RECOMMEND SIMPLE TRUNCATION

Use the same pattern as `tunnel.log` in the watchdog: `tail -n 1000 error.log > error.log.tmp && mv error.log.tmp error.log`. Run this at the start of any `cc-tmux` invocation when the log exceeds a threshold (e.g., 5000 lines). No logrotate config, no cron -- keep it self-contained.

### Doctor ngrok auth check -- RECOMMEND YES WITH TIMEOUT

Check `ngrok config check` (which is local, no network) to verify the auth token is configured. Do NOT validate the token against ngrok's API (that requires network and adds latency). The local check catches the most common issue (user forgot to set up token).

### Update backup config.env -- RECOMMEND YES

Before `step_deploy` overwrites files, copy `config.env` to `config.env.bak`. This is a one-line `cp` command and protects against data loss if the update introduces a breaking config change. `projects.conf` should also be backed up.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bats-core (Bash Automated Testing System) |
| Config file | none -- see Wave 0 |
| Quick run command | `bats tests/` |
| Full suite command | `bats tests/` |

**Note:** No test infrastructure currently exists in this project. bats-core is the standard testing framework for Bash scripts. However, given this project's pattern of manual verification via `step_verify()` and the fact that all prior phases shipped without automated tests, the practical approach is to rely on the doctor command itself as the primary validation tool, supplemented by manual smoke tests.

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ROB-01 | Invalid inputs produce clear error messages | manual | Run `cc-tmux project add` with missing args, invalid paths | N/A |
| ROB-02 | Scripts degrade gracefully when deps missing or network down | manual | Disconnect network, run `cc-tmux start`, verify local-only mode | N/A |
| ROB-03 | `cc-tmux doctor` produces pass/fail checklist | smoke | `cc-tmux doctor; echo $?` | Wave 0 |
| ROB-05 | `cc-tmux update` checks for and applies updates | smoke | `cc-tmux update` (verify output format) | Wave 0 |
| INST-07 | `cc-tmux uninstall` reverses all installer changes | manual | Run uninstall, verify all artifacts removed | N/A |

### Sampling Rate

- **Per task commit:** Manual smoke test of the specific command added/modified
- **Per wave merge:** Run `cc-tmux doctor` to verify the installation is still healthy after changes
- **Phase gate:** Full manual walkthrough: doctor (all pass), update (version check), uninstall (clean removal), then reinstall to verify

### Wave 0 Gaps

- [ ] No test framework installed -- bats-core would need `npm install -g bats` or `sudo apt install bats`
- [ ] No test directory exists
- [ ] Given project conventions (no tests in 4 prior phases), recommend **manual verification** over adding test framework -- doctor command itself IS the validation tool for this phase

## Open Questions

1. **tmux.conf ownership during uninstall**
   - What we know: Uninstall should remove `~/.tmux.conf` since the installer deployed it
   - What's unclear: If the user has customized their tmux.conf beyond what the installer wrote, should we back it up or warn before deletion?
   - Recommendation: Remove it. The installer overwrites it on every install anyway. If we want to be extra safe, check if it contains "Managed by cc-tmux" comment and only delete if so; otherwise warn.

2. **Re-deploy step_deploy during update**
   - What we know: step_deploy uses `BASH_SOURCE[0]` to find the repo directory and copies files to ~/.cc-tmux/
   - What's unclear: When called from `cc-tmux update`, the running script is `~/.cc-tmux/bin/cc-tmux`, not the repo. step_deploy needs to be sourced from the repo, not the deployed copy.
   - Recommendation: After `git pull`, source `step_deploy` from the freshly-pulled repo directory (not from ~/.cc-tmux/lib/setup.sh). The update function should `source "$repo_dir/lib/common.sh"` and `source "$repo_dir/lib/setup.sh"` from the repo, then call `step_deploy`.

3. **install.sh already writes CC_TMUX_REPO**
   - What we know: Looking at install.sh line 174, `CC_TMUX_REPO "$SCRIPT_DIR"` is already written to config.env
   - What's unclear: Nothing -- this is already implemented
   - Recommendation: No additional work needed for storing repo path. Just read it with `get_config "CC_TMUX_REPO"` in the update command.

## Sources

### Primary (HIGH confidence)

- **Existing codebase** -- All patterns derived from reading the actual project files: bin/cc-tmux, lib/common.sh, lib/config.sh, lib/setup.sh, lib/deps.sh, lib/ssh-hardening.sh, lib/tunnel/provider.sh, lib/tunnel/ngrok.sh, lib/workspace.sh, install.sh, startup.sh, templates/bashrc-hook.sh
- **CONTEXT.md** -- All locked decisions from user discussion session

### Secondary (MEDIUM confidence)

- [Bash Error Handling with Trap](https://citizen428.net/blog/bash-error-handling-with-trap/) -- trap ERR patterns
- [3 Bash error-handling patterns](https://www.howtogeek.com/bash-error-handling-patterns-i-use-in-every-script/) -- set -euo pipefail best practices
- [Guide to Using sed to Remove Multi-Line Text Blocks](https://www.baeldung.com/linux/sed-remove-multi-line-text-blocks) -- sed range deletion for sentinel blocks
- [Delete Lines Between Two Patterns With Sed](https://techstop.github.io/delete-lines-strings-between-two-patterns-sed/) -- sed `/START/,/END/d` pattern
- [Homebrew Troubleshooting](https://docs.brew.sh/Troubleshooting) -- brew doctor as reference for diagnostic UX
- [oh-my-bash uninstall.sh](https://github.com/ohmybash/oh-my-bash/blob/master/tools/uninstall.sh) -- bashrc cleanup patterns from a mature project

### Tertiary (LOW confidence)

- None -- all findings verified against codebase or established bash patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- pure bash, no new dependencies, all patterns verified in existing codebase
- Architecture: HIGH -- follows established project conventions (lazy loading, modular lib files, sentinel markers)
- Pitfalls: HIGH -- derived from reading the actual code and identifying real edge cases (self-deleting uninstall, missing CC_TMUX_REPO, stale sudo)
- Code examples: HIGH -- adapted from existing codebase patterns with modifications for the new use cases

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable domain -- bash patterns don't change)
