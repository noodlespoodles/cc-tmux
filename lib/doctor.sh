#!/usr/bin/env bash
# ============================================
# lib/doctor.sh -- Health diagnostics
#
# Provides: Modular check functions and
#   run_doctor orchestrator for system health.
#
# Assumes lib/common.sh and lib/config.sh have
# already been sourced by the caller.
#
# Doctor diagnoses only -- does NOT attempt
# any auto-fix, service start, or config write.
# ============================================

# ------------------------------------------
# Check: WSL2 environment
# ------------------------------------------

check_wsl() {
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
        log_check_pass "Running inside WSL2"
        return 0
    else
        log_check_fail "Not running inside WSL2"
        log_hint "Fix: This tool is designed for WSL2. Run inside Ubuntu from Windows Terminal."
        return 1
    fi
}

# ------------------------------------------
# Check: tmux installed
# ------------------------------------------

check_tmux() {
    if command -v tmux &>/dev/null; then
        log_check_pass "tmux installed ($(tmux -V 2>/dev/null || echo 'unknown version'))"
        return 0
    else
        log_check_fail "tmux not found"
        log_hint "Fix: sudo apt install tmux"
        return 1
    fi
}

# ------------------------------------------
# Check: SSH service running
# ------------------------------------------

check_ssh_service() {
    if sudo -n service ssh status &>/dev/null; then
        log_check_pass "SSH service running"
        return 0
    else
        log_check_fail "SSH service not running"
        log_hint "Fix: sudo service ssh start"
        return 1
    fi
}

# ------------------------------------------
# Check: Hardened SSHD config
# ------------------------------------------

check_sshd_config() {
    if [[ -f /etc/ssh/sshd_config.d/00-cc-tmux.conf ]]; then
        if sudo -n sshd -t &>/dev/null; then
            log_check_pass "Hardened SSH config valid"
            return 0
        else
            log_check_fail "Hardened SSH config has errors"
            log_hint "Fix: re-run install.sh to regenerate SSH config"
            return 1
        fi
    else
        log_check_fail "Hardened SSH config not found"
        log_hint "Fix: re-run install.sh to regenerate SSH config"
        return 1
    fi
}

# ------------------------------------------
# Check: SSH key pair
# ------------------------------------------

check_ssh_keys() {
    if [[ -f "$CC_TMUX_DIR/keys/cc-tmux_ed25519" ]]; then
        log_check_pass "SSH key pair exists"
        return 0
    else
        log_check_fail "SSH key pair not found"
        log_hint "Fix: re-run install.sh to regenerate SSH keys"
        return 1
    fi
}

# ------------------------------------------
# Check: fail2ban
# ------------------------------------------

check_fail2ban() {
    if ! dpkg -l fail2ban 2>/dev/null | grep -q "^ii"; then
        log_check_fail "fail2ban not installed"
        log_hint "Fix: sudo apt install fail2ban"
        return 1
    fi

    if sudo -n fail2ban-client status sshd &>/dev/null; then
        log_check_pass "fail2ban active (sshd jail running)"
        return 0
    else
        log_check_fail "fail2ban sshd jail not running"
        log_hint "Fix: sudo service fail2ban restart"
        return 1
    fi
}

# ------------------------------------------
# Check: ngrok
# ------------------------------------------

check_ngrok() {
    if ! command -v ngrok &>/dev/null; then
        log_check_fail "ngrok not found"
        log_hint "Fix: sudo apt install ngrok"
        return 1
    fi

    if ngrok config check &>/dev/null; then
        log_check_pass "ngrok installed (auth token configured)"
        return 0
    else
        log_check_pass "ngrok installed (auth token not configured)"
        log_hint "Fix: ngrok config add-authtoken YOUR_TOKEN"
        return 0
    fi
}

# ------------------------------------------
# Check: Tunnel provider files deployed
# ------------------------------------------

check_tunnel_files() {
    if [[ -f "$CC_TMUX_DIR/lib/tunnel/provider.sh" ]] && [[ -f "$CC_TMUX_DIR/lib/tunnel/ngrok.sh" ]]; then
        log_check_pass "Tunnel provider files deployed"
        return 0
    else
        log_check_fail "Tunnel provider files missing"
        log_hint "Fix: re-run install.sh to redeploy files"
        return 1
    fi
}

# ------------------------------------------
# Check: config.env exists
# ------------------------------------------

check_config() {
    if [[ -f "$CC_TMUX_DIR/config.env" ]]; then
        log_check_pass "config.env exists"
        return 0
    else
        log_check_fail "config.env not found"
        log_hint "Fix: re-run install.sh"
        return 1
    fi
}

# ------------------------------------------
# Check: projects.conf exists and non-empty
# ------------------------------------------

check_projects() {
    if [[ -f "$CC_TMUX_DIR/projects.conf" ]] && [[ -s "$CC_TMUX_DIR/projects.conf" ]]; then
        log_check_pass "projects.conf exists ($(wc -l < "$CC_TMUX_DIR/projects.conf" | tr -d ' ') projects)"
        return 0
    else
        log_check_fail "projects.conf missing or empty"
        log_hint "Fix: cc-tmux project add <name> <path>"
        return 1
    fi
}

# ------------------------------------------
# Check: Directory structure
# ------------------------------------------

check_directory_structure() {
    if [[ -d "$CC_TMUX_DIR/lib" ]] && [[ -d "$CC_TMUX_DIR/templates" ]] && [[ -d "$CC_TMUX_DIR/bin" ]]; then
        log_check_pass "Directory structure intact (lib, templates, bin)"
        return 0
    else
        log_check_fail "Directory structure incomplete"
        log_hint "Fix: re-run install.sh to redeploy"
        return 1
    fi
}

# ------------------------------------------
# Check: tmux.conf deployed
# ------------------------------------------

check_tmux_conf() {
    if [[ -f "$HOME/.tmux.conf" ]]; then
        log_check_pass "tmux.conf deployed"
        return 0
    else
        log_check_fail "tmux.conf not found"
        log_hint "Fix: re-run install.sh to deploy tmux.conf"
        return 1
    fi
}

# ------------------------------------------
# Check: cc-tmux CLI deployed and executable
# ------------------------------------------

check_cli() {
    if [[ -f "$CC_TMUX_DIR/bin/cc-tmux" ]] && [[ -x "$CC_TMUX_DIR/bin/cc-tmux" ]]; then
        log_check_pass "cc-tmux CLI deployed"
        return 0
    else
        log_check_fail "cc-tmux CLI not found or not executable"
        log_hint "Fix: re-run install.sh to deploy CLI"
        return 1
    fi
}

# ------------------------------------------
# Orchestrator: run all checks
# ------------------------------------------

run_doctor() {
    local pass=0 fail=0

    echo ""
    echo "${BOLD}CC-TMUX Health Check${RESET}"
    echo "--------------------"
    echo ""

    check_wsl              && ((pass++)) || ((fail++))
    check_tmux             && ((pass++)) || ((fail++))
    check_ssh_service      && ((pass++)) || ((fail++))
    check_sshd_config      && ((pass++)) || ((fail++))
    check_ssh_keys         && ((pass++)) || ((fail++))
    check_fail2ban         && ((pass++)) || ((fail++))
    check_ngrok            && ((pass++)) || ((fail++))
    check_tunnel_files     && ((pass++)) || ((fail++))
    check_config           && ((pass++)) || ((fail++))
    check_projects         && ((pass++)) || ((fail++))
    check_directory_structure && ((pass++)) || ((fail++))
    check_tmux_conf        && ((pass++)) || ((fail++))
    check_cli              && ((pass++)) || ((fail++))

    echo ""
    echo "  Results: ${GREEN}$pass passed${RESET}, ${RED}$fail failed${RESET}"
    echo ""

    [[ $fail -eq 0 ]]
}
