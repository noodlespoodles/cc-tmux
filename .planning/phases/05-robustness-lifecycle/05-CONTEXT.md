# Phase 5: Robustness & Lifecycle - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Add input validation, error handling, graceful degradation, health diagnostics (`cc-tmux doctor`), self-update (`cc-tmux update`), and clean uninstall (`cc-tmux uninstall`) across all existing scripts. This is a hardening and lifecycle phase — no new features, just making everything bulletproof and adding management commands.

Requirements: ROB-01, ROB-02, ROB-03, ROB-05, INST-07

</domain>

<decisions>
## Implementation Decisions

### Doctor Diagnostics (cc-tmux doctor)
- Check these components: WSL environment, tmux installed, SSH service running, sshd config valid, SSH keys exist, fail2ban active, ngrok installed and configured, tunnel provider files deployed, config.env exists, projects.conf valid, ~/.cc-tmux/ directory structure
- Output: color-coded pass/fail checklist (green ✓ / red ✗) with fix suggestion for each failure
- Diagnose only — do NOT attempt auto-fix (suggest commands instead)
- Exit code: 0 if all pass, 1 if any fail
- Add as `cc-tmux doctor` subcommand in bin/cc-tmux

### Self-Update (cc-tmux update)
- Mechanism: `git pull` from origin in the repo clone directory, then re-run deploy step
- Version check: compare local `git rev-parse HEAD` with `git ls-remote origin HEAD`
- Only runs on explicit `cc-tmux update` — no auto-check on startup
- If local modifications exist: warn about uncommitted changes, offer to stash or abort
- After pull: re-run `step_deploy` to copy updated files to `~/.cc-tmux/`
- Store repo clone path in config.env as `CC_TMUX_REPO` during install

### Uninstall (cc-tmux uninstall)
- Show what will be removed, require explicit "yes" confirmation (or `--yes` flag)
- Remove: `~/.cc-tmux/` directory, bashrc hooks (sentinel-based removal), sudoers file, sshd drop-in, fail2ban jail config
- Do NOT remove system packages (tmux, ngrok, fail2ban, openssh-server) — may be used by other things
- Before removal: stop tunnel (tunnel_stop), kill tmux session, remove fail2ban jail
- Desktop shortcut removal deferred to Phase 6 (INST-08) — uninstall handles server-side only
- Add as `cc-tmux uninstall` subcommand

### Error Handling Patterns
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing codebase
- `bin/cc-tmux` — CLI entry point to extend with doctor/update/uninstall subcommands
- `lib/common.sh` — Logging functions, install_package, add_bashrc_block (sentinel pattern for removal)
- `lib/config.sh` — Config read/write, CC_TMUX_DIR constant
- `lib/setup.sh` — step_deploy (re-run for update), step_verify (reference for doctor checks)
- `lib/deps.sh` — Package checks (reference for doctor)
- `lib/ssh-hardening.sh` — SSH security functions (reference for doctor)
- `lib/tunnel/provider.sh` — Tunnel interface (reference for doctor)
- `install.sh` — Full installer flow (reference for uninstall reversal)
- `startup.sh` — Entry point (graceful degradation target)

### Project
- `.planning/PROJECT.md` — Core value, constraints
- `.planning/REQUIREMENTS.md` — ROB-01 through ROB-03, ROB-05, INST-07

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/setup.sh:step_verify()` — Already has 12+ verification checks that can inform doctor diagnostics
- `lib/common.sh:add_bashrc_block()` — Uses sentinel markers (`# BEGIN cc-tmux` / `# END cc-tmux`) for clean removal
- `lib/setup.sh:step_deploy()` — Re-usable for update's re-deploy step
- `lib/config.sh:read_config()` — Can read CC_TMUX_REPO path
- `bin/cc-tmux` — Already has case-statement routing for subcommands

### Established Patterns
- Color-coded output via lib/common.sh (log_ok, log_error, log_warn, log_hint)
- Sentinel-based bashrc blocks for idempotent add/remove
- Sudoers at `/etc/sudoers.d/cc-tmux` — simple `sudo rm`
- sshd drop-in at `/etc/ssh/sshd_config.d/00-cc-tmux.conf` — simple `sudo rm`
- fail2ban jail at `/etc/fail2ban/jail.d/cc-tmux.conf` — simple `sudo rm`

### Integration Points
- `bin/cc-tmux` — New subcommands: doctor, update, uninstall
- `~/.cc-tmux/config.env` — Needs CC_TMUX_REPO added during install
- `~/.cc-tmux/error.log` — New error log file
- `install.sh` — Needs to record repo path in config.env

</code_context>

<specifics>
## Specific Ideas

- Doctor should feel like `brew doctor` or `docker info` — quick, clear, actionable
- Uninstall must be thorough — user said "ease of install" matters, and that includes clean removal
- Error messages should be helpful to non-technical users — not just "file not found" but "Project path '/foo' doesn't exist. Check the path and try again."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-robustness-lifecycle*
*Context gathered: 2026-03-20*
