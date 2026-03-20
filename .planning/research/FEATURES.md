# Feature Research

**Domain:** Terminal workspace / remote dev environment toolkit (WSL2 + tmux + SSH tunnel)
**Researched:** 2026-03-20
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| One-command installer | Every modern CLI tool (homebrew, nvm, rustup) installs with one command. Asking users to copy-paste 13 steps is a dealbreaker for the non-technical audience | MEDIUM | V1 has `install.sh` but it still requires manual project editing afterward. V2 must handle everything including interactive project setup. Detect Windows username automatically via `cmd.exe /C "echo %USERNAME%"` (V1 already does this). Must handle apt, snap, SSH config, ngrok auth, tmux conf, bashrc modification in sequence with clear progress |
| Automatic Windows username detection | V1's YOURUSERNAME placeholder is the #1 friction point. Every comparable tool (tmuxinator, smug, chezmoi) auto-detects environment context | LOW | Already solved in V1 installer via `cmd.exe /C "echo %USERNAME%"` -- just needs to be applied consistently everywhere |
| Project/workspace management via CLI | tmuxinator has `tmuxinator new/list/edit/delete/copy`. smug has `smug start/stop/list/edit/new`. Users expect `ccx add myproject /path/to/folder`, not "edit workspace-init.sh" | MEDIUM | Store workspace config in a YAML or simple key-value file (`~/.config/ccx/projects.conf`). CLI commands: `ccx add <name> <path>`, `ccx remove <name>`, `ccx list`. Generate tmux session from config at startup |
| Cross-device session continuity | The entire product premise. tmux handles this natively -- just need SSH + tunnel. Must work: start on PC, walk away, connect from phone, same state | LOW | V1 already does this. V2 just needs to make it more robust (auto-reconnect, better attach logic) |
| SSH with key-based auth | Every SSH setup guide since 2015 says "disable password auth, use keys." Security-conscious users will bounce if they see password-only auth. Termius supports SSH keys natively | MEDIUM | Generate SSH key pair during install, display public key for user to add to Termius. Optionally keep password auth as fallback during setup phase, then prompt user to disable it |
| Tunnel with connection info display | Users need to know how to connect from their phone. V1 shows this but the port changes every reboot. Must show connection details clearly every startup | LOW | V1 does this already. V2 improves by persisting the info to a file and providing a `ccx status` command |
| Desktop shortcut (Windows) | Non-technical users expect a clickable icon, not a terminal command. V1 has this via PowerShell script | LOW | V1 approach works. V2 should automate the PowerShell execution from within the bash installer (call `powershell.exe` from WSL) |
| Graceful attach/reattach | tmuxinator, smug, and every tmux wrapper handle "session exists? attach. Doesn't exist? create then attach" seamlessly | LOW | V1's `attach.sh` does this. V2 should integrate it into the main `ccx` command |
| Mobile-friendly tmux mode | When your pitch is "use it from your phone," the phone experience must work. Small screens need bigger tap targets, minimal status bar, essential info only | LOW | V1 has manual Ctrl+B, Shift+M toggle. V2 should auto-detect SSH client screen dimensions and switch automatically when width < 80 columns |
| Error handling and input validation | V1 has none -- wrong paths silently break. Any tool handling system configuration (SSH, services) needs clear error messages and rollback | MEDIUM | Wrap every operation in validation. Check paths exist before adding projects. Verify SSH starts successfully. Confirm ngrok has auth token before attempting tunnel |
| Uninstall script | chezmoi has `purge`, tmuxinator doesn't need one (just delete YAML). But a tool that modifies SSH config, bashrc, sudoers, and installs system packages MUST clean up after itself | LOW | V1 README has manual steps. V2 needs `ccx uninstall` that reverses everything the installer did |
| Health check / diagnostics | When SSH won't connect or ngrok dies, users need `ccx doctor` not a troubleshooting section in a README. tmux-resurrect has status checks, Docker has `docker info` | MEDIUM | Check: SSH running? tmux session exists? ngrok tunnel active? Tunnel address reachable? WSL networking mode? Report clear pass/fail for each component |

### Differentiators (Competitive Advantage)

Features that set this product apart from raw tmux + SSH + ngrok setup. Not expected from the category, but directly support the core value proposition.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Auto-detect mobile vs desktop | No other tmux wrapper auto-switches display modes based on terminal dimensions. Users connect from phone and it just looks right -- no keybinding ritual | LOW | Use tmux hooks or check `#{client_width}` on attach. If width < 80, apply mobile-optimized status bar. If >= 80, use desktop layout. tmux supports `client-session-changed` hook |
| Tunnel auto-reconnect with notification | ngrok free tier tunnels die regularly. Users currently discover this when their phone can't connect. Tool should detect tunnel death, restart it, and update the stored connection info | MEDIUM | Background watchdog script that monitors ngrok process and `/api/tunnels` endpoint. On death: restart ngrok, update stored address file. Optionally notify via simple webhook or file flag |
| Guided interactive installer for non-technical users | tmuxinator requires editing YAML. smug requires editing YAML. chezmoi has a setup wizard but it's for dotfiles. No tmux workspace tool offers a "What projects do you work on? What folders?" interview-style setup | MEDIUM | After dependency installation, walk user through: "Enter project name:" / "Enter folder path (or drag folder here):" / "Add another? (y/n)". Build config from answers. Much friendlier than "edit this YAML file" |
| Persistent tunnel endpoint guidance | ngrok free tier changes URL every restart, which is the biggest pain point. Tool should guide users toward stable endpoint solutions (ngrok paid domain, Cloudflare Tunnel free alternative, Tailscale) and make switching easy | LOW | Provide `ccx tunnel --provider cloudflare` or similar. Document the free Cloudflare Tunnel path (stable URL, no cost, just needs a domain). Ship ngrok as default but make the tunnel provider swappable |
| Self-updating / version checking | smug and tmuxinator don't self-update (they rely on package managers). A git-based tool can `git pull` to update. Non-technical users need "a new version is available" prompts, not manual checking | LOW | On startup, compare local version tag with remote. If behind, display "Update available. Run `ccx update` to get it." Update is just `git pull` + re-run config migration if needed |
| Session persistence across WSL restarts | tmux-resurrect and tmux-continuum save/restore sessions across restarts, but they focus on pane content, not workspace structure. This tool knows the workspace structure from config, so it can always rebuild perfectly | LOW | Since project config defines the workspace, a WSL restart just means re-running workspace-init. No plugin needed. But add `systemd` or Task Scheduler integration so SSH and tmux start automatically when WSL boots |
| QR code for phone connection | Claude Code Remote Control displays a QR code for phone access. This is a delightful UX touch -- scan to connect instead of typing `0.tcp.in.ngrok.io:12345` into Termius manually | LOW | Generate QR code in terminal using `qrencode` (apt installable) with the SSH connection string. Display after tunnel starts. Massive UX win for the "set up your phone" step |
| Workspace templates | Beyond personal projects, offer starter templates: "Claude Code workspace" (3 project tabs + a scratch tab), "Web dev" (frontend + backend + db tabs), "Solo project" (single tab). Reduce setup friction further | LOW | Ship 2-3 template YAML files. `ccx init --template claude-code` creates a workspace from template. Templates are just pre-filled project configs with sensible defaults |
| Mosh support as SSH alternative | Mosh handles network changes and high latency gracefully -- perfect for mobile. SSH drops connection when switching WiFi to cellular; Mosh reconnects automatically. Termius supports Mosh | MEDIUM | Offer `ccx tunnel --mosh` or auto-install mosh alongside SSH. Mosh requires UDP port forwarding which ngrok free tier does NOT support (TCP only). This pairs better with Tailscale or Cloudflare. Flag as enhancement, not default |
| Configuration backup/export | When users reinstall Windows or set up a new machine, they lose their workspace config. A simple `ccx export` / `ccx import` saves time | LOW | Export workspace config + tmux.conf to a tarball or single file. Import restores them. Not a full dotfile manager -- just this tool's own config |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems. Explicitly NOT building these.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| GUI installer (Windows native) | "Non-technical users prefer GUIs" | Massive complexity increase (Electron/WPF) for a tool that runs in the terminal. The audience already has Windows Terminal and WSL. If they can't run a bash command, the entire product (tmux, SSH, Claude Code) won't work for them either | Well-designed interactive CLI installer with clear prompts, colors, and progress indicators. Terminal IS the GUI for this product |
| Custom tmux plugin system | "Let users extend with plugins" | Plugin ecosystems require maintenance, compatibility testing, and documentation that dwarfs the core tool. TPM (Tmux Plugin Manager) already exists for users who want plugins | Ship an opinionated tmux config that works great out of the box. Power users can modify `~/.tmux.conf` directly -- it's just a text file |
| Multi-user / shared workspaces | "Pair programming from different devices" | Shared tmux sessions have auth, permission, and conflict issues. Different users typing in the same pane creates chaos. This is a single-user tool by design | Each user installs their own instance. For pair programming, use screen sharing or dedicated tools (VS Code Live Share, tmate) |
| Full dotfile management | "Sync all my dotfiles across machines" | Scope creep into chezmoi/yadm territory. Those tools are mature and battle-tested. Reimplementing dotfile management adds no value to the core use case | Manage only this tool's own config (workspace layout, tunnel settings). Recommend chezmoi for full dotfile management in docs |
| iOS support | "I have an iPhone, not Android" | Testing requires Apple hardware. Termius exists on iOS but SSH key behavior, keyboard shortcuts, and tunnel compatibility differ. Can't verify quality without devices | Document that it "should work" with any SSH client on any platform, but only test and support Android + Termius. Community can report iOS findings |
| Docker/container-based approach | "Containers are more portable and isolated" | Adds Docker as a dependency (complex on Windows), breaks WSL2 filesystem access patterns, makes the tool inaccessible to the non-technical audience. The whole point is simplicity | Direct WSL2 installation. Docker is overhead for a personal workspace tool |
| Web-based terminal UI | "Access from any browser without SSH client" | Requires running a web server (ttyd, wetty, gotty), managing HTTPS certificates, and dealing with authentication -- all for marginal benefit when Termius already works | SSH client on phone is simpler, more secure, and already solved. Point users to Termius |
| Automatic Claude Code session management | "Auto-start Claude in each tab" | Claude Code requires API keys, authentication, and interactive consent. Auto-starting it in every tab wastes API credits and may trigger rate limits. Users want control over when Claude runs | Open tabs in the right directories with the right shell. Let users type `claude` when they're ready |

## Feature Dependencies

```
[One-command installer]
    |--requires--> [Windows username detection]
    |--requires--> [SSH key-based auth setup]
    |--requires--> [Tunnel provider setup (ngrok default)]
    |--requires--> [Project/workspace config format]
    |--produces--> [Desktop shortcut]

[Project management CLI]
    |--requires--> [Project/workspace config format]
    |--produces--> [Workspace session creation]

[Mobile auto-detect]
    |--requires--> [Mobile-friendly tmux mode]
    |--enhances--> [Cross-device session continuity]

[Tunnel auto-reconnect]
    |--requires--> [Tunnel provider setup]
    |--enhances--> [Cross-device session continuity]
    |--enables---> [Connection info display (stable)]

[Health check / diagnostics]
    |--requires--> [SSH setup]
    |--requires--> [Tunnel setup]
    |--requires--> [tmux session management]

[QR code for phone]
    |--requires--> [Tunnel connection info]
    |--enhances--> [Phone setup experience]

[Mosh support]
    |--conflicts--> [ngrok free tier (TCP only, no UDP)]
    |--requires--> [Tailscale or Cloudflare tunnel]

[Self-update]
    |--requires--> [Version tagging in git]

[Guided interactive installer]
    |--enhances--> [One-command installer]
    |--produces--> [Project/workspace config]
```

### Dependency Notes

- **Mosh conflicts with ngrok free tier:** Mosh requires UDP ports. ngrok free tier only supports TCP tunnels. Mosh only becomes viable if the user switches to Tailscale (peer-to-peer, supports UDP) or Cloudflare Tunnel. This means Mosh support is a Phase 3+ feature that depends on multi-tunnel-provider support being built first.
- **Project management CLI requires config format decision first:** Before building `ccx add/remove/list`, the config file format (YAML vs INI vs simple key-value) must be decided. This is a Phase 1 foundational decision.
- **Health check depends on all infrastructure being in place:** The `ccx doctor` command can only verify components that are already installed and configured. Build it after the core installer works.
- **QR code is cheap but high-impact:** Only depends on `qrencode` package and having the tunnel address. Can be added at any phase.

## MVP Definition

### Launch With (V2.0)

Minimum viable product -- what's needed for V2 to be meaningfully better than V1.

- [ ] One-command interactive installer -- handles dependencies, SSH, ngrok, workspace setup in one flow with clear progress
- [ ] Automatic username detection -- zero manual placeholder replacement
- [ ] Project config file -- YAML or simple format, no more editing shell scripts
- [ ] CLI project management -- `ccx add <name> <path>`, `ccx remove <name>`, `ccx list`
- [ ] SSH key-based auth -- generated during install, displayed for Termius setup
- [ ] Health check command -- `ccx doctor` verifies all components
- [ ] Error handling throughout -- every operation validates inputs and reports failures clearly
- [ ] Desktop shortcut automation -- created by installer, no separate PowerShell step
- [ ] Clean uninstall -- `ccx uninstall` reverses everything
- [ ] Mobile tmux mode -- improved from V1, still manual toggle but better defaults

### Add After Validation (V2.x)

Features to add once core is working and real users confirm the value.

- [ ] Auto-detect mobile vs desktop -- switch tmux layout based on terminal width on attach
- [ ] Tunnel auto-reconnect watchdog -- detect ngrok death, restart, update stored address
- [ ] QR code display for phone setup -- scan instead of typing connection details
- [ ] Self-update / version checking -- `ccx update` or startup notification
- [ ] Tunnel provider switching -- `ccx tunnel --provider cloudflare` for stable free URLs
- [ ] Session persistence via systemd/Task Scheduler -- auto-start SSH and workspace on WSL boot

### Future Consideration (V2.5+)

Features to defer until the tool has real usage and the core is solid.

- [ ] Mosh support -- requires non-ngrok tunnel provider, adds complexity
- [ ] Workspace templates -- pre-built configs for common setups
- [ ] Configuration export/import -- backup and restore across machines
- [ ] Cloudflare Tunnel as primary option -- free stable URLs but requires domain ownership and more setup

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| One-command installer | HIGH | MEDIUM | P1 |
| Auto username detection | HIGH | LOW | P1 |
| Project config file + CLI | HIGH | MEDIUM | P1 |
| SSH key-based auth | HIGH | MEDIUM | P1 |
| Health check (`ccx doctor`) | HIGH | MEDIUM | P1 |
| Error handling | HIGH | MEDIUM | P1 |
| Desktop shortcut automation | MEDIUM | LOW | P1 |
| Clean uninstall | MEDIUM | LOW | P1 |
| Mobile tmux mode (manual) | MEDIUM | LOW | P1 |
| Auto-detect mobile/desktop | HIGH | LOW | P2 |
| Tunnel auto-reconnect | HIGH | MEDIUM | P2 |
| QR code for phone setup | MEDIUM | LOW | P2 |
| Self-update mechanism | MEDIUM | LOW | P2 |
| Tunnel provider switching | MEDIUM | MEDIUM | P2 |
| Systemd/auto-start integration | MEDIUM | MEDIUM | P2 |
| Mosh support | LOW | MEDIUM | P3 |
| Workspace templates | LOW | LOW | P3 |
| Config export/import | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for V2 launch (solves V1 pain points)
- P2: Should have, add after V2 core is solid
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | tmuxinator (Ruby) | smug (Go) | tmuxp (Python) | CC x TMUX V2 (Bash) |
|---------|-------------------|-----------|----------------|----------------------|
| Config format | YAML | YAML | YAML/JSON | YAML (simple subset) |
| Session create/start | Yes | Yes | Yes | Yes |
| Session stop/kill | Yes | Yes | Yes | Yes |
| Project list/manage | `list`, `new`, `edit`, `copy`, `delete` | `list`, `edit`, `new`, `rm` | `ls`, `edit` | `add`, `remove`, `list` |
| Session freeze/snapshot | No | No | Yes (freeze to YAML) | No (rebuild from config) |
| Lifecycle hooks | Yes (pre/post window) | Yes (before_start, stop, attach, detach) | Yes (before/after script) | Partial (startup/shutdown) |
| Dependencies | Ruby + gem | None (Go binary) | Python + pip | None (pure bash) |
| SSH tunnel integration | No | No | No | **Yes (core feature)** |
| Mobile optimization | No | No | No | **Yes (auto-detect + mode switch)** |
| Remote access setup | No | No | No | **Yes (SSH + ngrok/tunnel)** |
| Windows/WSL support | Partial (WSL manual) | Partial (WSL manual) | Partial (WSL manual) | **Native WSL focus** |
| One-command install | `gem install` | `go install` or download | `pip install` | `bash install.sh` (guided) |
| Health diagnostics | No | No | No | **Yes (`ccx doctor`)** |
| Desktop shortcut | No | No | No | **Yes (Windows integration)** |
| Non-technical user focus | No (developer tool) | No (developer tool) | No (developer tool) | **Yes (core audience)** |

**Key insight:** tmuxinator, smug, and tmuxp are session managers for developers who already understand tmux. CC x TMUX V2 is a workspace access tool for people who don't want to think about tmux. The competitive advantage is the integrated experience (install + configure + tunnel + phone access) not any single feature.

## Sources

- [tmuxp documentation and comparison](https://tmuxp.git-pull.com/about.html) -- session freeze, YAML/JSON support, CLI features
- [smug GitHub repository](https://github.com/ivaaaan/smug) -- Go-based, YAML config, lifecycle hooks, dependency-free
- [tmuxp vs tmuxinator comparison (Slant)](https://www.slant.co/versus/32439/32440/~tmuxp_vs_tmuxinator) -- community rankings and feature comparison
- [Cloudflare Tunnel vs ngrok vs Tailscale (DEV Community)](https://dev.to/mechcloud_academy/cloudflare-tunnel-vs-ngrok-vs-tailscale-choosing-the-right-secure-tunneling-solution-4inm) -- tunnel provider comparison
- [Top 10 ngrok alternatives 2026 (Pinggy)](https://pinggy.io/blog/best_ngrok_alternatives/) -- free tier limitations, Cloudflare Tunnel as free alternative with stable URLs
- [tmux-resurrect (GitHub)](https://github.com/tmux-plugins/tmux-resurrect) -- session persistence across restarts
- [tmux responsive status bar (Coderwall)](https://coderwall.com/p/trgyrq/make-your-tmux-status-bar-responsive) -- `#{client_width}` for responsive layouts
- [Mosh (mobile shell)](https://mosh.org/) -- UDP-based, roaming support, predictive echo, requires UDP ports
- [chezmoi comparison table](https://www.chezmoi.io/comparison-table/) -- dotfile manager feature comparison
- [Claude Code Remote Control docs](https://code.claude.com/docs/en/remote-control) -- QR code access pattern, session URL approach
- [WSL2 systemd SSH auto-start (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/wsl/systemd) -- systemd support in WSL2
- [SSH into WSL2 guide](https://copyprogramming.com/howto/ssh-into-wsl-from-another-machine-on-the-network) -- mirrored networking, modern WSL2 SSH patterns
- [Termius Android features](https://termius.com/free-ssh-client-for-android) -- SSH key support, Mosh support, terminal autocomplete
- [Harper Reed blog: Claude Code on phone](https://harper.blog/2026/01/05/claude-code-is-better-on-your-phone/) -- real-world mobile Claude Code usage patterns

---
*Feature research for: Terminal workspace / remote dev environment toolkit*
*Researched: 2026-03-20*
