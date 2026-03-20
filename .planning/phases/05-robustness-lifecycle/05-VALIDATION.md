---
phase: 5
slug: robustness-lifecycle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash -n syntax checks + grep verification |
| **Config file** | none — inline verification |
| **Quick run command** | `bash -n lib/doctor.sh && bash -n lib/update.sh && bash -n lib/uninstall.sh` |
| **Full suite command** | `for f in lib/doctor.sh lib/update.sh lib/uninstall.sh bin/cc-tmux; do bash -n "$f"; done` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick syntax check
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | ROB-01, ROB-02 | unit | `bash -n lib/common.sh && grep -q "^log_check_pass()" lib/common.sh && grep -q "^remove_bashrc_block()" lib/common.sh` | ✅ | ⬜ pending |
| 5-01-02 | 01 | 1 | ROB-03 | unit | `bash -n lib/doctor.sh && grep -q "^run_doctor()" lib/doctor.sh` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 2 | ROB-05, INST-07 | unit | `bash -n lib/update.sh && bash -n lib/uninstall.sh && grep -q "run_update" lib/update.sh && grep -q "run_uninstall" lib/uninstall.sh` | ❌ W0 | ⬜ pending |
| 5-02-02 | 02 | 2 | ROB-01, ROB-02 | unit | `grep -q 'source.*lib/doctor\.sh' bin/cc-tmux && grep -q '! -f.*lib/doctor\.sh' bin/cc-tmux` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `lib/doctor.sh` — doctor diagnostics stub
- [ ] `lib/update.sh` — self-update stub
- [ ] `lib/uninstall.sh` — clean uninstall stub

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| cc-tmux update pulls and redeploys | ROB-05 | Requires git remote + changes | Push a change, run update, verify |
| cc-tmux uninstall removes everything | INST-07 | Destructive — removes files | Run uninstall, verify cleanup |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
