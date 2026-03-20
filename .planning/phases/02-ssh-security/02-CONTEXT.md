# Phase 2: SSH & Security - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Harden the SSH configuration installed by Phase 1. Generate Ed25519 key pair, update sshd_config for key-only auth, configure fail2ban for brute-force protection, and display key import instructions for phone setup. Phase 1's `setup_ssh_config()` in lib/setup.sh currently enables both password and pubkey auth — this phase upgrades it to key-only with defense-in-depth.

Requirements: SEC-01, SEC-02, SEC-03, SEC-04

</domain>

<decisions>
## Implementation Decisions

### Key Management
- Generate Ed25519 key pair stored at `~/.cc-tmux/keys/cc-tmux_ed25519` and `.pub`
- Do NOT touch `~/.ssh/` — cc-tmux keys are self-contained
- If keys already exist at that path, skip generation (idempotent)
- After generation: print private key to terminal with clear Termius import instructions
- Also save key path to config.env (`CC_TMUX_SSH_KEY=~/.cc-tmux/keys/cc-tmux_ed25519`)
- Add the public key to `~/.ssh/authorized_keys` (create if needed, append if exists, skip if already present)

### SSH Hardening
- Override the existing `/etc/ssh/sshd_config.d/cc-tmux.conf` drop-in (Phase 1 created this)
- Hardened settings:
  - `PubkeyAuthentication yes`
  - `PasswordAuthentication no` (for remote connections)
  - `PermitRootLogin no`
  - `MaxAuthTries 3`
  - `LoginGraceTime 30`
  - `X11Forwarding no`
  - `AllowUsers {current_wsl_user}`
  - `Protocol 2` (if supported by OpenSSH version)
- Keep password auth available on localhost (`Match Address 127.0.0.1` block with `PasswordAuthentication yes`) as lockout safety net
- Don't touch the main `/etc/ssh/sshd_config` — only the cc-tmux drop-in

### fail2ban Configuration
- Create `/etc/fail2ban/jail.d/cc-tmux.conf` with SSH-specific jail
- Settings: `maxretry = 5`, `bantime = 600` (10 min), `findtime = 600`
- Filter: use built-in `sshd` filter
- No persistent bans (WSL restarts clear state anyway)
- Log only, no email/webhook notifications
- Enable and start fail2ban service after config

### Password Auth Transition
- Phase 2 script generates keys first, then updates sshd_config to disable password auth
- Display clear warning before disabling: "Make sure you've imported your key to Termius before continuing"
- In `--yes` (non-interactive) mode: disable immediately after key generation (assume user will import later)
- Localhost password auth remains as emergency recovery path

### Claude's Discretion
- Whether to create a dedicated `lib/ssh.sh` module or extend `lib/setup.sh`
- Exact fail2ban log path configuration
- Whether to verify key permissions (600/644) after generation
- Whether to test SSH login with the generated key before disabling password auth

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing SSH setup (Phase 1)
- `lib/setup.sh` — Contains `setup_ssh_config()` that writes cc-tmux.conf drop-in with password+pubkey auth. Phase 2 must upgrade this.
- `lib/common.sh` — Utility functions (log_ok, log_error, log_warn, log_hint, log_step, install_package, add_bashrc_block)
- `lib/config.sh` — Config management (write_config, read_config) for storing SSH key path
- `install.sh` — Entry point that sources all lib/ modules in order

### Research
- `.planning/research/STACK.md` — SSH hardening recommendations, Ed25519 over RSA rationale
- `.planning/research/PITFALLS.md` — SSH service doesn't persist across WSL2 restarts, systemd issues

### Project
- `.planning/PROJECT.md` — Core value (non-technical users), constraints (bash-only)
- `.planning/REQUIREMENTS.md` — SEC-01 through SEC-04 acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/setup.sh:setup_ssh_config()` — Already writes to `/etc/ssh/sshd_config.d/cc-tmux.conf`. Phase 2 can either modify this function or create a new `harden_ssh()` that overwrites the same file
- `lib/common.sh:log_step()` — Progress indicator for multi-step operations
- `lib/common.sh:install_package()` — Can verify fail2ban is installed (Phase 1 already installs it via deps.sh)
- `lib/config.sh:write_config()` — Can store SSH_KEY path in config.env

### Established Patterns
- Idempotent operations: check-before-act pattern used throughout Phase 1
- Drop-in config files: `/etc/ssh/sshd_config.d/cc-tmux.conf` pattern already established
- Sourced modules: all lib/ files sourced by install.sh, shared state via functions

### Integration Points
- `install.sh` step_ssh — currently calls `setup_ssh_config()` from lib/setup.sh
- `~/.cc-tmux/config.env` — Phase 2 adds `CC_TMUX_SSH_KEY` variable
- `/etc/ssh/sshd_config.d/cc-tmux.conf` — Phase 2 overwrites Phase 1's version
- `~/.ssh/authorized_keys` — Phase 2 adds the generated public key

</code_context>

<specifics>
## Specific Ideas

- User said "security" is a top priority — this must be locked down before the tunnel (Phase 3) exposes SSH publicly
- Key display should include step-by-step Termius import instructions (not just "here's your key")
- Non-technical users need hand-holding through the key concept — explain WHY password auth is being disabled

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-ssh-security*
*Context gathered: 2026-03-20*
