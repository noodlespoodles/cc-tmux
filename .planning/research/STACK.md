# Stack Research

**Domain:** WSL2-based persistent terminal workspace with remote access
**Researched:** 2026-03-20
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| tmux | 3.4+ (apt default on Ubuntu 24.04) | Session multiplexer, persistent workspaces | The foundational tool. V1 already uses it. Ubuntu 24.04 LTS ships tmux 3.4 via apt; 3.6a is latest upstream but apt version is fine for all features we need (mouse, status bar formatting, hooks). No reason to compile from source. |
| OpenSSH Server | 9.x (apt) | Remote access daemon | Already in V1. Standard, battle-tested. WSL2's systemd support means we can `systemctl enable ssh` for auto-start instead of the `sudo -n service ssh start` hack in V1. |
| ngrok | Latest (snap) | TCP tunnel for remote SSH access (default provider) | Keep as default despite limitations. The free tier still supports TCP tunnels (5,000 connections/month, 1GB bandwidth). The address changes on restart, which is annoying but acceptable for a free default. Non-technical users know ngrok; it has the lowest friction onboarding of any tunnel solution. |
| Bash 5.x | System default | All scripts, installer, utilities | Project constraint is bash-only. Bash 5.1+ ships on Ubuntu 22.04/24.04 in WSL2. Provides associative arrays, `readarray`, and other modern features we need. No Python/Node dependency. |
| systemd | WSL2 native | Service management, SSH auto-start | Ubuntu 22.04+ on WSL2 supports systemd via `/etc/wsl.conf` `[boot] systemd=true`. This replaces V1's fragile `sudo -n service ssh start` pattern. The installer should enable systemd if not already enabled and register SSH as a boot service. |

### Tunnel Provider Strategy

The V2 approach should be a **pluggable tunnel architecture** with ngrok as the default but easy switching to alternatives. Here is the evaluation:

| Provider | Free Tier | Persistent Address | Install Complexity | Recommendation |
|----------|-----------|-------------------|-------------------|----------------|
| **ngrok** | Yes (1GB/mo, 5K TCP conn) | No (random on restart) | Low (snap install + auth token) | **Default provider.** Most accessible for beginners. |
| **Tailscale** | Yes (100 devices, 3 users) | Yes (stable Tailscale IP) | Medium (install on Windows host + phone app) | **Recommended upgrade.** Eliminates tunnel address churn entirely. Stable IPs. But requires running on Windows host, NOT in WSL2 (MTU issues). Phone needs Tailscale app installed. |
| **Pinggy** | Yes (60-min sessions) | No (free) / Yes ($2.50/mo) | Very low (single SSH command, no install) | **Fallback option.** Zero-install tunnel via SSH. Good for quick testing but 60-min timeout on free tier is painful for persistent workspaces. |
| **Cloudflare Tunnel** | Yes (unlimited bandwidth) | Yes (with domain) | High (needs Cloudflare account, domain, cloudflared on both ends) | **Do not use.** TCP tunneling requires cloudflared on both client and server. Users would need cloudflared on their phone, which defeats the "use Termius on Android" requirement. |
| **bore** | Self-hosted only | N/A (needs your server) | High (need a public server to run bore server) | **Do not use.** Requires self-hosted server, antithetical to non-technical target audience. |

**Architecture decision:** The tunnel layer should be a single bash file (e.g., `tunnel.sh`) that sources a provider-specific module (e.g., `tunnels/ngrok.sh`, `tunnels/tailscale.sh`). The installer asks which provider to use. This isolates tunnel logic and makes adding providers trivial.

**Confidence:** HIGH -- verified ngrok free tier limits against official docs (March 2026), Tailscale WSL2 MTU issue confirmed via official Tailscale docs, Cloudflare TCP requirement confirmed via official docs.

### SSH Security Stack

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Ed25519 SSH keys | OpenSSH 9.x | Key-based authentication | Ed25519 is the current standard (2025+). Smaller keys, faster operations, stronger security than RSA. The installer should generate a key pair and offer to copy the public key to the user's phone (display QR code or copyable text). |
| `sshd_config.d/` drop-in | OpenSSH 8.2+ | Modular SSH configuration | V1 already uses this pattern (`/etc/ssh/sshd_config.d/workspace.conf`). Keep it -- it avoids clobbering the main sshd_config. V2 should harden the config significantly (see below). |
| fail2ban | apt | Brute force protection | Defense in depth. Even with key-only auth, fail2ban reduces log noise and blocks scanners. Lightweight, zero-maintenance after setup. Configure to ban after 3 failed attempts for 1 hour. |

**V2 SSH Config (drop-in file):**
```
# /etc/ssh/sshd_config.d/workspace.conf
Port 22
ListenAddress 0.0.0.0
Protocol 2

# Authentication
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30

# Security
X11Forwarding no
AllowTcpForwarding yes
PermitEmptyPasswords no
ClientAliveInterval 120
ClientAliveCountMax 3
```

**Key change from V1:** V1 uses `PasswordAuthentication yes`, which is insecure when exposed via tunnel. V2 must default to key-only auth. The installer generates keys and guides the user through copying the public key to their phone.

**Confidence:** HIGH -- SSH hardening best practices verified across multiple authoritative sources (DigitalOcean, Linuxize, official OpenSSH docs).

### tmux Configuration Stack

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| TPM (tmux Plugin Manager) | Latest (git clone) | Plugin management | Enables tmux-resurrect and tmux-continuum without manual management. Auto-installs itself on first tmux launch if not present. |
| tmux-resurrect | Latest (via TPM) | Session state persistence across restarts | Saves window/pane layout, working directories, and running programs. Critical for V2 because WSL2 instances can be shut down by Windows. Without this, users lose their workspace state. |
| tmux-continuum | Latest (via TPM) | Automatic session saving | Saves state every 15 minutes automatically. Combined with resurrect, this means the workspace survives WSL restarts, Windows reboots, and crashes. |

**tmux Mobile Auto-Detection Strategy:**

V1 requires manual `Ctrl+B, Shift+M` to toggle mobile mode. V2 should auto-detect.

The approach: Use a tmux hook on `client-attached` that checks `#{client_width}`. If width is below a threshold (e.g., 80 columns), apply mobile-optimized settings automatically. This works because Termius on a phone reports realistic column counts (typically 40-60 columns on a phone screen).

```bash
# In tmux.conf -- auto-detect mobile vs desktop on attach
set-hook -g client-attached 'run-shell "~/.cc-tmux/scripts/detect-device.sh"'
```

The `detect-device.sh` script reads `tmux display-message -p '#{client_width}'` and applies mobile or desktop status bar formatting accordingly.

**Confidence:** HIGH -- `#{client_width}` format string verified in tmux man page, hook mechanism is stable since tmux 2.4.

### Supporting Utilities

| Utility | Purpose | When to Use |
|---------|---------|-------------|
| `cmd.exe /C "echo %USERNAME%"` | Detect Windows username from WSL | During installation. V1 already does this but with no fallback validation. V2 should validate the result and offer manual entry if detection fails. |
| `wslpath` | Convert between Windows and WSL paths | Convert detected Windows paths to `/mnt/c/Users/...` format for project directories. Built into WSL2, no install needed. |
| `wslvar` (from `wslu`) | Read Windows environment variables cleanly | Alternative to `cmd.exe` hack. `wslvar USERNAME` is cleaner than piping cmd.exe output through `tr -d '\r'`. Install via `sudo apt install wslu`. |
| ShellCheck | Static analysis for bash scripts | During development. All V2 scripts must pass ShellCheck. Catches common bash pitfalls (unquoted variables, missing error handling, POSIX compliance issues). |
| `jq` | JSON parsing | Parse ngrok API response (`curl localhost:4040/api/tunnels`). V1 uses fragile grep/regex. V2 should use `jq '.tunnels[0].public_url'` for reliable parsing. |
| `qrencode` | Generate QR codes in terminal | Display SSH connection details as a QR code that users can scan with their phone camera to auto-populate Termius connection settings. Nice UX touch. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| ShellCheck | Bash linting | Run `shellcheck *.sh` before every commit. Catches unquoted variables, unused variables, deprecated syntax, and security issues. CI should enforce this. |
| `set -euo pipefail` | Bash strict mode | All scripts must use this. `set -e` exits on error, `set -u` catches undefined variables, `set -o pipefail` catches pipe failures. Combined with an ERR trap for debugging. |
| GitHub Actions | CI/CD | Lint all shell scripts with ShellCheck on every push. Run on `ubuntu-latest` to validate install script in clean environment. |

## Installation Architecture

The V1 installer copies scripts to `~/` (home directory). This is messy and pollutes the home folder. V2 should follow better conventions:

```
~/.cc-tmux/                    # XDG-inspired, single directory
  config.env                   # User settings (Windows username, tunnel provider, projects list)
  scripts/
    install.sh                 # Main installer (idempotent, re-runnable)
    startup.sh                 # Start SSH + tunnel + workspace
    attach.sh                  # Attach to existing workspace
    workspace.sh               # Create/manage tmux workspace
    tunnel.sh                  # Tunnel abstraction layer
    detect-device.sh           # Mobile/desktop auto-detection
    health.sh                  # Diagnostics and health check
    uninstall.sh               # Clean removal
  tunnels/
    ngrok.sh                   # ngrok-specific tunnel logic
    tailscale.sh               # Tailscale-specific tunnel logic
  tmux.conf                    # Generated tmux configuration
```

**Why not `~/.config/cc-tmux/`?** Because tmux sources its config from `~/.tmux.conf` by default, and this tool's scripts need to be on `$PATH` or called directly. Using `~/.cc-tmux/` keeps everything together, is discoverable, and avoids XDG compliance complexity that adds no value for this use case.

**The installer should be idempotent.** Running it twice should produce the same result. Every step checks whether its effect is already present before executing. Pattern:
```bash
install_package() {
    if command -v "$1" &>/dev/null; then
        echo "  [ok] $1 already installed"
    else
        sudo apt install -y "$1"
    fi
}
```

### Installer Script Pattern

The installer uses a numbered-step architecture with these phases:

1. **Preflight checks** -- Verify running in WSL2 (check `/proc/version` for Microsoft), verify bash version, verify sudo access
2. **Dependency installation** -- apt packages (tmux, openssh-server, jq, fail2ban, wslu), snap packages (ngrok if chosen)
3. **Auto-detection** -- Windows username, WSL distro name, default shell
4. **Interactive configuration** -- Tunnel provider choice, project directories (with add/remove UX), SSH key generation
5. **File deployment** -- Generate config files from templates, deploy scripts to `~/.cc-tmux/`
6. **Service setup** -- Enable systemd, configure SSH, configure fail2ban, set up auto-attach in `.bashrc`
7. **Verification** -- Run health check to confirm everything works
8. **Post-install guidance** -- Display connection info, offer to create Windows desktop shortcut

Each step prints `[1/8]` progress indicators (like V1 does well) and uses color output for status (`green` = success, `yellow` = warning, `red` = error).

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| ngrok (default tunnel) | Tailscale | When user wants persistent addresses and is willing to install Tailscale app on phone. Recommended as upgrade path, not default. |
| Ed25519 keys | RSA 4096 keys | Never. Ed25519 is universally supported since OpenSSH 6.5 (2014). Every modern SSH client including Termius supports it. |
| TPM for tmux plugins | Manual plugin install | Never. TPM auto-installs itself with 2 lines in tmux.conf and handles updates. Manual install is fragile. |
| `~/.cc-tmux/` directory | `~/.config/cc-tmux/` (XDG) | If the tool grows to multiple config files. For now, XDG adds complexity without benefit. |
| `jq` for JSON parsing | `grep -oP` regex | Never. V1's regex parsing of ngrok API is fragile. `jq` is a 1MB apt package that handles JSON correctly. |
| systemd service management | `sudo -n service` hack | Never (on systemd-capable WSL2). The V1 pattern requires a sudoers entry and is fragile. systemd is the correct approach on modern WSL2. |
| Bash 5.x strict mode | Loose bash scripting | Never. All V2 scripts must use `set -euo pipefail` and ERR trap. The V1 scripts have `set -e` only, which misses pipe failures and undefined variables. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Cloudflare Tunnel for TCP/SSH | Requires `cloudflared` on BOTH endpoints. Users would need to install cloudflared on their Android phone, which is not practical. Great for HTTP tunnels, wrong tool for SSH-to-phone. | ngrok or Tailscale |
| bore / rathole / chisel | All require self-hosted server infrastructure. Target audience is non-technical Windows users, not sysadmins. | ngrok (hosted, free tier) |
| Zrok | Impressive technology but requires self-hosting the server component or using their hosted service with more complex setup than ngrok. Overkill for tunneling port 22. | ngrok |
| Password SSH authentication | V1 uses `PasswordAuthentication yes`. When exposed through a public ngrok tunnel, this is a brute-force target. Even with fail2ban, key-only auth is the correct baseline. | Ed25519 key-based auth |
| RSA SSH keys | Slower, larger keys, no security advantage over Ed25519 in practice. Legacy choice. | Ed25519 |
| Compiling tmux from source | Ubuntu 24.04 ships tmux 3.4 via apt. The 3.6a features (scrollbars, theme mode) are nice-to-have but not needed. Compiling adds install complexity for non-technical users. | `apt install tmux` |
| Python/Node installer wrappers | Project constraint is bash-only. Adding a Python or Node dependency to run the installer defeats the "minimal dependencies" goal. Bash is sufficient for interactive installers. | Pure bash with `read`, `select`, color codes |
| Docker/containers | Adds massive complexity. The whole point is running Claude Code natively in WSL2 with access to Windows filesystem. Docker would isolate from `/mnt/c/`. | Direct WSL2 installation |
| `screen` instead of tmux | Less featureful, worse status bar customization, no plugin ecosystem, no mouse support by default. tmux is the modern standard. | tmux |
| Copying scripts to `~/` | V1 pattern. Pollutes home directory with `startup.sh`, `attach.sh`, `port.sh`, `workspace-init.sh`. Messy, no version tracking, conflicts with other tools. | `~/.cc-tmux/` directory structure |
| Manual `YOURUSERNAME` replacement | V1 requires users to edit files and replace a placeholder. Error-prone, bad UX. | Auto-detect with `wslvar USERNAME` or `cmd.exe /C "echo %USERNAME%"` with validation |

## Stack Patterns by Variant

**If user has Tailscale already:**
- Skip ngrok entirely
- Use Tailscale IP for SSH (persistent, no port changes)
- Simpler startup script (no tunnel management needed)
- Phone connects via Tailscale app + Termius pointed at Tailscale IP

**If user is on Ubuntu 22.04 LTS:**
- systemd may need manual enabling (`/etc/wsl.conf` `[boot] systemd=true`)
- tmux may be 3.2 via apt (still sufficient for all V2 features)
- fail2ban is available and works identically

**If user is on Ubuntu 24.04 LTS:**
- systemd is likely enabled by default
- tmux 3.4 via apt
- All features work out of the box

**If ngrok free tier becomes too restrictive:**
- The pluggable tunnel architecture allows swapping providers without touching other scripts
- Pinggy is the easiest migration (single SSH command, no binary install)
- Tailscale is the best long-term solution (persistent IPs, no bandwidth limits)

## Version Compatibility

| Component | Minimum Version | Tested With | Notes |
|-----------|-----------------|-------------|-------|
| WSL2 | 1.0+ with systemd support | WSL2 on Win11 | systemd requires WSL 0.67.6+. Check with `wsl --version`. |
| Ubuntu | 22.04 LTS | 22.04, 24.04 | Both work. 24.04 preferred for newer tmux/openssh. |
| tmux | 3.2+ | 3.4 (Ubuntu 24.04 apt) | Hooks, mouse support, format strings all stable since 3.2. |
| OpenSSH | 8.2+ | 9.x (Ubuntu 24.04 apt) | Ed25519 support, `sshd_config.d/` drop-in dirs. |
| ngrok | Latest snap | March 2026 | Free tier limits: 1GB/mo, 5K TCP connections. |
| Bash | 5.0+ | 5.2 (Ubuntu 24.04) | Associative arrays, `readarray`, modern string operations. |
| Termius (Android) | Latest Play Store | March 2026 | Ed25519 key import, SSH tunnel support confirmed. |
| jq | 1.6+ | 1.7 (Ubuntu 24.04 apt) | Stable, no known compat issues. |
| fail2ban | 0.11+ | 1.0+ (Ubuntu 24.04 apt) | systemd journal integration. |

## Sources

- [ngrok Free Plan Limits](https://ngrok.com/docs/pricing-limits/free-plan-limits) -- verified TCP tunnel availability and exact limits (HIGH confidence)
- [ngrok Pricing](https://ngrok.com/pricing) -- confirmed no static domains on free tier (HIGH confidence)
- [Tailscale WSL2 Install Guide](https://tailscale.com/docs/install/windows/wsl2) -- confirmed MTU issues, recommendation to run on Windows host only (HIGH confidence)
- [Tailscale SSH Docs](https://tailscale.com/docs/features/tailscale-ssh) -- confirmed free plan includes SSH, 100 devices (HIGH confidence)
- [Scott Hanselman - Tailscale + WSL2](https://www.hanselman.com/blog/using-tailscale-on-windows-to-network-more-easily-with-wsl2-and-visual-studio-code) -- practical setup for SSH into WSL2 via Tailscale on Windows host (MEDIUM confidence, 2022 article but approach still valid)
- [Pinggy](https://pinggy.io/) -- verified 60-min free tier timeout, $2.50/mo for persistent addresses (MEDIUM confidence)
- [tmux GitHub Releases](https://github.com/tmux/tmux/releases) -- confirmed 3.6a latest, 3.4 on Ubuntu 24.04 apt (HIGH confidence)
- [tmux-plugins/tpm](https://github.com/tmux-plugins/tpm) -- auto-install pattern confirmed (HIGH confidence)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) -- session persistence features confirmed (HIGH confidence)
- [tmux-plugins/tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) -- 15-min auto-save, auto-restore on start confirmed (HIGH confidence)
- [SSH Ed25519 Best Practices 2025](https://www.brandonchecketts.com/archives/ssh-ed25519-key-best-practices-for-2025) -- Ed25519 as current standard confirmed (HIGH confidence)
- [SSH Hardening - Linuxize](https://linuxize.com/post/ssh-hardening-best-practices/) -- sshd_config hardening patterns (HIGH confidence)
- [SSH Hardening - DigitalOcean](https://www.digitalocean.com/community/tutorials/hardening-ssh-fail2ban) -- fail2ban configuration patterns (HIGH confidence)
- [Idempotent Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) -- idempotent installer patterns (HIGH confidence)
- [Bash Best Practices - Shell Script](https://sharats.me/posts/shell-script-best-practices/) -- strict mode, error handling patterns (HIGH confidence)
- [ShellCheck](https://github.com/koalaman/shellcheck) -- bash linting tool (HIGH confidence)
- [WSL2 systemd - Microsoft](https://learn.microsoft.com/en-us/windows/wsl/systemd) -- systemd enablement via wsl.conf (HIGH confidence)
- [awesome-tunneling](https://github.com/anderspitman/awesome-tunneling) -- comprehensive tunnel comparison list (MEDIUM confidence, community-maintained)

---
*Stack research for: WSL2-based persistent terminal workspace with remote access*
*Researched: 2026-03-20*
