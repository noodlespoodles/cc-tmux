# Phase 1: Foundation & Installer - Research

**Researched:** 2026-03-20
**Domain:** Bash installer toolkit for WSL2 environment
**Confidence:** HIGH

## Summary

Phase 1 builds the foundation of cc-tmux v2: a single-command installer (`bash install.sh`) that installs all dependencies (tmux, openssh-server, ngrok, jq, fail2ban), auto-detects the Windows username, interactively gathers project folders and ngrok auth token, writes a config system for downstream phases, and enforces LF line endings via `.gitattributes`. The installer must be idempotent and feel like rustup -- guided, clear, works first time.

The V1 installer (`V1/install.sh`) provides a working reference but has critical gaps: snap-based ngrok install fails without systemd, `cmd.exe` interop hangs indefinitely, `YOURUSERNAME` placeholder requires manual replacement, no idempotency guards for `.bashrc`, and scripts scattered in `~/` with no structure. V2 addresses all of these.

**Primary recommendation:** Build a modular installer (`install.sh` sources `lib/` modules) with numbered steps, ANSI color output respecting `NO_COLOR`, timeout-protected Windows username detection with multiple fallbacks, ngrok via apt repository (not snap), and a `~/.cc-tmux/` runtime directory with sourceable `config.env`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Step-by-step wizard with numbered progress indicators (e.g., `[1/6] Installing dependencies...`)
- Color-coded output: green for success, red for errors, yellow for warnings, blue for prompts
- Each error shows inline with red highlight and a suggested fix action
- Dependency status shown as check/cross per item with automatic install-if-missing
- Support `--yes` flag for non-interactive mode (accept all defaults, skip prompts)
- Installer is a single entry point (`bash install.sh`) that sources lib/ modules
- User configuration lives in `~/.cc-tmux/` directory (not in the repo clone)
- Main config: `~/.cc-tmux/config.env` -- sourceable KEY=value format, zero dependencies
- Project list: `~/.cc-tmux/projects.conf` -- one `name|/path/to/folder` per line
- Both files are human-readable and hand-editable
- Repository is cloned anywhere; runtime files installed to `~/.cc-tmux/`
- CLI entry point `cc-tmux` symlinked to `/usr/local/bin/cc-tmux` or PATH exported in .bashrc
- Repo and install dir are separate -- repo is source of truth, `~/.cc-tmux/` is runtime
- Install ngrok via apt repository (NOT snap)
- Add ngrok's official apt signing key and repository
- Prompt user for auth token during install with clear instructions and dashboard URL
- Token stored via `ngrok config add-authtoken` (ngrok's native config)
- If ngrok already installed, skip install and verify config exists (idempotent)
- After setup, run a quick start/stop test tunnel to verify ngrok works
- `.gitattributes` in repo root forces `* text=auto eol=lf` for all text files
- `*.sh` files explicitly marked as `text eol=lf`

### Claude's Discretion
- Exact color codes and formatting details
- Whether to use `tput` or ANSI escape codes for colors
- Error message wording (as long as it's clear and actionable)
- Whether to create `~/.cc-tmux/bin/` or use a flat structure
- How to handle edge case: user has no Documents folder

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INST-01 | User can install everything with a single command (`bash install.sh`) that handles all dependencies | Modular installer architecture (install.sh + lib/ modules), apt package installation pattern, ngrok apt repo method |
| INST-02 | Installer auto-detects Windows username without manual placeholder replacement | Tiered detection strategy: `cmd.exe` with timeout -> `/mnt/c/Users/` directory parsing -> interactive fallback |
| INST-03 | Installer is idempotent -- re-running it doesn't break or duplicate anything | Sentinel markers, guard checks, overwrite-not-append pattern, `command -v` pre-checks |
| INST-04 | Installer provides clear progress indicators and error messages at each step | ANSI color output with NO_COLOR respect, numbered steps, check/cross status per dependency |
| INST-05 | Installer interactively asks user for project folders (guided setup, not config file editing) | Interactive `read` prompts, path validation with `wslpath`, projects.conf `name\|path` format |
| INST-06 | Installer handles ngrok auth token setup with clear instructions | ngrok apt repo install, `ngrok config add-authtoken`, dashboard URL display, test tunnel verification |
| ROB-04 | `.gitattributes` ensures LF line endings -- cloning on Windows doesn't break scripts | `.gitattributes` with `* text=auto eol=lf` and explicit `*.sh text eol=lf`, self-healing `sed` in install.sh |
</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | 5.1+ (Ubuntu 22.04/24.04 default) | All installer scripts | Project constraint: bash-only, no Python/Node deps |
| tmux | 3.2+ (apt) | Session multiplexer (installed by installer) | V1 already uses it; apt version sufficient |
| OpenSSH Server | 8.2+ (apt) | Remote access (installed by installer) | V1 already uses it; standard Linux package |
| ngrok | Latest (apt repo) | TCP tunnel for remote SSH | Locked decision: install via apt repository, not snap |
| jq | 1.6+ (apt) | JSON parsing for ngrok API | Replaces V1's fragile `grep -oP` pattern |
| fail2ban | 0.11+ (apt) | Brute force protection | Defense in depth for SSH exposed via tunnel |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| ShellCheck | Latest (apt) | Bash static analysis | Development time -- all scripts must pass |
| BATS | Latest (git clone) | Bash test framework | Testing installer idempotency and config operations |
| `dos2unix` | Latest (apt) | CRLF conversion fallback | Self-healing in install.sh if `.gitattributes` is insufficient |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ngrok apt repo | ngrok snap | Snap fails on WSL2 without systemd -- apt is reliable |
| ngrok apt repo | ngrok binary download | Works but no auto-update; apt integrates with system package management |
| `cmd.exe /C "echo %USERNAME%"` | `wslvar USERNAME` (wslu) | wslu was archived March 2025, no longer maintained; `cmd.exe` with timeout is more reliable |
| ANSI escape codes | `tput` commands | Both viable; ANSI is simpler, works in all WSL2 terminals; `tput` more portable but adds complexity. Recommendation: ANSI with `NO_COLOR` respect |

**Installation (what the installer itself installs):**
```bash
sudo apt update
sudo apt install -y tmux openssh-server jq fail2ban
# ngrok via apt repo (separate step -- see ngrok section)
```

## Architecture Patterns

### Recommended Project Structure (in repo)
```
cc-tmux/                         # Git repository (cloned anywhere)
  install.sh                     # Entry point -- sources lib/ modules
  .gitattributes                 # LF line ending enforcement
  lib/
    common.sh                    # Colors, logging, error handling, guards
    detect.sh                    # Windows username, WSL distro, path detection
    config.sh                    # Read/write config.env and projects.conf
    deps.sh                      # Dependency installation (apt packages, ngrok)
    setup.sh                     # SSH config, sudoers, bashrc hook
  templates/
    tmux.conf.tpl                # tmux config template (Phase 4 uses this)
    bashrc-hook.sh               # Auto-attach snippet for .bashrc
```

### Recommended Runtime Structure (installed)
```
~/.cc-tmux/                      # Runtime directory (created by installer)
  config.env                     # User-specific settings (KEY=value, sourceable)
  projects.conf                  # Project list (name|/path/to/folder per line)
  lib/                           # Copied from repo lib/
    common.sh
    detect.sh
    config.sh
    ...
  templates/                     # Copied from repo templates/
    tmux.conf.tpl
    bashrc-hook.sh
```

### Pattern 1: Modular Installer with Sourced Libraries
**What:** `install.sh` is the single entry point that sources lib/ modules for each capability.
**When to use:** Always -- this is the locked decision.
**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library modules
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/deps.sh"
source "$SCRIPT_DIR/lib/setup.sh"

# Parse arguments
NONINTERACTIVE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) NONINTERACTIVE=true; shift ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

main() {
    print_banner
    step_preflight          # [1/N] Verify WSL2, bash version, sudo
    step_install_deps       # [2/N] Install apt packages
    step_install_ngrok      # [3/N] Install ngrok via apt repo
    step_detect_environment # [4/N] Auto-detect Windows user, paths
    step_configure          # [5/N] Interactive project setup, ngrok token
    step_deploy             # [6/N] Copy files to ~/.cc-tmux/, write configs
    step_verify             # [7/N] Verify everything works
    print_summary
}

main
```

### Pattern 2: Sourceable Config File (config.env)
**What:** Configuration stored as `KEY=value` pairs that can be sourced directly by bash.
**When to use:** All scripts that need configuration values.
**Example:**
```bash
# ~/.cc-tmux/config.env
# Generated by cc-tmux installer -- hand-editable
# Last updated: 2026-03-20

CC_TMUX_VERSION="2.0.0"
CC_TMUX_INSTALL_DATE="2026-03-20"
WIN_USERNAME="Ben"
WIN_HOME="/mnt/c/Users/Ben"
WSL_DISTRO="Ubuntu"
TUNNEL_PROVIDER="ngrok"
SESSION_NAME="work"
```

**Loading pattern:**
```bash
CONFIG_FILE="$HOME/.cc-tmux/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log_error "Config not found. Run install.sh first."
    exit 1
fi
```

### Pattern 3: Idempotent Guard Checks
**What:** Every operation checks current state before acting.
**When to use:** Every installation step.
**Example:**
```bash
# Package installation guard
install_package() {
    local pkg="$1"
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        log_ok "$pkg already installed"
    else
        sudo apt install -y "$pkg" || {
            log_error "Failed to install $pkg"
            log_hint "Try: sudo apt update && sudo apt install -y $pkg"
            return 1
        }
        log_ok "$pkg installed"
    fi
}

# Bashrc sentinel guard
add_bashrc_block() {
    local marker="# MANAGED BY CC-TMUX"
    if grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
        log_ok "bashrc hook already configured"
    else
        cat >> "$HOME/.bashrc" << 'EOF'

# MANAGED BY CC-TMUX -- DO NOT EDIT THIS BLOCK
if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ]; then
    ~/.cc-tmux/lib/attach.sh
fi
# END CC-TMUX BLOCK
EOF
        log_ok "bashrc hook added"
    fi
}

# File deployment (overwrite is idempotent)
deploy_file() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    chmod 644 "$dst"
}
```

### Pattern 4: Color Output with NO_COLOR Support
**What:** ANSI color codes with respect for `NO_COLOR` environment variable.
**When to use:** All user-facing output.
**Example:**
```bash
# In lib/common.sh
setup_colors() {
    if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
    else
        RED=$'\033[0;31m'
        GREEN=$'\033[0;32m'
        YELLOW=$'\033[0;33m'
        BLUE=$'\033[0;34m'
        BOLD=$'\033[1m'
        RESET=$'\033[0m'
    fi
}

log_ok()    { echo "  ${GREEN}[ok]${RESET} $*"; }
log_error() { echo "  ${RED}[error]${RESET} $*"; }
log_warn()  { echo "  ${YELLOW}[warn]${RESET} $*"; }
log_hint()  { echo "       ${BLUE}$*${RESET}"; }
log_step()  { echo "${BOLD}[$1/$TOTAL_STEPS] $2${RESET}"; }
```

### Pattern 5: Windows Username Detection with Tiered Fallback
**What:** Multiple methods to detect Windows username, each with timeout protection.
**When to use:** During installer step_detect_environment.
**Example:**
```bash
detect_windows_username() {
    local username=""

    # Method 1: cmd.exe with timeout (fastest, most common)
    username=$(timeout 5 cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)
    if [[ -n "$username" && "$username" != "%USERNAME%" ]]; then
        echo "$username"
        return 0
    fi

    # Method 2: Parse /mnt/c/Users/ directory
    # Filter out system directories
    local candidates=()
    while IFS= read -r dir; do
        local name
        name=$(basename "$dir")
        case "$name" in
            Default|"Default User"|Public|"All Users"|desktop.ini) continue ;;
            *) candidates+=("$name") ;;
        esac
    done < <(ls -d /mnt/c/Users/*/ 2>/dev/null)

    if [[ ${#candidates[@]} -eq 1 ]]; then
        echo "${candidates[0]}"
        return 0
    elif [[ ${#candidates[@]} -gt 1 ]]; then
        # Multiple users found -- need interactive selection
        log_warn "Multiple Windows users found"
        return 1
    fi

    # Method 3: Fall through to interactive prompt
    return 1
}
```

### Anti-Patterns to Avoid
- **Placeholder replacement (`sed -i "s/YOURUSERNAME/$user/g"`):** Breaks if username contains `/` or `&`, not reversible, fails silently if already replaced. Use config.env sourcing instead.
- **Appending to .bashrc without guards:** Causes duplicate blocks on re-run. Always use sentinel markers and grep checks.
- **`snap install` on WSL2:** Fails without systemd. Use apt repository for ngrok.
- **Scattering scripts in `~/`:** V1 pattern. Pollutes home directory. Use `~/.cc-tmux/` exclusively.
- **`powershell.exe` for simple operations:** 2-5 second cold start vs 0.3s for `cmd.exe`. Never use PowerShell when cmd.exe suffices.
- **Relying on `wslvar` / wslu:** Repository archived March 2025, known interop issues with systemd. Use `cmd.exe` with timeout and directory parsing fallback.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing of ngrok API | `grep -oP` regex (V1 does this) | `jq '.tunnels[0].public_url'` | Regex breaks on format changes; jq handles all valid JSON |
| CRLF line ending prevention | Runtime conversion scripts | `.gitattributes` with `eol=lf` | Prevents the problem at source; `.gitattributes` is Git-native |
| CRLF self-healing | Custom conversion logic | `sed -i 's/\r$//'` at top of install.sh | Single line, handles edge case where .gitattributes was bypassed |
| Color terminal detection | Complex `tput` capability checks | `NO_COLOR` env var + `[ -t 1 ]` TTY check | Industry standard (no-color.org), simple, covers all cases |
| Package installation check | `which` or `type` commands | `dpkg -l "$pkg" \| grep "^ii"` for apt packages, `command -v` for binaries | `dpkg -l` is authoritative for apt; `command -v` for non-apt binaries |
| SSH key generation | Manual `ssh-keygen` calls | `sudo ssh-keygen -A` (generates all missing host key types) | OpenSSH built-in, handles all key types, already idempotent |

**Key insight:** V1 hand-rolled solutions for problems that have standard tools. `jq` replaces fragile regex, `.gitattributes` replaces runtime conversion, `dpkg -l` replaces `which` for package detection. Every hand-rolled solution adds a bug surface.

## Common Pitfalls

### Pitfall 1: Snap Fails on WSL2 Without Systemd
**What goes wrong:** `sudo snap install ngrok` fails with "System has not been booted with systemd as init system"
**Why it happens:** Snap requires systemd as PID 1; many WSL2 installs don't have it enabled
**How to avoid:** Use ngrok apt repository (locked decision). Commands:
```bash
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update
sudo apt install -y ngrok
```
**Warning signs:** Installer hangs at ngrok step; user reports "ngrok not found" after install

### Pitfall 2: cmd.exe Interop Hangs (10-40s or Indefinitely)
**What goes wrong:** `cmd.exe /C "echo %USERNAME%"` freezes during Windows username detection
**Why it happens:** WSL2 cross-VM communication via 9P protocol is fragile -- breaks after `wsl --shutdown`, during heavy I/O, or when antivirus intercepts
**How to avoid:** Always wrap with `timeout 5`. Have multiple fallback methods (parse `/mnt/c/Users/`, interactive prompt). Cache result in config.env so detection only runs once.
**Warning signs:** Installer appears frozen at "detecting username" step; Ctrl+C needed

### Pitfall 3: Non-Idempotent bashrc Modifications
**What goes wrong:** Re-running installer duplicates the auto-attach block in `.bashrc`
**Why it happens:** V1 checks for one marker string but the pattern is fragile
**How to avoid:** Use clear sentinel comments (`# MANAGED BY CC-TMUX` / `# END CC-TMUX BLOCK`) and `grep -qF` check before appending. Alternatively, source a separate file from `.bashrc` so the content can be safely overwritten.
**Warning signs:** `.bashrc` has duplicate blocks; multiple attach prompts on SSH login

### Pitfall 4: Windows Path Issues
**What goes wrong:** User's project paths contain spaces (e.g., `/mnt/c/Users/Ben/Documents/My Projects`) and scripts break
**Why it happens:** Unquoted variables in bash. `for dir in $PATHS` splits on spaces.
**How to avoid:** Always quote variable expansions (`"$path"`). Use `while IFS= read -r` for line-by-line processing of projects.conf. Validate paths exist during interactive setup.
**Warning signs:** "No such file or directory" errors with partial path; scripts work for users without spaces in paths

### Pitfall 5: ngrok Auth Token Not Configured
**What goes wrong:** ngrok installed but tunnel fails because auth token was skipped
**Why it happens:** User pressed Enter to skip during install; no verification step catches this
**How to avoid:** After ngrok install, check `ngrok config check` or look for the config file. If token missing, warn clearly. The locked decision includes a test tunnel -- this will catch missing tokens.
**Warning signs:** `ngrok tcp 22` exits with "authentication required"; tunnel never establishes

### Pitfall 6: Sudoers File Syntax Errors
**What goes wrong:** Typo in `/etc/sudoers.d/` file locks user out of sudo
**Why it happens:** Sudoers files are parsed strictly; wrong syntax = no sudo for anyone
**How to avoid:** Use `visudo -c -f /path/to/file` to validate syntax before deploying. Never directly write to sudoers without validation. Restrict permissions to `0440`.
**Warning signs:** "sudo: parse error" on any sudo command; user locked out of privileged operations

## Code Examples

### ngrok apt Repository Installation (Verified)
```bash
# Source: https://ngrok.com/download/linux (verified 2026-03-20)
install_ngrok() {
    if command -v ngrok &>/dev/null; then
        log_ok "ngrok already installed ($(ngrok version 2>/dev/null || echo 'unknown version'))"
        return 0
    fi

    log_step "$STEP" "Installing ngrok via apt repository..."

    # Add GPG signing key
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
        | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null || {
        log_error "Failed to download ngrok signing key"
        log_hint "Check your internet connection and try again"
        return 1
    }

    # Add apt repository
    echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
        | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null

    # Install
    sudo apt update -qq
    sudo apt install -y ngrok || {
        log_error "Failed to install ngrok"
        log_hint "Try manually: sudo apt install ngrok"
        return 1
    }

    log_ok "ngrok installed"
}
```

### ngrok Auth Token Setup (Interactive)
```bash
setup_ngrok_token() {
    # Check if already configured
    if ngrok config check &>/dev/null 2>&1; then
        log_ok "ngrok auth token already configured"
        return 0
    fi

    echo ""
    log_step "$STEP" "Configuring ngrok auth token..."
    echo ""
    echo "  You need an ngrok auth token to create tunnels."
    echo "  1. Sign up (free) at: ${BLUE}https://ngrok.com${RESET}"
    echo "  2. Get your token at: ${BLUE}https://dashboard.ngrok.com/get-started/your-authtoken${RESET}"
    echo ""

    if [[ "$NONINTERACTIVE" == true ]]; then
        log_warn "Skipped in non-interactive mode. Run later: ngrok config add-authtoken YOUR_TOKEN"
        return 0
    fi

    read -rp "  Paste your ngrok auth token (or press Enter to skip): " token

    if [[ -n "$token" ]]; then
        ngrok config add-authtoken "$token" || {
            log_error "Failed to save ngrok token"
            return 1
        }
        log_ok "ngrok auth token saved"
    else
        log_warn "Skipped. Run later: ngrok config add-authtoken YOUR_TOKEN"
    fi
}
```

### Project Folder Interactive Setup
```bash
setup_projects() {
    local projects_file="$HOME/.cc-tmux/projects.conf"

    if [[ -f "$projects_file" ]] && [[ -s "$projects_file" ]]; then
        log_ok "Project list already configured ($(wc -l < "$projects_file") projects)"
        return 0
    fi

    echo ""
    log_step "$STEP" "Setting up project folders..."
    echo ""
    echo "  Add project folders that will become tabs in your workspace."
    echo "  Format: Give each project a short name and its Windows path."
    echo ""

    local projects=()
    local win_home="/mnt/c/Users/$WIN_USERNAME"

    while true; do
        local num=$((${#projects[@]} + 1))
        echo "  --- Project $num ---"
        read -rp "  Project name (or 'done' to finish): " name

        [[ "$name" == "done" || -z "$name" ]] && break

        read -rp "  Folder path [$win_home/Documents]: " path
        path="${path:-$win_home/Documents}"

        # Validate path exists
        if [[ ! -d "$path" ]]; then
            log_warn "Path does not exist: $path"
            read -rp "  Add anyway? (y/N): " confirm
            [[ "$confirm" != [yY] ]] && continue
        fi

        projects+=("$name|$path")
        log_ok "Added: $name -> $path"
        echo ""
    done

    if [[ ${#projects[@]} -eq 0 ]]; then
        # Add default project
        projects+=("home|$win_home/Documents")
        log_warn "No projects added. Using default: home -> $win_home/Documents"
    fi

    # Write projects.conf
    printf '%s\n' "${projects[@]}" > "$projects_file"
    log_ok "Saved ${#projects[@]} project(s) to projects.conf"
}
```

### .gitattributes File
```gitattributes
# Force LF line endings for all text files
* text=auto eol=lf

# Explicitly mark shell scripts
*.sh text eol=lf
*.conf text eol=lf
*.tpl text eol=lf

# Explicitly mark Windows files
*.ps1 text eol=crlf
*.bat text eol=crlf
*.cmd text eol=crlf

# Binary files
*.png binary
*.ico binary
```

### Self-Healing CRLF in install.sh (Belt and Suspenders)
```bash
# At the very top of install.sh, before set -euo pipefail
# Self-heal CRLF if cloned on Windows without .gitattributes
if head -1 "$0" | grep -q $'\r'; then
    echo "Fixing Windows line endings..."
    sed -i 's/\r$//' "$0"
    # Re-execute with fixed line endings
    exec bash "$0" "$@"
fi
```

### Preflight Checks
```bash
step_preflight() {
    log_step 1 "Running preflight checks..."

    # Verify WSL2
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        log_error "This installer must run inside WSL2"
        log_hint "Open Ubuntu from Windows Terminal, then run this script"
        exit 1
    fi
    log_ok "Running in WSL2"

    # Verify bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
        log_error "Bash 5.0+ required (found ${BASH_VERSION})"
        log_hint "Update: sudo apt install bash"
        exit 1
    fi
    log_ok "Bash ${BASH_VERSION}"

    # Verify sudo access
    if ! sudo -v 2>/dev/null; then
        log_error "sudo access required"
        log_hint "Run: sudo echo test"
        exit 1
    fi
    log_ok "sudo access confirmed"

    # Verify internet (needed for apt)
    if ! ping -c 1 -W 3 archive.ubuntu.com &>/dev/null; then
        log_warn "Cannot reach archive.ubuntu.com -- apt install may fail"
    else
        log_ok "Internet connectivity"
    fi
}
```

## State of the Art

| Old Approach (V1) | Current Approach (V2) | Impact |
|--------------------|-----------------------|--------|
| `sudo snap install ngrok` | ngrok apt repository | Eliminates systemd dependency; works on all WSL2 |
| `cmd.exe /C "echo %USERNAME%"` (no timeout) | `timeout 5 cmd.exe` + `/mnt/c/Users/` fallback + interactive | Eliminates hang; 3-layer fallback |
| `sed -i "s/YOURUSERNAME/$user/g"` | Sourceable `config.env` with `WIN_USERNAME=value` | Eliminates placeholder replacement entirely |
| Scripts in `~/` (home pollution) | `~/.cc-tmux/` structured directory | Clean, discoverable, uninstallable |
| `set -e` only | `set -euo pipefail` + ERR trap | Catches undefined vars and pipe failures |
| `grep -oP` for JSON (ngrok API) | `jq` | Reliable JSON parsing, no Perl regex dependency |
| `wslvar` (wslu) | Direct `cmd.exe` + directory detection | wslu archived March 2025; direct approach more reliable |
| No idempotency | Guard checks on every operation | Re-run is safe and fast |

**Deprecated/outdated:**
- **wslu/wslvar**: Repository archived March 2025. Do not add as dependency. Use `cmd.exe` with timeout for Windows env var access and `/mnt/c/Users/` parsing as fallback.
- **snap for ngrok on WSL2**: Fundamentally broken without systemd as PID 1. The apt repository method is the correct approach.

## Open Questions

1. **ngrok test tunnel verification**
   - What we know: The locked decision says "run a quick start/stop test tunnel to verify ngrok works"
   - What's unclear: Whether to start a real TCP tunnel (requires port 22 and SSH running) or just verify `ngrok diagnose` / `ngrok config check`
   - Recommendation: Use `ngrok diagnose` to verify connectivity and auth without starting a real tunnel. Starting a real tunnel requires SSH to be running first, creating a circular dependency in the installer flow. If SSH is set up before the ngrok test, a quick `ngrok tcp 22 &` + poll `localhost:4040` + kill is viable.

2. **Multiple Windows Users on Same Machine**
   - What we know: `/mnt/c/Users/` directory parsing may find multiple user directories
   - What's unclear: How common this is; whether to auto-select or always prompt
   - Recommendation: If exactly one non-system user found, auto-select. If multiple found, present numbered list for selection. This handles the common case silently and the edge case gracefully.

3. **Installer Step Count**
   - What we know: Context says `[1/6]` example but the actual steps may differ
   - What's unclear: Exact number of steps once all requirements are mapped
   - Recommendation: Use a variable `TOTAL_STEPS` set at the top of `main()` so step numbers are always accurate. Likely 7 steps: preflight, deps, ngrok, detect, configure, deploy, verify.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | BATS (Bash Automated Testing System) v1.11+ |
| Config file | None -- BATS uses convention (`tests/*.bats`) |
| Quick run command | `bats tests/01-installer.bats` |
| Full suite command | `bats tests/` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INST-01 | install.sh runs without error, all deps present after | integration | `bats tests/01-installer.bats::test_install_all_deps` | No -- Wave 0 |
| INST-02 | Windows username detected automatically | unit | `bats tests/01-installer.bats::test_detect_username` | No -- Wave 0 |
| INST-03 | Re-running installer produces identical state | integration | `bats tests/01-installer.bats::test_idempotent_rerun` | No -- Wave 0 |
| INST-04 | Progress indicators present in output | unit | `bats tests/01-installer.bats::test_output_format` | No -- Wave 0 |
| INST-05 | projects.conf created with user entries | unit | `bats tests/01-installer.bats::test_projects_conf` | No -- Wave 0 |
| INST-06 | ngrok installed and token configured | integration | `bats tests/01-installer.bats::test_ngrok_setup` | No -- Wave 0 |
| ROB-04 | .gitattributes enforces LF | unit | `bats tests/01-installer.bats::test_line_endings` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `shellcheck lib/*.sh install.sh && bats tests/01-installer.bats`
- **Per wave merge:** `shellcheck lib/*.sh install.sh && bats tests/`
- **Phase gate:** Full suite green + manual run of `bash install.sh` on clean WSL2

### Wave 0 Gaps
- [ ] `tests/01-installer.bats` -- covers INST-01 through INST-06, ROB-04
- [ ] `tests/helpers/` -- shared test helpers (mock cmd.exe, temp config dirs)
- [ ] BATS install: `git clone https://github.com/bats-core/bats-core.git && cd bats-core && sudo ./install.sh /usr/local` or `sudo apt install bats`
- [ ] ShellCheck install: `sudo apt install shellcheck`

**Note:** Many installer tests require a real WSL2 environment and sudo access, making them integration tests that cannot easily run in CI. The unit tests (output format, config parsing, username detection logic) can be isolated and tested in any bash environment. Integration tests (apt install, ngrok setup, sudoers) are best verified via manual run with `bash install.sh` on a clean WSL2 instance.

## Sources

### Primary (HIGH confidence)
- [ngrok Download/Install Linux](https://ngrok.com/download/linux) -- apt repository installation commands verified
- [GitHub Docs - Configuring Git line endings](https://docs.github.com/en/get-started/git-basics/configuring-git-to-handle-line-endings) -- .gitattributes patterns
- [no-color.org](https://no-color.org/) -- NO_COLOR environment variable standard
- V1/install.sh -- reference implementation analyzed in full
- V1/workspace-init.sh -- project list pattern analyzed
- V1/tmux.conf -- placeholder pattern to eliminate

### Secondary (MEDIUM confidence)
- [Arslan - Idempotent Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) -- idempotent installation patterns
- [Scott Hanselman - CRLF Tips](https://www.hanselman.com/blog/carriage-returns-and-line-feeds-will-ultimately-bite-you-some-git-tips) -- Windows line ending management
- [Codequoi - tput vs ANSI](https://www.codequoi.com/en/coloring-terminal-text-tput-and-ansi-escape-sequences/) -- color output approaches
- [BATS-core GitHub](https://github.com/bats-core/bats-core) -- bash testing framework
- [Baeldung - Environment Variables from File](https://www.baeldung.com/linux/environment-variables-file) -- sourceable config.env patterns
- [wslu GitHub](https://github.com/wslutilities/wslu) -- confirmed archived March 2025

### Tertiary (LOW confidence)
- [WSL GitHub Issue #7371](https://github.com/microsoft/WSL/issues/7371) -- cmd.exe interop hang reports (community reports, timing varies)
- [Vampire/setup-wsl Discussion #20](https://github.com/Vampire/setup-wsl/discussions/20) -- .gitattributes for shell scripts in WSL context

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools verified via apt, ngrok apt repo confirmed via official docs
- Architecture: HIGH -- modular pattern established in ARCHITECTURE.md, locked in CONTEXT.md
- Pitfalls: HIGH -- all critical pitfalls verified against V1 code and WSL GitHub issues
- Windows username detection: HIGH -- three fallback methods documented, wslu deprecation confirmed
- ngrok installation: HIGH -- apt repo commands verified against ngrok.com official page
- Idempotency patterns: HIGH -- standard bash patterns verified across multiple sources
- Testing approach: MEDIUM -- BATS is standard but installer integration tests require real WSL2 environment

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (30 days -- stack is stable)
