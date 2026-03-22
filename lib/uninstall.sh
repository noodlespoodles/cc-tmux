#!/usr/bin/env bash
# ============================================
# lib/uninstall.sh -- Clean uninstall
#
# Provides: Ordered teardown with confirmation
#   prompt. Removes configs, bashrc blocks,
#   and ~/.cc-tmux/ but NOT system packages.
#
# Assumes lib/common.sh and lib/config.sh have
# already been sourced by the caller.
# ============================================

# ------------------------------------------
# Main uninstall orchestrator
# ------------------------------------------

run_uninstall() {
    local skip_confirm=false

    if [[ "${1:-}" == "--yes" ]] || [[ "${1:-}" == "-y" ]]; then
        skip_confirm=true
    fi

    # Show what will be removed
    echo ""
    echo "  The following will be removed:"
    echo "    - ~/.cc-tmux/ directory (config, libs, templates)"
    echo "    - bashrc hooks (auto-attach, path)"
    echo "    - /etc/sudoers.d/cc-tmux"
    echo "    - /etc/ssh/sshd_config.d/00-cc-tmux.conf"
    echo "    - /etc/fail2ban/jail.d/cc-tmux.conf"
    echo "    - ~/.tmux.conf"
    echo "    - ~/startup.sh"
    echo "    - Claude Workspace desktop shortcut"
    echo "    - Windows Explorer context menu (if installed)"
    echo "    - Windows-side ~/.cc-tmux/ helper scripts (if deployed)"
    echo ""
    echo "  System packages (tmux, ngrok, fail2ban, openssh-server) will NOT be removed."
    echo ""

    # Confirmation prompt
    if [[ "$skip_confirm" != true ]]; then
        local confirm
        read -rp "  Type 'yes' to confirm: " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_warn "Uninstall aborted"
            return 0
        fi
    fi

    echo ""

    # ------------------------------------------
    # Phase 1: Stop running services
    # (needs ~/.cc-tmux files still present)
    # ------------------------------------------

    local session_name
    session_name=$(get_config "SESSION_NAME" 2>/dev/null) || session_name="work"

    # Stop tunnel
    if [[ -f "$CC_TMUX_DIR/lib/tunnel/provider.sh" ]]; then
        source "$CC_TMUX_DIR/lib/tunnel/provider.sh" 2>/dev/null || true
        if load_tunnel_provider 2>/dev/null; then
            tunnel_stop 2>/dev/null || true
        fi
    fi

    # Kill tmux session
    tmux kill-session -t "$session_name" 2>/dev/null || true
    log_ok "Services stopped"

    # ------------------------------------------
    # Phase 2: Remove system configs (sudo)
    # (grouped to minimize sudo prompts)
    # ------------------------------------------

    sudo rm -f /etc/sudoers.d/cc-tmux
    sudo rm -f /etc/ssh/sshd_config.d/00-cc-tmux.conf
    sudo rm -f /etc/fail2ban/jail.d/cc-tmux.conf
    sudo service ssh restart 2>/dev/null || true
    sudo service fail2ban restart 2>/dev/null || true
    if command -v powershell.exe &>/dev/null; then
        powershell.exe -NoProfile -Command "Remove-Item \"\$env:USERPROFILE\\Desktop\\Claude Workspace.lnk\" -ErrorAction SilentlyContinue" 2>/dev/null
        # Remove context menu entries
        powershell.exe -NoProfile -Command "
            Remove-Item -Path 'HKCU:\\Software\\Classes\\Directory\\shell\\cc-tmux' -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path 'HKCU:\\Software\\Classes\\Directory\\Background\\shell\\cc-tmux' -Recurse -Force -ErrorAction SilentlyContinue
        " 2>/dev/null
    fi

    # Remove context menu PS1 from Windows filesystem
    local win_home_path
    win_home_path=$(get_config "WIN_HOME" 2>/dev/null) || win_home_path="/mnt/c/Users/$(get_config WIN_USERNAME 2>/dev/null)"
    if [[ -n "$win_home_path" ]]; then
        rm -f "$win_home_path/.cc-tmux/open-in-cctmux.ps1"
        rmdir "$win_home_path/.cc-tmux" 2>/dev/null || true
    fi

    log_ok "System configs, shortcuts, and context menu removed"

    # ------------------------------------------
    # Phase 3: Remove bashrc blocks (no sudo)
    # ------------------------------------------

    remove_bashrc_block "auto-attach"
    remove_bashrc_block "path"

    # ------------------------------------------
    # Phase 4: Remove user files
    # ------------------------------------------

    rm -f "$HOME/.tmux.conf"
    rm -f "$HOME/startup.sh"
    log_ok "User files removed"

    # ------------------------------------------
    # Phase 5: Remove ~/.cc-tmux/ (LAST)
    # (script was sourced from here)
    # ------------------------------------------

    rm -rf "$CC_TMUX_DIR"
    log_ok "cc-tmux has been uninstalled"
    echo ""
    echo "  System packages (tmux, ngrok, fail2ban, openssh-server)"
    echo "  were NOT removed. Uninstall them manually if desired:"
    echo "    sudo apt remove tmux ngrok fail2ban openssh-server"
    echo ""
}
