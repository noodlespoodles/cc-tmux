#!/usr/bin/env bash
# ============================================
# lib/detect.sh -- Environment detection
#
# Provides: Windows username detection with
#           tiered fallback, WSL distro detection,
#           and Windows home path resolution.
#
# Assumes lib/common.sh has already been sourced
# by the caller (uses log_ok, log_warn, etc.).
# ============================================

# ------------------------------------------
# Windows username detection (tiered fallback)
# ------------------------------------------

detect_windows_username() {
    local username=""

    # Method 1: cmd.exe with timeout (fastest, most common)
    username=$(timeout 5 cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)
    if [[ -n "$username" && "$username" != "%USERNAME%" ]]; then
        echo "$username"
        return 0
    fi

    # Method 2: Parse /mnt/c/Users/ directory
    local candidates=()
    if [[ -d "/mnt/c/Users" ]]; then
        while IFS= read -r dir; do
            local name
            name=$(basename "$dir")
            case "$name" in
                Default|"Default User"|Public|"All Users"|desktop.ini)
                    continue
                    ;;
                *)
                    candidates+=("$name")
                    ;;
            esac
        done < <(ls -d /mnt/c/Users/*/ 2>/dev/null)

        if [[ ${#candidates[@]} -eq 1 ]]; then
            echo "${candidates[0]}"
            return 0
        elif [[ ${#candidates[@]} -gt 1 ]]; then
            log_warn "Multiple Windows users found: ${candidates[*]}"
            return 1
        fi
    fi

    # Method 3: Fall through to interactive prompt (caller handles)
    return 1
}

# ------------------------------------------
# WSL distro detection
# ------------------------------------------

detect_wsl_distro() {
    # Method 1: Environment variable (set by WSL)
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        echo "$WSL_DISTRO_NAME"
        return 0
    fi

    # Method 2: Parse /etc/os-release
    if [[ -f /etc/os-release ]]; then
        local distro_name
        distro_name=$(. /etc/os-release && echo "$NAME")
        if [[ -n "$distro_name" ]]; then
            echo "$distro_name"
            return 0
        fi
    fi

    return 1
}

# ------------------------------------------
# Windows home directory resolution
# ------------------------------------------

detect_win_home() {
    local win_username="$1"
    local win_home="/mnt/c/Users/$win_username"

    if [[ -d "$win_home" ]]; then
        echo "$win_home"
        return 0
    else
        log_warn "Windows home not found: $win_home"
        return 1
    fi
}
