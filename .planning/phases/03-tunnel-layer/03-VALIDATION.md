---
phase: 3
slug: tunnel-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash -n syntax checks + grep function verification |
| **Config file** | none — inline verification |
| **Quick run command** | `bash -n lib/tunnel/provider.sh && bash -n lib/tunnel/ngrok.sh` |
| **Full suite command** | `for f in lib/tunnel/*.sh; do bash -n "$f"; done && echo "all pass"` |
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
| 3-01-01 | 01 | 1 | TUN-04 | unit | `bash -n lib/tunnel/provider.sh && grep -q "tunnel_start\|tunnel_stop\|tunnel_status\|tunnel_url" lib/tunnel/provider.sh` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | TUN-01, TUN-03 | unit | `bash -n lib/tunnel/ngrok.sh && grep -q "tunnel_start\|tunnel_url" lib/tunnel/ngrok.sh` | ❌ W0 | ⬜ pending |
| 3-02-01 | 02 | 2 | TUN-02 | unit | `grep -q "watchdog\|reconnect\|backoff" lib/tunnel/ngrok.sh` | ❌ W0 | ⬜ pending |
| 3-02-02 | 02 | 2 | TUN-01 | unit | `grep -q "tunnel_start\|startup" install.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `lib/tunnel/` directory created
- [ ] `lib/tunnel/provider.sh` — provider interface stub
- [ ] `lib/tunnel/ngrok.sh` — ngrok provider stub

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tunnel connects and displays address | TUN-01 | Requires ngrok account + network | Run startup, verify address shown |
| Auto-reconnect on tunnel drop | TUN-02 | Requires killing ngrok process | Kill ngrok, wait 30s, check if restarted |
| Phone connects via tunnel address | TUN-01 | Requires Termius + phone | Connect from phone using displayed address |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
