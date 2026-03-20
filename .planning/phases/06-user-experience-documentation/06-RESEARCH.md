# Phase 6: User Experience & Documentation - Research

**Researched:** 2026-03-20
**Domain:** Windows integration (desktop shortcut), terminal QR codes, user-facing documentation
**Confidence:** HIGH

## Summary

Phase 6 wraps the fully-functional toolkit (Phases 1-5 complete) with three categories of work: (1) automated Windows desktop shortcut creation from WSL using PowerShell interop, (2) QR code display at startup for phone SSH onboarding, and (3) comprehensive README documentation written for non-technical users.

All three domains are well-understood with mature tooling. The shortcut creation adapts V1's PowerShell approach to run automatically from WSL's `powershell.exe` interop. QR code generation uses the `qrencode` apt package with ANSI terminal output. The README adapts V1's structure but collapses 13 manual steps into a 3-step automated flow.

**Primary recommendation:** Implement shortcut creation and QR display as small function additions to existing modules (lib/setup.sh, startup.sh, lib/deps.sh), then write README.md as the final deliverable referencing all cc-tmux subcommands.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Installer calls `powershell.exe` from WSL to create desktop shortcut automatically (no manual PowerShell step)
- Shortcut target: `wsl.exe -d Ubuntu -- bash -lc '~/startup.sh'` (same as V1)
- Shortcut name: "Claude Workspace"
- Icon: wsl.exe default icon (no custom icon)
- Shortcut creation as a function in lib/setup.sh: `create_desktop_shortcut()`
- Wired into install.sh as a step (after deploy, before verify)
- Uninstall.sh (Phase 5) extended to remove the desktop shortcut via `powershell.exe`
- If powershell.exe not available: warn and skip (graceful degradation)
- Install `qrencode` package via apt (add to deps.sh dependency list)
- Generate QR code encoding `ssh://user@host:port` connection string
- Display as ANSI art in terminal after tunnel starts in startup.sh
- Show alongside text connection info (address, port, username)
- If qrencode not installed: skip QR, show text-only with hint to install
- QR display function in startup.sh or a small helper
- README written for non-technical users -- assume zero knowledge of WSL, SSH, or tmux
- Friendly, direct tone -- no jargon, explain concepts when first introduced
- README structure: 10 sections (What This Does, What You Need, Setup, Phone Setup, Daily Usage, Quick Reference, Troubleshooting, Uninstalling, Files Reference, License)
- Troubleshooting: first step for ANY issue is "Run `cc-tmux doctor`"
- Troubleshooting covers: can't connect from Termius, SSH won't start, ngrok isn't running, tmux session disappeared, PowerShell won't start in tab, closed window by accident, PC went to sleep, permission denied on SSH

### Claude's Discretion
- Exact README wording and length
- Whether to add badges to README (build status, license, etc.)
- Whether to include a "Contributing" section
- QR code size/error correction level
- Whether to add a CHANGELOG.md

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INST-08 | Installer creates Windows desktop shortcut automatically (no manual PowerShell step) | PowerShell COM object approach via `powershell.exe` interop from WSL; V1 script provides exact template; `create_desktop_shortcut()` in lib/setup.sh |
| MOB-04 | QR code displayed at startup for easy phone SSH connection setup | `qrencode` apt package with `-t ANSIUTF8` for compact terminal display; SSH URI format `ssh://user@host:port`; graceful fallback when not installed |
| DOC-01 | README provides complete setup guide written for non-technical users | V1 README structure adapted; 3 steps replace 13; ASCII architecture diagram preserved; tone: friendly, no jargon |
| DOC-02 | README includes quick reference card for daily usage | cc-tmux CLI subcommand table extracted from bin/cc-tmux `show_usage()`; tmux keybinding cheat sheet from V1 |
| DOC-03 | Troubleshooting section covers common failure modes with solutions | V1 troubleshooting section as base; add doctor-first advice; cover all 8 scenarios from CONTEXT.md |

</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| qrencode | 4.1.1 (apt) | Terminal QR code generation | Only maintained QR encoder with ANSI terminal output; standard apt package on Ubuntu |
| powershell.exe | WSL interop | Desktop shortcut creation via WScript.Shell COM | Only way to create .lnk files from WSL; V1 already proves this works |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| WScript.Shell COM | Built into Windows | Creates .lnk shortcut files | Called via powershell.exe from WSL during install |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| qrencode | Pure bash QR (Unicode blocks) | Much more complex, no error correction, fragile |
| powershell.exe COM | VBScript shortcut creation | Less reliable cross-version, more files to manage |
| qrencode ANSI | qrencode PNG + image viewer | Terminal-only environment, no image viewer available |

**Installation:**
```bash
sudo apt install qrencode
```

**Version verification:** qrencode 4.1.1 is the current version in Ubuntu apt repositories. This is a stable, rarely-updated package -- the core functionality has not changed in years.

## Architecture Patterns

### Integration Points (existing files to modify)

```
lib/deps.sh          # Add qrencode to install_package calls
lib/setup.sh         # Add create_desktop_shortcut() function
lib/uninstall.sh     # Add desktop shortcut removal step
install.sh           # Wire shortcut step, bump TOTAL_STEPS to 11
startup.sh           # Add show_qr_code() after tunnel connection info
README.md            # New file at repo root
```

### Pattern 1: Desktop Shortcut Creation via PowerShell Interop
**What:** Call `powershell.exe` from WSL bash to create a Windows .lnk shortcut using the WScript.Shell COM object.
**When to use:** During `install.sh` step execution, after deploy but before verify.
**Example:**
```bash
# Source: V1/setup-shortcut.ps1 adapted for inline WSL call
create_desktop_shortcut() {
    local win_username
    win_username=$(get_config "WIN_USERNAME")
    local wsl_distro
    wsl_distro=$(get_config "WSL_DISTRO")

    # Check powershell.exe is accessible
    if ! command -v powershell.exe &>/dev/null; then
        log_warn "powershell.exe not found -- skipping desktop shortcut"
        log_hint "Create manually: see README.md"
        return 0
    fi

    local desktop_path="/mnt/c/Users/$win_username/Desktop"
    if [[ ! -d "$desktop_path" ]]; then
        log_warn "Windows Desktop not found at $desktop_path -- skipping shortcut"
        return 0
    fi

    # Use PowerShell to create .lnk via WScript.Shell COM
    powershell.exe -NoProfile -Command "
        \$WshShell = New-Object -ComObject WScript.Shell
        \$Shortcut = \$WshShell.CreateShortcut(\"\$env:USERPROFILE\\Desktop\\Claude Workspace.lnk\")
        \$Shortcut.TargetPath = 'wsl.exe'
        \$Shortcut.Arguments = '-d $wsl_distro -- bash -lc \"~/startup.sh\"'
        \$Shortcut.IconLocation = 'C:\\Windows\\System32\\wsl.exe,0'
        \$Shortcut.Save()
    " 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log_ok "Desktop shortcut created: Claude Workspace"
    else
        log_warn "Could not create desktop shortcut"
        log_hint "Create manually: see README.md"
    fi
}
```

### Pattern 2: QR Code Display with Graceful Fallback
**What:** Generate and display an SSH QR code in the terminal using qrencode after the tunnel starts, with text-only fallback.
**When to use:** In startup.sh section 4 (display connection info), after tunnel URL is known.
**Example:**
```bash
# Display QR code for phone SSH setup
show_qr_code() {
    local addr="$1"  # host:port format
    local host="${addr%:*}"
    local port="${addr##*:}"
    local ssh_uri="ssh://$USER@$host:$port"

    if command -v qrencode &>/dev/null; then
        echo "  Scan to connect:"
        echo ""
        qrencode -t ANSIUTF8 -m 1 "$ssh_uri"
        echo ""
    fi
}
```

### Pattern 3: Shortcut Removal in Uninstall
**What:** Remove the Windows desktop shortcut during uninstall via PowerShell interop.
**When to use:** In lib/uninstall.sh, added to the removal list shown to user and executed in Phase 2 (system configs removal).
**Example:**
```bash
# Remove desktop shortcut (in uninstall Phase 2 or as a separate step)
if command -v powershell.exe &>/dev/null; then
    powershell.exe -NoProfile -Command "
        Remove-Item \"\$env:USERPROFILE\\Desktop\\Claude Workspace.lnk\" -ErrorAction SilentlyContinue
    " 2>/dev/null
fi
```

### Anti-Patterns to Avoid
- **Inline PowerShell with unescaped variables:** Dollar signs in PowerShell commands run from bash must be escaped (`\$`) or they expand as bash variables. Use single-quoted heredocs where possible.
- **Blocking on qrencode failure:** QR display is purely cosmetic. Never `set -e` trap on qrencode failure. Always check `command -v qrencode` first.
- **Hard-coding distro name as "Ubuntu":** V1 hard-coded `-d Ubuntu`. V2 has `WSL_DISTRO` in config.env -- use it for the shortcut target.
- **README that assumes knowledge:** Every technical term (WSL, SSH, tmux, ngrok) must be explained on first use or linked.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| QR code generation | Unicode block character QR encoder | `qrencode -t ANSIUTF8` | Error correction, proper encoding, tested on every terminal |
| .lnk file creation | Binary .lnk format writer in bash | PowerShell WScript.Shell COM | .lnk is a binary format with COM internals; only reliable via COM |
| SSH URI encoding | Manual string concatenation | Standard `ssh://user@host:port` format | IETF draft-ietf-secsh-scp-sftp-ssh-uri defines the format |

**Key insight:** Both shortcut creation and QR encoding are small utilities that wrap existing system tools. The real work in this phase is the README documentation.

## Common Pitfalls

### Pitfall 1: PowerShell Dollar Sign Escaping in Bash
**What goes wrong:** Bash interprets `$env:USERPROFILE` as a bash variable, resulting in empty string.
**Why it happens:** PowerShell and bash both use `$` for variables. When calling `powershell.exe -Command "..."` from bash, bash processes the string first.
**How to avoid:** Escape all PowerShell dollar signs as `\$` in double-quoted strings. Alternatively, write the PowerShell command to a temp file and execute that.
**Warning signs:** Shortcut gets created in wrong location or fails silently.

### Pitfall 2: WSL Distro Name with Spaces
**What goes wrong:** If the distro name contains spaces (e.g., "Ubuntu 22.04"), the shortcut arguments break.
**Why it happens:** `wsl.exe -d "Ubuntu 22.04"` needs quotes around the distro name.
**How to avoid:** In the PowerShell command, wrap the distro name in escaped quotes. Test with `$WSL_DISTRO_NAME` values that include spaces.
**Warning signs:** Shortcut double-click opens wrong distro or fails.

### Pitfall 3: QR Code Too Large for Terminal
**What goes wrong:** Default qrencode settings produce a QR code that overflows the terminal width.
**Why it happens:** Default margin is 4 and size is 3, which for longer URLs produces wide output.
**How to avoid:** Use `-m 1` (margin 1) and `-s 1` (size 1) to minimize output. The `ANSIUTF8` type is the most compact (uses half-block Unicode characters, fitting 2 rows per line).
**Warning signs:** QR code wraps in terminal, making it unscannable.

### Pitfall 4: README Assumes Reader Has Terminal Knowledge
**What goes wrong:** Users don't know what "open WSL" means, can't find Windows Terminal, don't know what a "prompt" is.
**Why it happens:** Developer curse of knowledge. V1's README suffered from this slightly.
**How to avoid:** Each step must say WHERE to do it (e.g., "Open Windows Terminal, click the dropdown, select Ubuntu"). Use bold for UI element names. Include expected output after each command.
**Warning signs:** Support questions about "where do I type this?"

### Pitfall 5: Shortcut Path When Desktop Is OneDrive-Synced
**What goes wrong:** Some Windows configs redirect Desktop to OneDrive path (`C:\Users\Name\OneDrive\Desktop`).
**Why it happens:** OneDrive known folders sync can move Desktop, Documents, etc.
**How to avoid:** Use `$env:USERPROFILE\Desktop` in PowerShell (which follows the real Desktop location) rather than constructing the path manually. The V1 approach already does this correctly.
**Warning signs:** Shortcut doesn't appear on desktop despite successful creation.

### Pitfall 6: qrencode Not Available in Non-Interactive Install
**What goes wrong:** `install.sh --yes` installs qrencode, but startup.sh runs before qrencode is deployed.
**Why it happens:** This is not actually a problem because qrencode is installed via apt system-wide, not deployed to ~/.cc-tmux. Just a reminder that qrencode availability doesn't depend on step_deploy.
**How to avoid:** Use `command -v qrencode` check at display time, not install time.

## Code Examples

### QR Code Terminal Output (qrencode)
```bash
# Source: qrencode man page + verified ANSI output types
# ANSIUTF8 uses Unicode half-block chars for compact 2-rows-per-line display
# -m 1 reduces margin to 1 (default 4 wastes space)
# -l L is fine -- error correction L is sufficient for short URIs

echo "ssh://user@0.tcp.ngrok.io:12345" | qrencode -t ANSIUTF8 -m 1 -o -

# Or with direct argument:
qrencode -t ANSIUTF8 -m 1 "ssh://user@0.tcp.ngrok.io:12345"
```

### PowerShell Shortcut Creation from WSL Bash
```bash
# Source: V1/setup-shortcut.ps1, adapted for WSL interop
# Key: escape all $ as \$ in double-quoted bash string
powershell.exe -NoProfile -Command "
    \$WshShell = New-Object -ComObject WScript.Shell
    \$Shortcut = \$WshShell.CreateShortcut(\"\$env:USERPROFILE\\Desktop\\Claude Workspace.lnk\")
    \$Shortcut.TargetPath = 'wsl.exe'
    \$Shortcut.Arguments = '-d Ubuntu -- bash -lc \"~/startup.sh\"'
    \$Shortcut.IconLocation = 'C:\\Windows\\System32\\wsl.exe,0'
    \$Shortcut.Save()
"
```

### PowerShell Shortcut Removal from WSL Bash
```bash
# Source: inverse of creation, for uninstall.sh
powershell.exe -NoProfile -Command "
    Remove-Item \"\$env:USERPROFILE\\Desktop\\Claude Workspace.lnk\" -ErrorAction SilentlyContinue
"
```

### SSH URI Format
```
# Source: IETF draft-ietf-secsh-scp-sftp-ssh-uri
# Format: ssh://[user@]host[:port]
ssh://ben@0.tcp.ngrok.io:12345
```

### cc-tmux Subcommands (for Quick Reference Card)
```
# Source: bin/cc-tmux show_usage()
cc-tmux start              # Start workspace (SSH + tunnel + tmux)
cc-tmux stop               # Stop workspace (kill session + tunnel)
cc-tmux project add        # Add a project tab
cc-tmux project remove     # Remove a project tab
cc-tmux project list       # List configured projects
cc-tmux tunnel             # Show tunnel status
cc-tmux doctor             # Check installation health
cc-tmux update             # Check for and apply updates
cc-tmux uninstall          # Remove cc-tmux completely
cc-tmux version            # Show cc-tmux version
cc-tmux help               # Show help message
```

## State of the Art

| Old Approach (V1) | Current Approach (V2) | When Changed | Impact |
|--------------------|----------------------|--------------|--------|
| Manual PowerShell shortcut (Step 12 in README) | Automated via install.sh calling powershell.exe | This phase | One fewer manual step |
| No QR code, manual port entry | QR code auto-displayed at startup | This phase | Phone setup in seconds |
| 13-step manual setup guide | 3-step automated setup | This phase | Dramatically simpler README |
| Manual script files to manage | cc-tmux CLI with subcommands | Phase 4 (done) | Quick reference card possible |
| Password-only SSH | Ed25519 key-based SSH | Phase 2 (done) | Phone setup docs reference key import, not password |

**Deprecated/outdated:**
- V1's `~/port.sh`, `~/attach.sh`, `~/workspace-init.sh` -- all replaced by cc-tmux CLI
- Manual sed replacement of YOURUSERNAME -- replaced by auto-detection

## Open Questions

1. **QR code output type: ANSIUTF8 vs ANSI256UTF8**
   - What we know: ANSIUTF8 uses half-block Unicode characters (most compact). ANSI256 uses 256-color escape codes. ANSIUTF8 is the best for terminal compactness.
   - What's unclear: Whether all WSL2 terminal emulators (Windows Terminal, ConPTY) render ANSIUTF8 correctly.
   - Recommendation: Use ANSIUTF8. Windows Terminal supports Unicode half-blocks. If issues arise, fall back to ANSI256.

2. **WSL distro name in shortcut**
   - What we know: `WSL_DISTRO` is stored in config.env. `$WSL_DISTRO_NAME` env var is set by WSL at runtime.
   - What's unclear: Whether distro names with spaces (e.g., "Ubuntu 22.04 LTS") need special quoting in the .lnk Arguments field.
   - Recommendation: Use the config value. Test with quoting. Most Ubuntu installs report just "Ubuntu" without version suffix.

3. **README badges**
   - What we know: Claude's discretion per CONTEXT.md.
   - Recommendation: Skip badges. This is not a widely-distributed npm package. License badge only if desired. Keep the README clean and focused on the non-technical user.

4. **CHANGELOG.md**
   - What we know: Claude's discretion per CONTEXT.md.
   - Recommendation: Skip for v1.0 release. Not needed until there are actual version updates to track.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual verification (bash scripts, no automated test framework) |
| Config file | none |
| Quick run command | Manual: run install.sh, verify shortcut appears, run startup.sh, verify QR displays |
| Full suite command | Manual: full install cycle + README review |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INST-08 | Desktop shortcut created during install | manual-only | Verify .lnk exists: `powershell.exe -Command "Test-Path \"\$env:USERPROFILE\\Desktop\\Claude Workspace.lnk\""` | N/A |
| MOB-04 | QR code displayed at startup after tunnel connects | manual-only | Run startup.sh, visually confirm QR appears | N/A |
| DOC-01 | README has complete setup guide | manual-only | Read README.md, verify 10 sections present | N/A |
| DOC-02 | README has quick reference card | manual-only | Check README.md for command table | N/A |
| DOC-03 | Troubleshooting section covers 8 scenarios | manual-only | Count troubleshooting subsections in README.md | N/A |

**Justification for manual-only:** All five requirements involve either Windows interop (shortcut .lnk creation requires real Windows Desktop), external services (QR needs live tunnel), or documentation quality (README is prose). These cannot be meaningfully automated with unit tests. The step_verify in install.sh can be extended to check shortcut existence as part of the install verification.

### Sampling Rate
- **Per task commit:** Visual inspection of modified files
- **Per wave merge:** Full install cycle on WSL2
- **Phase gate:** All 5 requirements manually verified

### Wave 0 Gaps
None -- no test infrastructure needed for this phase. Validation is manual inspection and functional testing on a real WSL2 system.

## Implementation Notes

### install.sh Changes
- `TOTAL_STEPS` must increase from 10 to 11 (or the new shortcut step can share a step number with an existing step)
- New step placement: after step 10 (PATH config), before step_verify
- Current step numbering:
  1. Preflight
  2. Install deps
  3. Install ngrok
  4. Detect environment
  5. Configure
  6. System setup
  7. SSH hardening
  8. Deploy runtime files
  9. Deploy startup script
  10. Configure PATH
  11. **NEW: Create desktop shortcut**
  - Verify (unnumbered, runs last)

### lib/deps.sh Changes
- Add `install_package "qrencode"` after `install_package "fail2ban"` in `step_install_deps()`

### lib/setup.sh Changes
- Add `create_desktop_shortcut()` function at the end of the file
- This function uses `get_config` for WIN_USERNAME and WSL_DISTRO

### lib/uninstall.sh Changes
- Add shortcut removal to the "what will be removed" display list
- Add PowerShell removal command to Phase 2 (system configs removal) or Phase 4 (user files removal)

### startup.sh Changes
- Add `show_qr_code()` function
- Call it in section 4 after displaying text connection info (inside the `tunnel_available` branch)

### README.md Structure
Must follow the 10-section structure from CONTEXT.md. Key adaptations from V1:
- V1's ASCII architecture diagram: keep but update for V2 architecture
- V1's "Quick Reference" table: update commands from manual scripts to cc-tmux CLI
- V1's troubleshooting: expand with all 8 scenarios, add "Run cc-tmux doctor first" advice
- V1's Files Reference: update for V2 file layout (~/.cc-tmux/ structure)
- New: Phone Setup section (import SSH key into Termius)

## Sources

### Primary (HIGH confidence)
- V1/setup-shortcut.ps1 -- proven PowerShell shortcut creation pattern
- V1/README.md -- proven documentation structure and tone
- bin/cc-tmux -- all subcommands for quick reference card
- qrencode man page (Debian) -- output types, options, error correction

### Secondary (MEDIUM confidence)
- [qrencode man page (Debian)](https://manpages.debian.org/testing/qrencode/qrencode.1.en.html) -- ANSIUTF8 output format details
- [IETF SSH URI draft](https://www.ietf.org/archive/id/draft-salowey-secsh-uri-00.html) -- ssh:// URI format specification
- [qrencode terminal usage](https://www.linuxbash.sh/post/generate-a-qr-code-in-the-terminal-using-qrencode--t-ansi) -- practical ANSI examples

### Tertiary (LOW confidence)
None -- all findings verified against official docs or existing codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- qrencode and PowerShell interop are mature, stable, well-documented tools
- Architecture: HIGH -- all integration points are existing files with established patterns (step functions, graceful degradation)
- Pitfalls: HIGH -- based on direct V1 experience, PowerShell escaping is well-known, QR sizing is documented
- Documentation: HIGH -- V1 README provides a proven template; cc-tmux CLI is fully built

**Research date:** 2026-03-20
**Valid until:** Indefinite -- qrencode and WScript.Shell COM are extremely stable APIs
