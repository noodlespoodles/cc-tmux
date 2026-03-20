---
phase: 02-ssh-security
verified: 2026-03-20T15:45:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 2: SSH & Security Verification Report

**Phase Goal:** User's SSH service runs with defense-in-depth security that is safe to expose through a public tunnel
**Verified:** 2026-03-20T15:45:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

Must-haves sourced from both PLAN frontmatter (02-01-PLAN.md and 02-02-PLAN.md) and ROADMAP Success Criteria.

**From 02-01-PLAN.md must_haves.truths:**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Ed25519 key pair is generated at ~/.cc-tmux/keys/ with correct permissions | VERIFIED | `generate_ssh_keys()` at line 17: ssh-keygen -t ed25519, chmod 600 private, chmod 644 pub, chmod 700 dir |
| 2 | SSH drop-in config disables password auth remotely but allows it on localhost | VERIFIED | `write_hardened_ssh_config()`: PasswordAuthentication no globally, Match Address 127.0.0.1,::1 with PasswordAuthentication yes as last block |
| 3 | fail2ban jail is configured for SSH brute-force protection | VERIFIED | `configure_fail2ban()` at line 165: writes /etc/fail2ban/jail.d/cc-tmux.conf, maxretry=5, bantime=600, backend auto-detected |
| 4 | Private key is displayed with step-by-step Termius import instructions | VERIFIED | `display_key_instructions()` at line 65: 8-step numbered guide, BEGIN KEY/END KEY markers, cat of private key |

**From 02-02-PLAN.md must_haves.truths:**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | Running install.sh sources ssh-hardening.sh and executes the SSH hardening step | VERIFIED | install.sh line 33: `source "$SCRIPT_DIR/lib/ssh-hardening.sh"`, line 287-288: `log_step 7` + `step_harden_ssh` |
| 6 | Sudoers allows passwordless fail2ban-client and sshd -t commands | VERIFIED | lib/setup.sh line 47: NOPASSWD entries for service fail2ban *, sshd -t, sshd -T, fail2ban-client status * |
| 7 | step_verify reports pass/fail for SSH key, hardened config, and fail2ban jail | VERIFIED | lib/setup.sh lines 193-218: 3 checks added (cc-tmux_ed25519, 00-cc-tmux.conf, jail.d/cc-tmux.conf), total 10 pass++ counters confirmed |

**Score: 7/7 truths verified**

---

### ROADMAP Success Criteria Cross-Check

| SC# | Criterion | Status | Notes |
|-----|-----------|--------|-------|
| SC1 | SSH authenticates via Ed25519 keys by default — password authentication is disabled | VERIFIED | PasswordAuthentication no in sshd config, PubkeyAuthentication yes, key generated and installed to authorized_keys |
| SC2 | SSH daemon runs with hardened settings (no root login, limited auth attempts, protocol 2 only) | VERIFIED with note | PermitRootLogin no, MaxAuthTries 3, LoginGraceTime 30. The "Protocol 2 only" directive is intentionally absent — it was removed from OpenSSH 7.6 and causes parse errors on modern systems. All modern OpenSSH uses Protocol 2 implicitly. PLAN explicitly documents this decision. |
| SC3 | fail2ban is active and bans IPs after repeated failed SSH login attempts | VERIFIED | configure_fail2ban() deploys jail with maxretry=5, bantime=600, verifies jail status |
| SC4 | SSH key pair generated during install with private key displayed for Termius import | VERIFIED | step_harden_ssh() orchestrates: generate_ssh_keys -> install_public_key -> display_key_instructions with 8-step Termius guide |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/ssh-hardening.sh` | All Phase 2 security functions | VERIFIED | 6 functions confirmed: generate_ssh_keys, install_public_key, display_key_instructions, write_hardened_ssh_config, configure_fail2ban, step_harden_ssh. File passes `bash -n` syntax check. |
| `install.sh` | Updated installer with SSH hardening step | VERIFIED | Sources ssh-hardening.sh (line 33), TOTAL_STEPS=8 (line 276), step_harden_ssh as step 7 (lines 287-288). No stale TOTAL_STEPS=7. |
| `lib/setup.sh` | Updated sudoers and verification for Phase 2 | VERIFIED | Sudoers expanded with fail2ban + sshd commands, step_deploy uses log_step 8, step_verify has 10 pass++ checks (3 new Phase 2 checks). |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| install.sh | lib/ssh-hardening.sh | `source "$SCRIPT_DIR/lib/ssh-hardening.sh"` | WIRED | Line 33, after setup.sh source |
| install.sh | step_harden_ssh | function call in main() sequence | WIRED | Lines 287-288, between step_setup_system [6/8] and step_deploy [8/8] |
| lib/setup.sh | fail2ban-client | sudoers NOPASSWD entry | WIRED | Line 47: `/usr/bin/fail2ban-client status *` and `/usr/bin/fail2ban-client status` |
| lib/ssh-hardening.sh | lib/common.sh | sourced logging functions | WIRED | Uses log_ok, log_error, log_warn throughout — common.sh provides all 5 logging functions |
| lib/ssh-hardening.sh | lib/config.sh | write_config for SSH key path | WIRED | Line 33: `write_config CC_TMUX_SSH_KEY "$key_path"` |

---

### Requirements Coverage

All Phase 2 requirements appear in both 02-01-PLAN.md and 02-02-PLAN.md frontmatter.

| Requirement | Description | Source Plans | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| SEC-01 | SSH uses Ed25519 key-based authentication by default (not password-only) | 02-01, 02-02 | SATISFIED | generate_ssh_keys() creates Ed25519 pair; install_public_key() adds to authorized_keys; write_hardened_ssh_config() sets PasswordAuthentication no |
| SEC-02 | SSH daemon runs with hardened configuration (no root login, limited auth attempts) | 02-01, 02-02 | SATISFIED | PermitRootLogin no, MaxAuthTries 3, LoginGraceTime 30, PermitEmptyPasswords no, X11Forwarding no, AllowUsers restricted to current user |
| SEC-03 | fail2ban or equivalent protects against brute-force SSH attempts | 02-01, 02-02 | SATISFIED | configure_fail2ban() writes jail, auto-detects backend, restarts service, verifies jail active |
| SEC-04 | SSH keys are generated during install and displayed for easy phone setup | 02-01, 02-02 | SATISFIED | step_harden_ssh() calls display_key_instructions() which prints private key with 8-step Termius guide |

No orphaned requirements — all SEC-01 through SEC-04 are claimed by plans and implemented.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| lib/setup.sh | 17-23 | Phase 1 `cc-tmux.conf` drop-in is still written by setup_ssh_config() before hardening overwrites it | Info | Not a bug — hardening.sh deletes it via `sudo rm -f /etc/ssh/sshd_config.d/cc-tmux.conf` in write_hardened_ssh_config(). Slight redundancy but harmless. |
| lib/setup.sh | 82-86 | `step_configure()` defined in both install.sh (line 164) and lib/setup.sh (line 82) | Warning | Bash last-write-wins means install.sh's definition overrides setup.sh's silently. setup.sh's version is dead code. However, all functions it called (setup_ssh_config, setup_sudoers, setup_bashrc_hook) are correctly reached via step_setup_system() in install.sh. No functional impact, but the dead function in setup.sh is a maintenance hazard. |

No stub patterns, empty implementations, or TODO/FIXME comments found in Phase 2 files.

---

### Human Verification Required

#### 1. Interactive confirmation prompt display

**Test:** Run `bash install.sh` on a WSL2 system through the full flow until the SSH hardening step. When the private key is displayed, verify the warning prompt appears correctly before password auth is disabled.
**Expected:** Yellow `[!]` warning text appears, `Continue? (Y/n):` prompt is shown, entering `n` skips hardening, pressing Enter or `y` continues.
**Why human:** Interactive terminal flow and color rendering cannot be verified by static analysis.

#### 2. sshd config validation rollback

**Test:** Temporarily corrupt the sshd config and run `write_hardened_ssh_config()`. Verify rollback triggers and SSH remains accessible.
**Expected:** `log_error "SSH config syntax invalid -- rolling back"` fires, minimal safe config is restored, SSH still accepts connections.
**Why human:** Requires a live sshd environment; cannot be tested without running the service.

#### 3. fail2ban ban behavior

**Test:** On a live system after install, attempt 6+ failed SSH logins and verify the IP is banned.
**Expected:** After 5 failures within 600 seconds, subsequent attempts are refused. `sudo fail2ban-client status sshd` shows the banned IP.
**Why human:** Requires live network and SSH environment.

#### 4. Localhost password auth fallback

**Test:** From within WSL2 (127.0.0.1), attempt `ssh localhost` using the user password (not the key).
**Expected:** Password authentication succeeds from localhost even though it is disabled for remote connections.
**Why human:** Requires live SSH service with the Match Address block active.

---

### Gaps Summary

No gaps. All automated checks pass. Phase 2 delivers a complete, correctly wired SSH hardening system:

- `lib/ssh-hardening.sh` contains all 6 required functions with substantive implementations
- `install.sh` is correctly wired: sources the module, runs step 7 with the hardening orchestrator, TOTAL_STEPS=8
- `lib/setup.sh` is correctly updated: sudoers covers all required commands, step_deploy uses log_step 8, step_verify has 10 checks including 3 Phase 2 checks
- All key links verified (source, call, config write, logging dependency)
- All 4 SEC requirements satisfied
- No stub implementations, no Protocol 2 directive (correctly omitted per OpenSSH 7.6+)
- All three files pass `bash -n` syntax check

The one notable finding (dead `step_configure` function in setup.sh) is a pre-existing naming collision from Phase 1 that has no functional impact on Phase 2 behavior.

---

_Verified: 2026-03-20T15:45:00Z_
_Verifier: Claude (gsd-verifier)_
