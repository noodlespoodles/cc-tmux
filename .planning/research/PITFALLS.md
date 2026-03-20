# Pitfalls Research

**Domain:** WSL2/tmux/SSH remote access toolkit with bash installer
**Researched:** 2026-03-20
**Confidence:** HIGH (most pitfalls verified against V1 code, WSL GitHub issues, and official docs)

## Critical Pitfalls

### Pitfall 1: Snap Does Not Work on WSL2 Without Systemd

**What goes wrong:**
The V1 installer uses `sudo snap install ngrok`, which fails on most WSL2 installations. Snap requires systemd as PID 1, and many WSL2 setups either don't have systemd enabled or are running on Windows 10 where systemd support requires manual opt-in via `/etc/wsl.conf`. The installer hits an error and either hangs or exits, leaving ngrok uninstalled with no fallback.

**Why it happens:**
WSL2 historically ran without systemd. Microsoft added systemd support (requiring `[boot] systemd=true` in `/etc/wsl.conf`), but it's not on by default in all distributions and is not universally reliable. Snap is tightly coupled to systemd's socket activation.

**How to avoid:**
Use the ngrok apt repository or direct binary download instead of snap. The binary method is the most reliable:
```bash
curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
  | sudo tar xz -C /usr/local/bin
```
Detect the installation method at runtime: check if snap works, fall back to apt, fall back to binary download.

**Warning signs:**
- `snap install` hangs or prints "System has not been booted with systemd as init system"
- User reports "ngrok not found" after install completes

**Phase to address:**
Installer phase (core). This must be fixed before any user touches the tool.

---

### Pitfall 2: `cmd.exe /C` Interop Can Hang Indefinitely

**What goes wrong:**
The V1 installer runs `cmd.exe /C "echo %USERNAME%"` to detect the Windows username. This call can hang for 10-40 seconds or freeze indefinitely. WSL2's Windows interop (`/mnt/c/Windows/system32/cmd.exe`) sometimes becomes unresponsive, especially shortly after WSL boots, during heavy I/O, or when antivirus software intercepts the cross-VM call. The installer appears frozen with no feedback.

**Why it happens:**
WSL2 runs as a lightweight Hyper-V VM. Calling Windows executables requires cross-VM communication through the 9P protocol and WSL interop layer. This path is fragile -- it can break after `wsl --shutdown`, during Windows Updates, or when security software intervenes. PowerShell is even worse (0.3s for `cmd.exe` vs 2-5s+ for `powershell.exe` cold start).

**How to avoid:**
1. Set a timeout on the interop call: `timeout 5 cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r'`
2. Have multiple fallbacks: parse `/mnt/c/Users/` directory listing, check `$LOGNAME`, ask interactively as last resort
3. Cache the result so it's only detected once (write to a config file)
4. Never use `powershell.exe` for simple operations -- `cmd.exe` is 10x faster

**Warning signs:**
- Installer appears to hang at the "detecting username" step
- Users report needing to Ctrl+C and restart the installer

**Phase to address:**
Installer phase (core). Username detection is the first thing that runs.

---

### Pitfall 3: ngrok Free Tier 2-Hour Session Limit and Random URLs

**What goes wrong:**
As of 2026, ngrok free tier limits TCP tunnel sessions to 2 hours with 1GB/month bandwidth. After 2 hours, the tunnel dies silently -- the SSH connection drops, the user's phone disconnects, and there's no notification. The tunnel URL also changes on every restart (including after the 2-hour timeout), so the user must manually update their Termius connection settings on their phone every time.

**Why it happens:**
ngrok progressively tightened free tier restrictions. The V1 project was designed when free tier was more generous. A non-technical user who walks away from their PC expecting to connect from their phone hours later will find a dead tunnel with no explanation.

**How to avoid:**
1. Build a tunnel health monitor that detects when the tunnel dies and auto-restarts it
2. Display the new URL prominently after restart (push notification is ideal but complex)
3. Implement a wrapper script that polls `localhost:4040/api/tunnels` and reconnects on failure
4. Document the limitation clearly during setup
5. Consider supporting alternatives: Cloudflare Tunnel (free, no session limits, no bandwidth caps but more complex setup) or SSH-based tunnels like Pinggy/localhost.run (single command, no install)
6. For paid ngrok users, support static domains via config

**Warning signs:**
- Users report "SSH stopped working after a while"
- Phone can't connect but PC workspace is fine
- ngrok log shows "session closed, remote gone away"

**Phase to address:**
Tunnel management phase. The auto-reconnect wrapper is critical for usability. Alternative tunnel support can come in a later hardening phase.

---

### Pitfall 4: SSH Service Doesn't Survive WSL2 Restarts

**What goes wrong:**
WSL2 doesn't persist running services between sessions. When the user reboots Windows, runs `wsl --shutdown`, or the WSL2 VM is reclaimed by Windows for memory, the SSH server stops. The user launches their workspace shortcut expecting everything to work, but phone access is broken because SSH isn't running. Even with systemd enabled, the SSH service may not auto-start reliably due to WSL-specific systemd issues.

**Why it happens:**
WSL2 is not a full VM -- it's a managed lightweight VM that can be started and stopped by Windows. Services started with `service ssh start` are ephemeral. Systemd support in WSL2 is still maturing and has documented issues with unit startup failures (WSL GitHub issues #11822, #11690).

**How to avoid:**
1. The startup script must always start SSH as its first action (V1 does this correctly with `sudo -n service ssh start`)
2. The sudoers NOPASSWD entry for SSH service control is essential (V1 has this)
3. Don't rely on systemd `enable` -- use the startup script as the source of truth
4. Add a health check: verify SSH is actually listening on port 22 after starting it
5. Consider adding SSH startup to `.bashrc` for interactive sessions as a belt-and-suspenders approach

**Warning signs:**
- `sudo service ssh status` shows "not running" after opening WSL
- Port 22 not listening: `ss -tlnp | grep :22` returns nothing
- ngrok tunnel connects but SSH connection refused

**Phase to address:**
Core infrastructure phase. SSH must be bulletproof before tunnel setup makes sense.

---

### Pitfall 5: Windows Line Endings (CRLF) in Shell Scripts

**What goes wrong:**
If a user clones the repo on Windows (via Git for Windows with default settings), all `.sh` files get CRLF line endings. Running them in WSL produces cryptic errors: `bash: ./install.sh: /bin/bash^M: bad interpreter: No such file or directory`. The `^M` (carriage return) is invisible in most editors, making the error baffling to non-technical users.

**Why it happens:**
Git for Windows defaults to `core.autocrlf=true`, converting LF to CRLF on checkout. The scripts are fine in the repo (LF), but broken on disk after clone. This is the single most common "it doesn't work" report for any bash-script-based project targeting Windows users.

**How to avoid:**
1. Add a `.gitattributes` file to the repo: `*.sh text eol=lf` and `*.conf text eol=lf`
2. As a safety net, have the installer self-heal: `sed -i 's/\r$//' "$0"` at the top of the entry script
3. Include `dos2unix` as a dependency or inline the conversion
4. Document in README: "Clone inside WSL, not Windows Explorer"

**Warning signs:**
- User reports `/bin/bash^M: bad interpreter`
- `cat -A script.sh` shows `^M$` at line endings
- Scripts work for the developer but fail for users

**Phase to address:**
Repository setup (pre-installer). The `.gitattributes` file should be committed before any user clones.

---

### Pitfall 6: Claude Code Crashes on Mobile Terminal (Termius Android)

**What goes wrong:**
Claude Code's TUI (built on Ink/React) crashes or renders garbage when used over SSH on mobile terminals. The crash occurs in rendering code that handles syntax highlighting and terminal formatting, which is sensitive to terminal dimensions and capabilities. Specifically: the terminal sends resize events as the soft keyboard appears/disappears, Ink's internal render state gets corrupted, and text overlaps/overwrites itself. Neither Ctrl+L nor tmux redraw fixes it because the corruption is in Ink's virtual buffer, not the terminal's.

**Why it happens:**
Mobile terminals have different TERM capabilities, smaller/variable screen widths, and aggressive background app killing. Termius on Android has historically had tmux compatibility issues (incorrect TTY behavior). Claude Code's streaming output generates 4,000-6,700 scroll events per second inside tmux, causing severe jitter.

**How to avoid:**
1. Set `TERM=xterm-256color` or `TERM=tmux-256color` explicitly in the SSH session
2. Configure tmux terminal overrides: `set -as terminal-overrides ",*:RGB"`
3. Use `set -sg escape-time 0` to reduce input lag on mobile
4. Document that Claude Code mobile is "usable but imperfect" -- set expectations
5. The mobile tmux mode should minimize status bar to maximize screen real estate
6. Consider adding `stty rows X cols Y` presets for common phone screens
7. Recommend users run `claude --no-animation` or similar flags if available

**Warning signs:**
- Users report "screen goes crazy" or "text overlaps" on phone
- Claude Code exits immediately after starting on mobile SSH
- Garbled output that survives tmux redraw

**Phase to address:**
Mobile optimization phase. This is a known upstream limitation that can only be mitigated, not fully solved. Set expectations early.

---

### Pitfall 7: Non-Idempotent Installer Breaks on Re-run

**What goes wrong:**
The V1 installer appends to `.bashrc` without checking if the content already exists (it does check, but only for one marker). If something goes wrong mid-install and the user re-runs it, they could get duplicate PATH entries, duplicate auto-attach blocks, conflicting SSH configs, or sed replacements that mangle already-replaced values (running `sed -i "s/YOURUSERNAME/$WIN_USER/g"` on a file where YOURUSERNAME was already replaced does nothing, but the user thinks it updated).

**Why it happens:**
Bash scripts are procedural by default. Making every operation idempotent requires explicit guard checks that are easy to forget. Non-technical users will absolutely re-run the installer when something seems wrong.

**How to avoid:**
1. Every file write must be preceded by a check: does this content already exist?
2. Use sentinel markers in files: `# MANAGED BY CC-TMUX - DO NOT EDIT` blocks
3. For config files, write the entire file rather than appending (overwrite is naturally idempotent)
4. For `.bashrc`, use grep to check for the marker before appending
5. Test the installer by running it 3 times in a row -- the result should be identical to running it once
6. Store installation state in a config file (`~/.cc-tmux/config`) to track what's been done

**Warning signs:**
- `.bashrc` has duplicate blocks
- tmux.conf has conflicting settings
- SSH config has duplicate `ListenAddress` directives
- Users report "I ran install again and now it's broken"

**Phase to address:**
Installer phase (core). Every installation step must be idempotent from day one.

---

### Pitfall 8: SSH with Password-Only Auth Exposed via Public Tunnel

**What goes wrong:**
V1 configures SSH with `PasswordAuthentication yes` and exposes port 22 through ngrok to the public internet. Anyone who discovers the ngrok URL (they're enumerable and short-lived but public) can attempt brute-force password attacks against the WSL user account. WSL default passwords are often simple, and there's no rate limiting or fail2ban configured.

**Why it happens:**
Password auth is the easiest to set up and explain to non-technical users. Key-based auth requires file transfers between devices, which is a UX hurdle. The V1 installer prioritized getting it working over hardening it.

**How to avoid:**
1. Default to key-based authentication and generate keys during install
2. Display the public key / provide a QR code for easy phone transfer
3. If password auth is kept as fallback, implement `fail2ban` or equivalent
4. Use `MaxAuthTries 3` and `LoginGraceTime 30` in sshd_config
5. Consider `AllowUsers` directive to restrict to only the WSL user
6. Add SSH key setup as a guided step in the installer with clear instructions for Termius
7. At minimum, warn users to use strong passwords if they stick with password auth

**Warning signs:**
- `/var/log/auth.log` shows failed login attempts from unknown IPs
- `lastb` shows brute-force patterns
- User's WSL account has a simple password like their first name

**Phase to address:**
SSH security phase. This should be addressed early -- before the tool is shared publicly. At minimum, the installer should prompt for a strong password and configure basic hardening.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoded paths like `/mnt/c/Users/` | Simple implementation | Breaks for users with non-standard Windows drive letters or custom mount points | MVP only -- parameterize in v2 |
| Copying scripts to `~/` instead of `~/.cc-tmux/bin/` | Simpler install | Clutters home directory, hard to uninstall cleanly, naming conflicts | Never -- use a dedicated directory from the start |
| `pkill ngrok` before restart | Ensures clean tunnel | Kills ALL ngrok processes including unrelated ones | MVP only -- use PID file tracking |
| `sleep 3` after ngrok start | Gives ngrok time to establish tunnel | Unreliable on slow connections, wastes time on fast ones | MVP only -- poll the API endpoint instead |
| Using `nohup` for ngrok backgrounding | Quick daemonization | No automatic restart, no log rotation, no proper supervision | MVP only -- use a proper process monitor loop |
| `sed -i "s/YOURUSERNAME/$WIN_USER/g"` templating | Fast to implement | Breaks if username contains `/` or `&`, not reversible, fails if already replaced | Never -- use a config file that scripts source at runtime |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ngrok API (`localhost:4040`) | Querying immediately after start; API not ready yet | Poll with retry: `until curl -sf localhost:4040/api/tunnels; do sleep 1; done` with timeout |
| ngrok API (`localhost:4040`) | Using `grep -oP` (Perl regex) which isn't available on all systems | Use `python3 -c` or `jq` for JSON parsing, or basic grep with POSIX patterns |
| Termius on Android | Assuming it supports all terminal escape sequences | Test with Termius specifically; it has known tmux rendering issues. Set TERM correctly |
| WSL2 filesystem (`/mnt/c/`) | Treating it like native Linux filesystem for permissions/performance | Linux-native operations belong in `~/` or `/home/`. Only use `/mnt/c/` for accessing project files |
| Windows desktop shortcut | Using `wsl.exe -e bash -c "~/startup.sh"` which may not find the right distro | Specify distro explicitly: `wsl.exe -d Ubuntu -e bash -c "~/startup.sh"` |
| Git on Windows files | Running git inside WSL on `/mnt/c/` mounted files | Performance is 5-10x slower than native. Let Windows Git handle Windows files, WSL Git handle WSL files |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| ngrok tunnel latency for SSH | Noticeable keystroke delay on mobile, 100-300ms added round-trip | Choose ngrok region closest to user; consider alternatives with lower overhead | Always present on free tier; worse on congested networks |
| WSL2 `/mnt/c/` filesystem performance | Slow `git status`, slow file operations, Claude Code feels sluggish | Keep working files in WSL2 native filesystem (`~/projects/`), symlink if needed | >50 files in directory tree |
| `history-limit 50000` in tmux | Memory usage grows over long Claude Code sessions with heavy output | Set reasonable limit (10000-20000), or implement periodic history clearing | After hours of Claude Code streaming output |
| Polling ngrok API in a tight loop | CPU usage spikes, ngrok API rate limiting | Poll at 30-60 second intervals, use exponential backoff on failure | Continuous monitoring |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Password auth + public tunnel | Brute-force attacks against WSL user account via the internet | Default to key-based auth; if passwords kept, use fail2ban + strong password enforcement |
| SSH host keys regenerated on every install | Man-in-the-middle warnings on reconnect, users trained to ignore them | Generate host keys only if they don't exist (`ssh-keygen -A` already does this, but check first) |
| ngrok auth token stored in plain text | Token compromise allows attacker to create tunnels on your account | Store in config file with `600` permissions; warn user not to commit `.ngrok2/` directory |
| sudoers NOPASSWD for SSH service | Broad `service ssh *` allows stop/start/restart by any process | Restrict to exactly needed commands: `NOPASSWD: /usr/sbin/service ssh start, /usr/sbin/service ssh restart` |
| No firewall rules within WSL | Other services (dev servers, databases) potentially exposed through tunnel | Only tunnel port 22; add iptables rules to restrict what's accessible |
| Sensitive data in tmux scrollback | SSH session scrollback may contain API keys, passwords typed in terminal | Set reasonable `history-limit`; consider `set-option -g history-file ""` to prevent scrollback persistence |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Error messages assume Linux knowledge | "Permission denied" or "command not found" means nothing to target audience | Translate errors: "SSH couldn't start. This usually means..." with specific fix instructions |
| Installer requires editing a file manually after setup | Users skip it, workspace has dummy projects, they think it's broken | Interactive project setup during install: "Enter path to your first project:" |
| ngrok URL changes require manual Termius update | Phone access breaks after every reboot with no fix the user understands | Display URL change prominently; consider clipboard/QR code; explore stable tunnel options |
| Mobile/Desktop mode toggle requires knowing tmux prefix key | Non-technical users don't know what Ctrl+B is, will never discover the toggle | Auto-detect screen width and switch modes; document the toggle with a cheat card |
| No feedback during long operations | User thinks installer is frozen during `apt update` or ngrok startup | Show spinners/progress bars; print what's happening at each step |
| Silent failures in startup script | Workspace appears to start but SSH or ngrok isn't actually running | Verify each service after starting; print clear status: "SSH: OK / ngrok: FAILED (reason)" |

## "Looks Done But Isn't" Checklist

- [ ] **Installer:** Often missing idempotency -- verify running it twice produces the same result as once
- [ ] **SSH config:** Often missing key-based auth -- verify `PubkeyAuthentication yes` is set and keys are generated
- [ ] **ngrok tunnel:** Often missing auto-reconnect -- verify tunnel restores after `pkill ngrok && sleep 5`
- [ ] **Desktop shortcut:** Often missing distro specification -- verify it opens the right WSL distro when multiple are installed
- [ ] **tmux config:** Often missing TERM override -- verify `echo $TERM` inside tmux shows `tmux-256color` not `screen`
- [ ] **File permissions:** Often missing `.gitattributes` -- verify `.sh` files have LF endings after fresh Windows clone
- [ ] **Uninstaller:** Often missing entirely -- verify clean removal of all config, scripts, sudoers entries, and bashrc modifications
- [ ] **Health check:** Often missing SSH verification -- verify SSH is listening, not just started (`ss -tlnp | grep :22`)
- [ ] **Windows 10 support:** Often assumes Windows 11 features -- verify mirrored networking is not required (it's Win11-only)
- [ ] **Multiple WSL distros:** Often assumes single distro -- verify shortcut targets the correct distribution

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CRLF line endings | LOW | Run `sed -i 's/\r$//' *.sh` or install `dos2unix` and run on all scripts |
| Broken SSH config | LOW | Delete `/etc/ssh/sshd_config.d/workspace.conf`, re-run SSH setup portion of installer |
| ngrok token lost/expired | LOW | Re-run `ngrok config add-authtoken NEW_TOKEN` |
| Duplicate .bashrc entries | LOW | Manually edit `~/.bashrc`, remove duplicate blocks between sentinel comments |
| Non-idempotent install corruption | MEDIUM | Run uninstaller (if exists), then fresh install. Without uninstaller: manually clean `~/startup.sh`, `~/attach.sh`, `~/.tmux.conf`, `.bashrc` additions, sudoers entry |
| SSH brute-force compromise | HIGH | Change WSL password immediately, rotate SSH host keys, check `~/.ssh/authorized_keys` for foreign keys, review `history` for unauthorized commands, revoke ngrok token |
| Claude Code render corruption | LOW | Detach tmux (`Ctrl+B, d`), run `tmux kill-session -t work`, re-run workspace init. Or `reset` terminal within tmux |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Snap fails on WSL2 | Installer core | `which ngrok` succeeds on fresh WSL2 without systemd |
| `cmd.exe` hang | Installer core | Username detection completes within 5 seconds or falls back gracefully |
| ngrok 2-hour limit | Tunnel management | Tunnel auto-restarts after simulated kill; new URL is displayed |
| SSH doesn't survive restart | Core infrastructure | After `wsl --shutdown && wsl`, SSH is running within 10 seconds of startup script |
| CRLF line endings | Repository setup | Fresh `git clone` on Windows, `file install.sh` shows "POSIX shell script" not "with CRLF" |
| Claude Code mobile crash | Mobile optimization | Claude Code starts and renders on Termius Android without immediate crash |
| Non-idempotent installer | Installer core | `bash install.sh && bash install.sh` produces identical system state |
| SSH password brute-force | SSH security | `sshd_config` shows key-based auth preferred, fail2ban installed or MaxAuthTries set |
| `cmd.exe` interop freeze | Installer core | Installer detects username on Windows 10 and 11 within 10 seconds |
| Stale TERM variable | tmux configuration | `echo $TERM` inside tmux over SSH shows correct value; colors render properly |

## Sources

- [WSL2 SSH issues -- microsoft/WSL GitHub issues #5755, #4690](https://github.com/microsoft/WSL/issues/5755)
- [WSL2 systemd issues -- microsoft/WSL #11822, #11690, #13540](https://github.com/microsoft/WSL/issues/11822)
- [WSL2 cmd.exe interop hangs -- microsoft/WSL #7371](https://github.com/microsoft/WSL/issues/7371)
- [Claude Code WSL2 freeze -- anthropics/claude-code #27367](https://github.com/anthropics/claude-code/issues/27367)
- [Claude Code mobile crash -- anthropics/claude-code #14400](https://github.com/anthropics/claude-code/issues/14400)
- [Claude Code tmux rendering corruption -- anthropics/claude-code #29937](https://github.com/anthropics/claude-code/issues/29937)
- [Claude Code tmux scroll jitter -- anthropics/claude-code #9935](https://github.com/anthropics/claude-code/issues/9935)
- [ngrok free plan limits documentation](https://ngrok.com/docs/pricing-limits/free-plan-limits)
- [ngrok alternatives 2026 -- freeCodeCamp](https://www.freecodecamp.org/news/top-ngrok-alternatives-tunneling-tools/)
- [WSL2 snap/snapd limitation -- snapcraft.io forum](https://forum.snapcraft.io/t/snapd-shows-up-as-unavailable-inside-wsl/34075)
- [WSL2 file permissions -- Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/file-permissions)
- [WSL2 networking modes -- Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/networking)
- [WSL2 advanced config -- Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
- [Idempotent bash scripts -- arslan.io](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/)
- [tmux FAQ -- tmux/tmux Wiki](https://github.com/tmux/tmux/wiki/FAQ)
- [WSL2 Windows 10 vs 11 capabilities -- microsoft/WSL Discussion #9987](https://github.com/microsoft/WSL/discussions/9987)

---
*Pitfalls research for: CC x TMUX v2 -- WSL2/tmux/SSH remote access toolkit*
*Researched: 2026-03-20*
