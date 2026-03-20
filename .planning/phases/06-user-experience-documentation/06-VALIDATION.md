---
phase: 6
slug: user-experience-documentation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash -n syntax checks + grep + file existence |
| **Config file** | none — inline verification |
| **Quick run command** | `bash -n lib/setup.sh && bash -n startup.sh && test -f README.md` |
| **Full suite command** | `bash -n lib/setup.sh && bash -n startup.sh && bash -n install.sh && test -f README.md` |
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
| 6-01-01 | 01 | 1 | INST-08, MOB-04 | unit | `bash -n lib/setup.sh && grep -q "create_desktop_shortcut" lib/setup.sh && grep -q "qrencode" startup.sh` | ✅ | ⬜ pending |
| 6-01-02 | 01 | 1 | DOC-01, DOC-02, DOC-03 | unit | `test -f README.md && grep -q "Quick Reference" README.md && grep -q "Troubleshooting" README.md` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `README.md` — documentation file (created by plan)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Desktop shortcut launches workspace | INST-08 | Requires Windows desktop | Double-click shortcut, verify workspace opens |
| QR code displays and scans correctly | MOB-04 | Requires phone camera | Scan QR with phone, verify SSH connection string |
| README is clear for non-technical users | DOC-01 | Prose quality review | Read from a beginner's perspective |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
