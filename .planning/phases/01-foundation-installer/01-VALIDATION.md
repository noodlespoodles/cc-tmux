---
phase: 1
slug: foundation-installer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (Bash Automated Testing System) |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `bats tests/unit/` |
| **Full suite command** | `bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bats tests/unit/`
- **After every plan wave:** Run `bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | ROB-04 | unit | `test -f .gitattributes && grep -q 'eol=lf' .gitattributes` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 1 | INST-02 | unit | `bats tests/unit/detect.bats` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 1 | INST-04 | unit | `bats tests/unit/common.bats` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | INST-01 | integration | `bats tests/integration/install.bats` | ❌ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | INST-05 | unit | `bats tests/unit/config.bats` | ❌ W0 | ⬜ pending |
| 1-02-03 | 02 | 1 | INST-06 | unit | `bats tests/unit/ngrok.bats` | ❌ W0 | ⬜ pending |
| 1-02-04 | 02 | 1 | INST-03 | integration | `bats tests/integration/idempotent.bats` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/unit/detect.bats` — stubs for INST-02 (username detection)
- [ ] `tests/unit/common.bats` — stubs for INST-04 (progress/error output)
- [ ] `tests/unit/config.bats` — stubs for INST-05 (project config)
- [ ] `tests/unit/ngrok.bats` — stubs for INST-06 (ngrok setup)
- [ ] `tests/integration/install.bats` — stubs for INST-01 (full install)
- [ ] `tests/integration/idempotent.bats` — stubs for INST-03 (re-run safety)
- [ ] BATS framework installed via `npm install --save-dev bats` or `apt install bats`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Desktop shortcut works | INST-08 | Requires Windows GUI | Click shortcut, verify WSL opens |
| Termius connects via tunnel | TUN-01 | Requires phone + ngrok | Connect from Termius app |

*Note: INST-08 and TUN-01 are Phase 6 and Phase 3 respectively — listed for awareness only.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
