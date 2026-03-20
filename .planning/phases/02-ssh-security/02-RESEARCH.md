# Phase 2: SSH & Security - Research

**Researched:** 2026-03-20
**Domain:** SSH hardening, Ed25519 key management, fail2ban intrusion prevention
**Confidence:** HIGH

## Summary

Phase 2 hardens the SSH configuration installed by Phase 1. The work breaks into four discrete areas: (1) Ed25519 key pair generation stored at `~/.cc-tmux/keys/`, (2) overwriting the existing `cc-tmux.conf` sshd drop-in with hardened settings, (3) configuring fail2ban for SSH brute-force protection, and (4) displaying the private key with Termius import instructions. All four areas are well-understood and use standard Linux tools with no exotic dependencies.

The critical architectural insight is that Ubuntu 24.04 places `Include /etc/ssh/sshd_config.d/*.conf` at the TOP of `/etc/ssh/sshd_config`, meaning drop-in files are read first and their values take precedence over the main config (OpenSSH uses first-match-wins for most directives). This means our `cc-tmux.conf` drop-in will reliably override defaults without touching the main sshd_config. One important caveat: the `Protocol 2` directive was removed from OpenSSH in version 7.6 (2017) -- it must NOT be included in the config or sshd will fail to start on modern systems.

**Primary recommendation:** Create a dedicated `lib/ssh-hardening.sh` module (Claude's discretion area) to keep Phase 2 logic cleanly separated from Phase 1's `lib/setup.sh`. The existing `setup_ssh_config()` function should remain as-is for Phase 1 compatibility; Phase 2 adds a `harden_ssh()` function that overwrites the same drop-in file with stronger settings.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Generate Ed25519 key pair stored at `~/.cc-tmux/keys/cc-tmux_ed25519` and `.pub`
- Do NOT touch `~/.ssh/` -- cc-tmux keys are self-contained
- If keys already exist at that path, skip generation (idempotent)
- After generation: print private key to terminal with clear Termius import instructions
- Also save key path to config.env (`CC_TMUX_SSH_KEY=~/.cc-tmux/keys/cc-tmux_ed25519`)
- Add the public key to `~/.ssh/authorized_keys` (create if needed, append if exists, skip if already present)
- Override the existing `/etc/ssh/sshd_config.d/cc-tmux.conf` drop-in (Phase 1 created this)
- Hardened settings: PubkeyAuthentication yes, PasswordAuthentication no, PermitRootLogin no, MaxAuthTries 3, LoginGraceTime 30, X11Forwarding no, AllowUsers {current_wsl_user}, Protocol 2 (if supported by OpenSSH version)
- Keep password auth available on localhost (`Match Address 127.0.0.1` block with `PasswordAuthentication yes`) as lockout safety net
- Don't touch the main `/etc/ssh/sshd_config` -- only the cc-tmux drop-in
- Create `/etc/fail2ban/jail.d/cc-tmux.conf` with SSH-specific jail
- fail2ban settings: maxretry = 5, bantime = 600 (10 min), findtime = 600
- Filter: use built-in `sshd` filter
- No persistent bans (WSL restarts clear state anyway)
- Log only, no email/webhook notifications
- Enable and start fail2ban service after config
- Phase 2 script generates keys first, then updates sshd_config to disable password auth
- Display clear warning before disabling: "Make sure you've imported your key to Termius before continuing"
- In `--yes` (non-interactive) mode: disable immediately after key generation (assume user will import later)
- Localhost password auth remains as emergency recovery path

### Claude's Discretion
- Whether to create a dedicated `lib/ssh.sh` module or extend `lib/setup.sh`
- Exact fail2ban log path configuration
- Whether to verify key permissions (600/644) after generation
- Whether to test SSH login with the generated key before disabling password auth

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SEC-01 | SSH uses Ed25519 key-based authentication by default (not password-only) | Ed25519 generation via `ssh-keygen -t ed25519`, key stored at `~/.cc-tmux/keys/cc-tmux_ed25519`, public key appended to `~/.ssh/authorized_keys` idempotently |
| SEC-02 | SSH daemon runs with hardened configuration (no root login, limited auth attempts) | Drop-in file at `/etc/ssh/sshd_config.d/cc-tmux.conf` overwrites Phase 1 version; Ubuntu's Include-at-top means drop-in takes precedence; Protocol 2 directive MUST be omitted (removed in OpenSSH 7.6) |
| SEC-03 | fail2ban or equivalent protects against brute-force SSH attempts | fail2ban jail drop-in at `/etc/fail2ban/jail.d/cc-tmux.conf`; backend must detect whether rsyslog writes auth.log or systemd journal is sole source |
| SEC-04 | SSH keys are generated during install and displayed for easy phone setup | Private key displayed with step-by-step Termius Android import instructions; no passphrase (user convenience for non-technical audience) |

</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| ssh-keygen | OpenSSH 9.x (bundled) | Ed25519 key pair generation | Standard tool, ships with openssh-server already installed by Phase 1 |
| sshd_config.d drop-in | OpenSSH 8.2+ | Modular SSH hardening config | Pattern already established by Phase 1; avoids touching main sshd_config |
| fail2ban | 1.0+ (apt) | SSH brute-force protection | Already installed by Phase 1 (`lib/deps.sh`); lightweight, zero-maintenance |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| sshd -t | OpenSSH 9.x | Validate sshd config syntax before restart | After writing drop-in, before restarting sshd -- prevents lockout from bad config |
| fail2ban-client | 1.0+ | Verify jail is active and correctly configured | After enabling fail2ban, to confirm sshd jail is running |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fail2ban | iptables rate limiting | fail2ban is higher-level, easier to configure, and already installed |
| Ed25519 keys | RSA 4096 keys | Never -- Ed25519 is universally supported since OpenSSH 6.5 (2014), smaller, faster, stronger |
| No passphrase on keys | Passphrase-protected keys | Non-technical users connecting from phone -- passphrase adds friction with minimal benefit since key is per-device |

## Architecture Patterns

### Recommended Module Structure

```
lib/
  ssh-hardening.sh    # NEW: Phase 2 SSH hardening functions
  setup.sh            # UNCHANGED: Phase 1 basic SSH setup remains intact
  common.sh           # Reuse: log_*, install_package, deploy_file
  config.sh           # Reuse: write_config, get_config, ensure_config_dir

~/.cc-tmux/
  keys/
    cc-tmux_ed25519       # Private key (permissions 600)
    cc-tmux_ed25519.pub   # Public key (permissions 644)
  config.env              # Adds: CC_TMUX_SSH_KEY="~/.cc-tmux/keys/cc-tmux_ed25519"

/etc/ssh/sshd_config.d/
  cc-tmux.conf            # OVERWRITTEN by Phase 2 (was created by Phase 1)

/etc/fail2ban/jail.d/
  cc-tmux.conf            # NEW: SSH jail configuration

~/.ssh/
  authorized_keys         # APPENDED: cc-tmux public key added (idempotent)
```

### Pattern 1: Idempotent Key Generation

**What:** Check if key exists before generating; check if public key is in authorized_keys before appending.
**When to use:** Every time the installer runs (could be first time or re-run).
**Example:**
```bash
generate_ssh_keys() {
    local key_dir="$CC_TMUX_DIR/keys"
    local key_path="$key_dir/cc-tmux_ed25519"

    mkdir -p "$key_dir"
    chmod 700 "$key_dir"

    if [[ -f "$key_path" ]]; then
        log_ok "SSH key pair already exists at $key_path"
        return 0
    fi

    # Generate Ed25519 key pair with no passphrase
    ssh-keygen -t ed25519 -f "$key_path" -N "" -C "cc-tmux-$(date +%Y%m%d)"
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"

    log_ok "Ed25519 key pair generated"
}
```

### Pattern 2: Idempotent Authorized Keys Append

**What:** Add public key to authorized_keys only if not already present.
**When to use:** After key generation, to register the key for SSH login.
**Example:**
```bash
install_public_key() {
    local pub_key_path="$CC_TMUX_DIR/keys/cc-tmux_ed25519.pub"
    local auth_keys="$HOME/.ssh/authorized_keys"

    # Ensure .ssh directory exists with correct permissions
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Read the public key content
    local pub_key
    pub_key=$(cat "$pub_key_path")

    # Append only if not already present
    if grep -qF "$pub_key" "$auth_keys" 2>/dev/null; then
        log_ok "Public key already in authorized_keys"
    else
        echo "$pub_key" >> "$auth_keys"
        chmod 600 "$auth_keys"
        log_ok "Public key added to authorized_keys"
    fi
}
```

### Pattern 3: Config Validation Before Restart

**What:** Use `sshd -t` to validate sshd_config syntax before restarting the service.
**When to use:** After writing the hardened drop-in config, before calling `service ssh restart`.
**Example:**
```bash
write_hardened_ssh_config() {
    local conf="/etc/ssh/sshd_config.d/cc-tmux.conf"
    local current_user
    current_user=$(whoami)

    sudo tee "$conf" > /dev/null <<EOF
# Managed by cc-tmux installer -- Phase 2 hardened config
# Overwrites Phase 1 basic config

ListenAddress 0.0.0.0

# Authentication
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
PermitEmptyPasswords no

# Access control
AllowUsers $current_user

# Security
X11Forwarding no

# Localhost fallback -- password auth on loopback only
Match Address 127.0.0.1,::1
    PasswordAuthentication yes
EOF

    # Validate before restarting
    if sudo sshd -t; then
        log_ok "SSH config syntax valid"
    else
        log_error "SSH config syntax invalid -- rolling back"
        # Rollback: restore Phase 1 config
        sudo tee "$conf" > /dev/null <<'ROLLBACK'
# Managed by cc-tmux installer
ListenAddress 0.0.0.0
PasswordAuthentication yes
PubkeyAuthentication yes
ROLLBACK
        return 1
    fi
}
```

### Pattern 4: fail2ban Backend Auto-Detection

**What:** Detect whether auth.log exists (rsyslog) or systemd journal is the sole log source.
**When to use:** When writing the fail2ban jail configuration.
**Example:**
```bash
configure_fail2ban() {
    local jail_conf="/etc/fail2ban/jail.d/cc-tmux.conf"

    # Detect log backend
    local backend="auto"
    if [[ -f /var/log/auth.log ]]; then
        backend="auto"  # fail2ban will find auth.log
    elif systemctl is-active systemd-journald &>/dev/null; then
        backend="systemd"
    fi

    sudo tee "$jail_conf" > /dev/null <<EOF
# Managed by cc-tmux installer
[sshd]
enabled = true
port = ssh
filter = sshd
backend = $backend
maxretry = 5
bantime = 600
findtime = 600
EOF
}
```

### Anti-Patterns to Avoid

- **Touching `/etc/ssh/sshd_config` directly:** Always use the drop-in directory. The main config may be managed by the distro or other tools.
- **Restarting sshd without validation:** Always run `sshd -t` first. A bad config kills ALL SSH connections including the one you're using.
- **Generating keys with a passphrase for this use case:** Non-technical users connecting from phone. Passphrase adds a step they won't understand and may lock them out.
- **Using `ssh-copy-id`:** It doesn't check for duplicates and requires an active SSH connection to the target (which is localhost, but still unnecessarily complex).
- **Including `Protocol 2` in sshd_config:** Removed from OpenSSH 7.6 (2017). Including it causes a config parse error on modern systems.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Key generation | Custom key generation logic | `ssh-keygen -t ed25519` | Battle-tested, handles entropy, file permissions, key format |
| Config syntax validation | Regex-based config checker | `sshd -t` (test mode) | OpenSSH's own validator catches issues no regex can |
| Brute-force detection | Custom log parser | fail2ban with built-in `sshd` filter | Handles log rotation, regex updates, ban/unban lifecycle |
| Public key deduplication | Line-by-line file comparison | `grep -qF "$pub_key" authorized_keys` | Simple, correct, handles edge cases |
| fail2ban jail config | Custom iptables rules | fail2ban jail.d drop-in | fail2ban manages the full lifecycle: detect, ban, unban, log |

**Key insight:** All four security components (key gen, config hardening, fail2ban, authorized_keys) have standard tools that handle edge cases. Custom solutions would miss corner cases like file locking, permission inheritance, and log format variations.

## Common Pitfalls

### Pitfall 1: Protocol 2 Directive Crashes sshd on Modern OpenSSH

**What goes wrong:** The `Protocol` keyword was removed from OpenSSH in version 7.6 (released October 2017). Including `Protocol 2` in sshd_config causes a parse error and prevents sshd from starting. The CONTEXT.md specifies "Protocol 2 (if supported by OpenSSH version)" -- it is NOT supported on any modern system.
**Why it happens:** Old hardening guides still recommend it. Many copy-paste configs include it.
**How to avoid:** Omit `Protocol 2` entirely. OpenSSH has been protocol-2-only since version 7.6. Check with: `sshd -t` after writing config.
**Warning signs:** `sshd -t` returns "Deprecated option Protocol" or service fails to restart.

### Pitfall 2: Drop-in Config Ordering and First-Match-Wins

**What goes wrong:** If Ubuntu has a file like `50-cloud-init.conf` in sshd_config.d that sets `PasswordAuthentication yes`, and your cc-tmux.conf sorts alphabetically AFTER it, your `PasswordAuthentication no` is ignored because OpenSSH uses first-match-wins.
**Why it happens:** Ubuntu 24.04 includes `/etc/ssh/sshd_config.d/*.conf` at the TOP of sshd_config, so drop-in files are processed alphabetically before the main config. Among drop-in files, lexical order determines precedence.
**How to avoid:** Name the drop-in file so it sorts EARLY: `00-cc-tmux.conf` instead of `cc-tmux.conf`. This ensures cc-tmux settings win over any other drop-in files. Phase 1 used `cc-tmux.conf` -- Phase 2 should rename to `00-cc-tmux.conf` and clean up the old file.
**Warning signs:** `PasswordAuthentication` still shows as `yes` when testing with `sshd -T | grep password`.

### Pitfall 3: fail2ban Backend Mismatch on WSL2

**What goes wrong:** fail2ban defaults to `backend = auto`, which looks for log files. On WSL2 with systemd enabled, sshd may log to the systemd journal instead of `/var/log/auth.log`. If rsyslog is not running or not installed, auth.log doesn't exist and fail2ban silently does nothing.
**Why it happens:** Ubuntu on WSL2 has inconsistent logging -- rsyslog may or may not be active depending on systemd configuration. Modern Ubuntu increasingly relies on journald.
**How to avoid:** Auto-detect the backend: check if `/var/log/auth.log` exists AND is being actively written to. If not, use `backend = systemd`. Verify after setup with `fail2ban-client status sshd`.
**Warning signs:** `fail2ban-client status sshd` shows 0 total banned and 0 currently failed even after deliberate failed login attempts.

### Pitfall 4: Match Block Must Be Last in Drop-in Config

**What goes wrong:** In sshd_config, a `Match` block extends to the end of the file or until the next `Match` keyword. If you put any global directives AFTER a `Match Address` block, they become part of the Match block instead of global settings.
**Why it happens:** The Match block is not a traditional "block" with an end marker -- it's a context switch that persists.
**How to avoid:** Always place the `Match Address 127.0.0.1,::1` block as the VERY LAST section in the drop-in config file. No global directives should follow it.
**Warning signs:** Settings after the Match block only apply to localhost connections, not to all connections as intended.

### Pitfall 5: Disabling Password Auth Before Key Is Imported

**What goes wrong:** The installer disables password authentication, but the user hasn't yet imported their private key into Termius on their phone. They can no longer SSH in from any device, including testing from localhost (unless the localhost Match block is present).
**Why it happens:** Sequential operations -- config change takes effect immediately on sshd restart, but key import is a manual user action.
**How to avoid:** In interactive mode, display the key and import instructions, then ask for confirmation before disabling password auth. The localhost `Match Address` fallback is the safety net for recovery. In `--yes` mode, proceed immediately (user accepts the risk).
**Warning signs:** User reports "connection refused" or "permission denied" after running the installer.

### Pitfall 6: authorized_keys Permissions Too Open

**What goes wrong:** OpenSSH refuses to use authorized_keys if the file or its parent directory has permissions that are too open. Specifically: `~/.ssh/` must be 700, `authorized_keys` must be 600 or 644. If these are wrong, key auth silently fails and the user gets "permission denied".
**Why it happens:** Scripts that create these files may not set permissions, or WSL2's `/mnt/c/` mount permissions can bleed into `~/` in edge cases.
**How to avoid:** Explicitly set `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/authorized_keys` after every write operation. Verify with `ls -la ~/.ssh/`.
**Warning signs:** Key auth fails silently; `sshd` log shows "Authentication refused: bad ownership or modes for file /home/user/.ssh/authorized_keys".

## Code Examples

### Complete Hardened sshd Drop-in Config

```bash
# /etc/ssh/sshd_config.d/00-cc-tmux.conf
# Managed by cc-tmux installer -- Phase 2 hardened config
# Do not edit manually; re-run installer to regenerate

ListenAddress 0.0.0.0

# Authentication -- key-only for remote connections
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
PermitEmptyPasswords no

# Access control
AllowUsers {current_user}

# Security hardening
X11Forwarding no
ClientAliveInterval 120
ClientAliveCountMax 3

# Localhost safety net -- password auth on loopback
Match Address 127.0.0.1,::1
    PasswordAuthentication yes
```

**Note:** `Protocol 2` is intentionally omitted -- it was removed from OpenSSH 7.6 and causes parse errors on modern systems.

### Complete fail2ban Jail Drop-in

```bash
# /etc/fail2ban/jail.d/cc-tmux.conf
# Managed by cc-tmux installer

[sshd]
enabled = true
port = ssh
filter = sshd
backend = {auto-detected: auto|systemd}
maxretry = 5
bantime = 600
findtime = 600
```

### Key Display and Termius Instructions Template

```bash
display_key_instructions() {
    local key_path="$1"

    echo ""
    echo "========================================"
    echo "  Your SSH Private Key"
    echo "========================================"
    echo ""
    echo "  WHY: Your SSH connection now requires"
    echo "  a key instead of a password. This is"
    echo "  much more secure -- like a lock that"
    echo "  only your specific key can open."
    echo ""
    echo "  Copy everything between the lines below:"
    echo ""
    echo "  ---- BEGIN KEY (copy from here) ----"
    cat "$key_path"
    echo "  ---- END KEY (copy to here) ----"
    echo ""
    echo "  HOW TO IMPORT INTO TERMIUS (Android):"
    echo ""
    echo "  1. Open Termius on your phone"
    echo "  2. Tap Settings (gear icon)"
    echo "  3. Tap Keychain"
    echo "  4. Tap + (plus) to add a new key"
    echo "  5. Tap 'Paste from clipboard'"
    echo "  6. Paste the key you copied above"
    echo "  7. Give it a name like 'cc-tmux'"
    echo "  8. Tap Save"
    echo ""
    echo "  Then when setting up your SSH connection"
    echo "  in Termius, select this key instead of"
    echo "  using a password."
    echo ""
    echo "========================================"
}
```

### Effective sshd Config Verification

```bash
# After writing config, verify effective settings
verify_ssh_hardening() {
    local pass=0
    local fail=0

    # Check effective config (not just file contents)
    local effective
    effective=$(sudo sshd -T 2>/dev/null)

    # Verify key settings
    if echo "$effective" | grep -qi "passwordauthentication no"; then
        log_ok "Password auth disabled (remote)"
        ((pass++))
    else
        log_error "Password auth still enabled"
        ((fail++))
    fi

    if echo "$effective" | grep -qi "pubkeyauthentication yes"; then
        log_ok "Public key auth enabled"
        ((pass++))
    else
        log_error "Public key auth not enabled"
        ((fail++))
    fi

    if echo "$effective" | grep -qi "permitrootlogin no"; then
        log_ok "Root login disabled"
        ((pass++))
    else
        log_error "Root login still permitted"
        ((fail++))
    fi

    echo "  SSH hardening: $pass passed, $fail failed"
    [[ $fail -eq 0 ]]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Protocol 2` directive | Omit entirely | OpenSSH 7.6 (Oct 2017) | Including it causes parse error on modern systems |
| RSA 4096 keys | Ed25519 keys | ~2019 industry shift | Smaller, faster, stronger; universally supported since OpenSSH 6.5 |
| `/var/log/auth.log` for fail2ban | Auto-detect auth.log vs systemd journal | Ubuntu 22.04+ | Journal may be sole log source on systemd-enabled WSL2 |
| Single `sshd_config` file | `sshd_config.d/` drop-in directory | OpenSSH 8.2 (Feb 2020) | Modular config that survives package upgrades |
| `backend = auto` in fail2ban | Explicit backend detection | fail2ban 0.11+ | Auto may not find journal backend; explicit is safer |

**Deprecated/outdated:**
- `Protocol 2`: Removed from OpenSSH 7.6. Protocol 1 support was entirely dropped.
- `UsePrivilegeSeparation`: Removed in OpenSSH 7.5. Privilege separation is always on.
- `KeyRegenerationInterval`: Removed with Protocol 1 support.
- RSA host keys as default: Ed25519 host keys are now preferred.

## Open Questions

1. **Drop-in file naming: `cc-tmux.conf` vs `00-cc-tmux.conf`**
   - What we know: Ubuntu processes drop-in files alphabetically. First-match-wins. A file named `50-cloud-init.conf` would take precedence over `cc-tmux.conf` (which sorts after `5`).
   - What's unclear: Whether WSL2 Ubuntu images typically include any other drop-in files in sshd_config.d.
   - Recommendation: Rename to `00-cc-tmux.conf` to guarantee precedence. Clean up old `cc-tmux.conf` from Phase 1 during the upgrade. This is safe and defensive.

2. **fail2ban service persistence across WSL2 restarts**
   - What we know: WSL2 services don't survive shutdown/restart. fail2ban state is ephemeral.
   - What's unclear: Whether fail2ban auto-starts via systemd on WSL2 boot (depends on systemd enablement status).
   - Recommendation: Don't depend on fail2ban auto-starting. The startup script (Phase 3+) should ensure fail2ban is running. For Phase 2, just configure and start it once. Document that it needs restart after WSL reboot.

3. **Whether to test SSH login with generated key before disabling password auth**
   - What we know: This would be the gold standard for safety. Could use `ssh -i key localhost echo test`.
   - What's unclear: Whether sshd is running and accessible at the point in the install script where this would happen (it should be, since Phase 1 starts it).
   - Recommendation: YES, do a quick verification. It's a Claude discretion area and the safety benefit is high. If the test fails, abort the password-disable step and warn the user.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash (manual verification commands) |
| Config file | none -- bash scripts, verified by running commands |
| Quick run command | `sudo sshd -T \| grep -E "(password\|pubkey\|permitroot\|maxauth)"` |
| Full suite command | Run all verification checks in sequence (see below) |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SEC-01 | Ed25519 key exists and is in authorized_keys | smoke | `test -f ~/.cc-tmux/keys/cc-tmux_ed25519 && grep -qF "$(cat ~/.cc-tmux/keys/cc-tmux_ed25519.pub)" ~/.ssh/authorized_keys` | n/a (inline) |
| SEC-02 | sshd runs hardened config | smoke | `sudo sshd -T \| grep -q "passwordauthentication no" && sudo sshd -T \| grep -q "permitrootlogin no"` | n/a (inline) |
| SEC-03 | fail2ban sshd jail is active | smoke | `sudo fail2ban-client status sshd 2>/dev/null \| grep -q "Status"` | n/a (inline) |
| SEC-04 | Key was generated and display function exists | unit | `test -f ~/.cc-tmux/keys/cc-tmux_ed25519.pub && file ~/.cc-tmux/keys/cc-tmux_ed25519 \| grep -q "private"` | n/a (inline) |

### Sampling Rate

- **Per task commit:** Run quick sshd -T check and key existence check
- **Per wave merge:** Full verification of all SEC-01 through SEC-04
- **Phase gate:** All four smoke tests pass before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] Add `step_verify` entries in `lib/setup.sh` for SSH hardening checks (key exists, config valid, fail2ban active)
- [ ] Add sudoers entry for `fail2ban-client` if needed for status checks (check if current sudoers covers it)

## Sources

### Primary (HIGH confidence)

- [sshd_config(5) man page](https://man7.org/linux/man-pages/man5/sshd_config.5.html) - Match block allowed keywords (PasswordAuthentication confirmed), Include directive behavior, first-match-wins semantics
- [OpenSSH Release Notes](https://www.openssh.org/releasenotes.html) - Protocol keyword removal confirmed in 7.6
- [Termius Import SSH Keys](https://termius.com/documentation/import-ssh-keys) - Ed25519 import workflow confirmed
- [fail2ban GitHub Discussion #3638](https://github.com/fail2ban/fail2ban/discussions/3638) - systemd journal backend configuration
- [fail2ban GitHub Issue #3292](https://github.com/fail2ban/fail2ban/issues/3292) - backend = systemd required on systemd-only systems
- [SSH Ed25519 Best Practices 2025](https://www.brandonchecketts.com/archives/ssh-ed25519-key-best-practices-for-2025) - Ed25519 as current standard, no-passphrase tradeoffs

### Secondary (MEDIUM confidence)

- [DigitalOcean - SSH with fail2ban](https://www.digitalocean.com/community/tutorials/how-to-protect-ssh-with-fail2ban-on-ubuntu-20-04) - jail.d drop-in pattern, sshd filter usage
- [Arch Wiki - fail2ban](https://wiki.archlinux.org/title/Fail2ban) - systemd backend configuration
- [firxworx.com - Avoiding duplicate authorized_keys entries](https://firxworx.com/blog/devops/add-entry-to-ssh-authorized_keys-avoid-duplicates/) - grep -qF idempotency pattern
- [Hacker News - sshd_config.d order matters](https://news.ycombinator.com/item?id=43573507) - First-match-wins discussion, alphabetical ordering

### Tertiary (LOW confidence)

- [rsyslog on WSL2](https://gist.github.com/0x49D1/596d457921034e9c18e5e1052a4ad515) - Known WSL2 rsyslog issues (may or may not apply to current WSL2 versions)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are already installed by Phase 1; well-documented, stable
- Architecture: HIGH - Drop-in config pattern established by Phase 1; sshd_config behavior verified against official man pages
- Pitfalls: HIGH - Protocol 2 removal verified against OpenSSH release notes; first-match-wins verified against man page; fail2ban backend issue verified against fail2ban GitHub
- Code examples: HIGH - Based on official OpenSSH man page, established bash patterns, and verified Termius import workflow

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable domain -- SSH hardening patterns change slowly)

---
*Phase: 02-ssh-security*
*Research completed: 2026-03-20*
