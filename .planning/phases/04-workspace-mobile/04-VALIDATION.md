---
phase: 4
slug: workspace-mobile
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash -n syntax checks + grep function verification |
| **Config file** | none — inline verification |
| **Quick run command** | `bash -n lib/workspace.sh && bash -n bin/cc-tmux` |
| **Full suite command** | `for f in lib/workspace.sh bin/cc-tmux templates/mobile-check.sh; do bash -n "$f"; done` |
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
| 4-01-01 | 01 | 1 | WRK-01, WRK-03, WRK-04 | unit | `bash -n lib/workspace.sh && grep -q "workspace_init\|workspace_attach" lib/workspace.sh` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 1 | WRK-05, MOB-01, MOB-02, MOB-03 | unit | `grep -q "mobile\|client_width\|89b4fa" templates/tmux.conf.tpl` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 2 | WRK-02 | unit | `bash -n bin/cc-tmux && grep -q "project.*add\|project.*remove\|project.*list" bin/cc-tmux` | ❌ W0 | ⬜ pending |
| 4-02-02 | 02 | 2 | WRK-01 | unit | `grep -q "workspace_init" startup.sh && grep -q "cc-tmux" install.sh` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `lib/workspace.sh` — workspace init stub
- [ ] `templates/tmux.conf.tpl` — tmux config template
- [ ] `bin/cc-tmux` — CLI entry point stub

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| tmux windows created per project | WRK-01 | Requires running tmux | Run startup, verify windows match projects.conf |
| Mobile mode triggers on narrow terminal | MOB-01 | Requires Termius/narrow terminal | SSH from phone, check layout |
| Session survives terminal close | WRK-03 | Requires close/reopen cycle | Close window, reopen, verify session exists |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
