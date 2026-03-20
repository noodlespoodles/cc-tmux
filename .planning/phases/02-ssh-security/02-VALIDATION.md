---
phase: 2
slug: ssh-security
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash -n + sshd -t + service status checks |
| **Config file** | none — inline verification |
| **Quick run command** | `bash -n lib/setup.sh && echo "syntax ok"` |
| **Full suite command** | `bash -n lib/setup.sh && sudo sshd -t 2>&1` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash -n lib/setup.sh`
- **After every plan wave:** Run full validation including `sshd -t`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | SEC-01, SEC-04 | unit | `bash -n lib/setup.sh && grep -q "ssh-keygen.*ed25519" lib/setup.sh` | ✅ | ⬜ pending |
| 2-01-02 | 01 | 1 | SEC-02 | unit | `bash -n lib/setup.sh && grep -q "PermitRootLogin no" lib/setup.sh` | ✅ | ⬜ pending |
| 2-01-03 | 01 | 1 | SEC-03 | unit | `test -f lib/setup.sh && grep -q "fail2ban" lib/setup.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — lib/setup.sh exists from Phase 1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SSH key login works from Termius | SEC-01 | Requires phone + Termius app | Import key, connect via tunnel |
| fail2ban actually bans after 5 attempts | SEC-03 | Requires real failed SSH attempts | Attempt 6 wrong passwords from another terminal |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
