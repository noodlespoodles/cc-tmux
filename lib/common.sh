#!/usr/bin/env bash
# ============================================
# lib/common.sh -- Shared utilities
#
# Provides: color output, logging, error handling,
#           idempotency guards, and system checks.
#
# Usage: This file is sourced by entry scripts.
#   source "$SCRIPT_DIR/lib/common.sh"
#
# Do NOT add set -euo pipefail here -- that
# belongs in the entry script that sources this.
# ============================================

# ------------------------------------------
# Color output with NO_COLOR support
# ------------------------------------------

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

# ------------------------------------------
# Logging functions
# ------------------------------------------

log_ok() {
    echo "  ${GREEN}[ok]${RESET} $*"
}

log_error() {
    echo "  ${RED}[error]${RESET} $*" >&2
    # Also append to error.log with timestamp (guard: dir must exist)
    if [[ -d "$HOME/.cc-tmux" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HOME/.cc-tmux/error.log"
    fi
}

log_warn() {
    echo "  ${YELLOW}[warn]${RESET} $*"
}

log_hint() {
    echo "       ${BLUE}$*${RESET}"
}

log_step() {
    local step_num="$1"
    local message="$2"
    echo "${BOLD}[$step_num/${TOTAL_STEPS:-?}] $message${RESET}"
}

# ------------------------------------------
# Package installation (idempotent)
# ------------------------------------------

install_package() {
    local pkg="$1"
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        log_ok "$pkg already installed"
    else
        if sudo apt install -y "$pkg"; then
            log_ok "$pkg installed"
        else
            log_error "Failed to install $pkg"
            log_hint "Try: sudo apt update && sudo apt install -y $pkg"
            return 1
        fi
    fi
}

# ------------------------------------------
# Idempotent .bashrc block management
# ------------------------------------------

add_bashrc_block() {
    local name="$1"
    local content="$2"
    local bashrc="$HOME/.bashrc"
    local start_marker="# CC-TMUX:${name}:START"
    local end_marker="# CC-TMUX:${name}:END"

    if grep -qF "$start_marker" "$bashrc" 2>/dev/null; then
        # Block exists -- replace it in place
        local tmpfile
        tmpfile=$(mktemp)
        awk -v start="$start_marker" -v end="$end_marker" -v content="$content" '
            $0 == start { skip=1; print; print content; next }
            $0 == end   { skip=0 }
            !skip       { print }
        ' "$bashrc" > "$tmpfile"
        # Append the end marker after content
        mv "$tmpfile" "$bashrc"
        log_ok "bashrc block '$name' updated"
    else
        # Block does not exist -- append it
        {
            echo ""
            echo "$start_marker"
            echo "$content"
            echo "$end_marker"
        } >> "$bashrc"
        log_ok "bashrc block '$name' added"
    fi
}

# ------------------------------------------
# File deployment (idempotent -- overwrite)
# ------------------------------------------

deploy_file() {
    local src="$1"
    local dst="$2"
    local perms="${3:-644}"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    chmod "$perms" "$dst"
}

# ------------------------------------------
# System requirement checks
# ------------------------------------------

require_wsl() {
    if ! grep -qi "microsoft" /proc/version 2>/dev/null; then
        log_error "This must run inside WSL2"
        log_hint "Open Ubuntu from Windows Terminal, then run this script"
        exit 1
    fi
}

require_sudo() {
    if ! sudo -v 2>/dev/null; then
        log_error "sudo access required"
        log_hint "Run: sudo echo test"
        exit 1
    fi
}

check_internet() {
    if ping -c 1 -W 3 archive.ubuntu.com &>/dev/null; then
        return 0
    else
        log_warn "Cannot reach archive.ubuntu.com -- apt install may fail"
        return 1
    fi
}

# ------------------------------------------
# Error log truncation
# ------------------------------------------

truncate_error_log() {
    local log_file="$HOME/.cc-tmux/error.log"
    if [[ -f "$log_file" ]]; then
        local line_count
        line_count=$(wc -l < "$log_file" 2>/dev/null) || return 0
        if [[ "$line_count" -gt 5000 ]]; then
            tail -n 1000 "$log_file" > "${log_file}.tmp"
            mv "${log_file}.tmp" "$log_file"
        fi
    fi
}

# ------------------------------------------
# Bashrc block removal (counterpart to add)
# ------------------------------------------

remove_bashrc_block() {
    local name="$1"
    local bashrc="$HOME/.bashrc"
    local start_marker="# CC-TMUX:${name}:START"

    if grep -qF "$start_marker" "$bashrc" 2>/dev/null; then
        sed -i "/# CC-TMUX:${name}:START/,/# CC-TMUX:${name}:END/d" "$bashrc"
        log_ok "bashrc block '$name' removed"
    else
        log_warn "bashrc block '$name' not found (already removed?)"
    fi
}

# ------------------------------------------
# Doctor output helpers
# ------------------------------------------

log_check_pass() { echo "  ${GREEN}[pass]${RESET} $*"; }
log_check_fail() { echo "  ${RED}[FAIL]${RESET} $*"; }

# ------------------------------------------
# Initialize colors on source
# ------------------------------------------
setup_colors
