#!/usr/bin/env bash
# ============================================
# lib/setup.sh -- System setup and deployment
#
# Provides: SSH config, sudoers, bashrc hook,
#           file deployment, and verification.
#
# Assumes lib/common.sh and lib/config.sh have
# already been sourced by the caller.
# ============================================

# ------------------------------------------
# SSH server configuration
# ------------------------------------------

setup_ssh_config() {
    sudo tee /etc/ssh/sshd_config.d/cc-tmux.conf > /dev/null <<'EOF'
# Managed by cc-tmux installer
ListenAddress 0.0.0.0
PasswordAuthentication yes
PubkeyAuthentication yes
EOF
    log_ok "SSH config written to /etc/ssh/sshd_config.d/cc-tmux.conf"

    # Generate host keys if missing
    sudo ssh-keygen -A 2>/dev/null
    log_ok "SSH host keys verified"

    # Restart SSH to apply config
    if sudo service ssh restart; then
        log_ok "SSH service restarted"
    else
        log_warn "SSH service restart failed -- may need manual start"
    fi
}

# ------------------------------------------
# Sudoers configuration (validated)
# ------------------------------------------

setup_sudoers() {
    local sudoers_file="/etc/sudoers.d/cc-tmux"
    local tmp_file="/tmp/cc-tmux-sudoers"

    # Write sudoers content to temp file
    cat > "$tmp_file" <<EOF
$USER ALL=(ALL) NOPASSWD: /usr/sbin/service ssh *, /usr/sbin/service fail2ban *, /usr/sbin/sshd -t, /usr/sbin/sshd -T, /usr/bin/fail2ban-client status *, /usr/bin/fail2ban-client status
EOF
    chmod 0440 "$tmp_file"

    # Validate syntax before deploying
    if sudo visudo -c -f "$tmp_file" &>/dev/null; then
        sudo cp "$tmp_file" "$sudoers_file"
        sudo chmod 0440 "$sudoers_file"
        rm -f "$tmp_file"
        log_ok "Sudoers configured: passwordless SSH service management"
    else
        rm -f "$tmp_file"
        log_error "Sudoers validation failed -- not deployed"
        log_hint "This is a safety check. The installer will still work, but you may need to enter your password for SSH service commands."
        return 1
    fi
}

# ------------------------------------------
# bashrc auto-attach hook
# ------------------------------------------

setup_bashrc_hook() {
    local hook_content
    hook_content='if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ]; then
    source "$HOME/.cc-tmux/templates/bashrc-hook.sh"
fi'

    add_bashrc_block "auto-attach" "$hook_content"
}

# ------------------------------------------
# Step: Configure system (SSH, sudoers, bashrc)
# ------------------------------------------

step_configure() {
    setup_ssh_config
    setup_sudoers
    setup_bashrc_hook
}

# ------------------------------------------
# Deploy tmux.conf from template
# ------------------------------------------

deploy_tmux_conf() {
    local win_username
    win_username=$(get_config "WIN_USERNAME")

    cp "$CC_TMUX_DIR/templates/tmux.conf.tpl" "$HOME/.tmux.conf"
    sed -i "s|__USERNAME__|$win_username|g" "$HOME/.tmux.conf"
    chmod 644 "$HOME/.tmux.conf"
    log_ok "tmux.conf deployed with username: $win_username"
}

# ------------------------------------------
# Deploy cc-tmux CLI to bin/
# ------------------------------------------

deploy_bin() {
    local repo_dir
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    mkdir -p "$CC_TMUX_DIR/bin"
    cp "$repo_dir/bin/cc-tmux" "$CC_TMUX_DIR/bin/cc-tmux"
    chmod 755 "$CC_TMUX_DIR/bin/cc-tmux"
    log_ok "cc-tmux CLI deployed to $CC_TMUX_DIR/bin/"
}

# ------------------------------------------
# Step: Deploy runtime files
# ------------------------------------------

step_deploy() {
    log_step 8 "Deploying runtime files..."

    local repo_dir
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    # Create target directories
    mkdir -p "$CC_TMUX_DIR/lib"
    mkdir -p "$CC_TMUX_DIR/templates"

    # Deploy lib/ files (sourced, not executed -- 644)
    for f in "$repo_dir"/lib/*.sh; do
        if [[ -f "$f" ]]; then
            deploy_file "$f" "$CC_TMUX_DIR/lib/$(basename "$f")" 644
        fi
    done
    log_ok "Library files deployed to $CC_TMUX_DIR/lib/"

    # Deploy lib/tunnel/ files (tunnel provider modules)
    if [[ -d "$repo_dir/lib/tunnel" ]]; then
        mkdir -p "$CC_TMUX_DIR/lib/tunnel"
        for f in "$repo_dir"/lib/tunnel/*.sh; do
            if [[ -f "$f" ]]; then
                deploy_file "$f" "$CC_TMUX_DIR/lib/tunnel/$(basename "$f")" 644
            fi
        done
        log_ok "Tunnel provider files deployed to $CC_TMUX_DIR/lib/tunnel/"
    fi

    # Deploy templates/ files
    for f in "$repo_dir"/templates/*; do
        if [[ -f "$f" ]]; then
            deploy_file "$f" "$CC_TMUX_DIR/templates/$(basename "$f")" 644
        fi
    done
    log_ok "Template files deployed to $CC_TMUX_DIR/templates/"

    # Make mobile-check.sh executable (called by tmux run-shell)
    chmod 755 "$CC_TMUX_DIR/templates/mobile-check.sh"

    # Deploy tmux.conf from template (substitutes __USERNAME__)
    deploy_tmux_conf

    # Deploy cc-tmux CLI
    deploy_bin
}

# ------------------------------------------
# Step: Verify installation
# ------------------------------------------

step_verify() {
    echo ""
    echo "${BOLD}Verifying installation...${RESET}"

    local pass=0
    local fail=0

    # Check tmux
    if command -v tmux &>/dev/null; then
        echo "  ${GREEN}[pass]${RESET} tmux installed ($(tmux -V 2>/dev/null || echo 'unknown'))"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} tmux not found"
        ((fail++))
    fi

    # Check ngrok
    if command -v ngrok &>/dev/null; then
        echo "  ${GREEN}[pass]${RESET} ngrok installed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} ngrok not found"
        ((fail++))
    fi

    # Check jq
    if command -v jq &>/dev/null; then
        echo "  ${GREEN}[pass]${RESET} jq installed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} jq not found"
        ((fail++))
    fi

    # Check fail2ban
    if dpkg -l fail2ban 2>/dev/null | grep -q "^ii"; then
        echo "  ${GREEN}[pass]${RESET} fail2ban installed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} fail2ban not installed"
        ((fail++))
    fi

    # Check config.env
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "  ${GREEN}[pass]${RESET} config.env exists"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} config.env not found"
        ((fail++))
    fi

    # Check projects.conf
    if [[ -f "$PROJECTS_FILE" ]]; then
        echo "  ${GREEN}[pass]${RESET} projects.conf exists"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} projects.conf not found"
        ((fail++))
    fi

    # Check runtime lib deployed
    if [[ -d "$CC_TMUX_DIR/lib" ]]; then
        echo "  ${GREEN}[pass]${RESET} runtime lib deployed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} runtime lib not deployed"
        ((fail++))
    fi

    # Check SSH key pair
    if [[ -f "$CC_TMUX_DIR/keys/cc-tmux_ed25519" ]]; then
        echo "  ${GREEN}[pass]${RESET} SSH key pair exists"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} SSH key pair not found"
        ((fail++))
    fi

    # Check hardened SSH config
    if [[ -f /etc/ssh/sshd_config.d/00-cc-tmux.conf ]]; then
        echo "  ${GREEN}[pass]${RESET} Hardened SSH config deployed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} Hardened SSH config not found"
        ((fail++))
    fi

    # Check fail2ban jail
    if [[ -f /etc/fail2ban/jail.d/cc-tmux.conf ]]; then
        echo "  ${GREEN}[pass]${RESET} fail2ban SSH jail configured"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} fail2ban SSH jail not configured"
        ((fail++))
    fi

    # Check tunnel provider deployed
    if [[ -f "$CC_TMUX_DIR/lib/tunnel/provider.sh" ]]; then
        echo "  ${GREEN}[pass]${RESET} Tunnel provider interface deployed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} Tunnel provider interface not deployed"
        ((fail++))
    fi

    # Check ngrok provider deployed
    if [[ -f "$CC_TMUX_DIR/lib/tunnel/ngrok.sh" ]]; then
        echo "  ${GREEN}[pass]${RESET} ngrok tunnel provider deployed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} ngrok tunnel provider not deployed"
        ((fail++))
    fi

    # Check tmux.conf deployed
    if [[ -f "$HOME/.tmux.conf" ]]; then
        echo "  ${GREEN}[pass]${RESET} tmux.conf deployed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} tmux.conf not found"
        ((fail++))
    fi

    # Check cc-tmux CLI deployed
    if [[ -x "$CC_TMUX_DIR/bin/cc-tmux" ]]; then
        echo "  ${GREEN}[pass]${RESET} cc-tmux CLI deployed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} cc-tmux CLI not found"
        ((fail++))
    fi

    # Check workspace module deployed
    if [[ -f "$CC_TMUX_DIR/lib/workspace.sh" ]]; then
        echo "  ${GREEN}[pass]${RESET} workspace module deployed"
        ((pass++))
    else
        echo "  ${RED}[fail]${RESET} workspace module not found"
        ((fail++))
    fi

    echo ""
    echo "  Results: ${GREEN}$pass passed${RESET}, ${RED}$fail failed${RESET}"
}

# ------------------------------------------
# Create Windows desktop shortcut
# ------------------------------------------

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
    if powershell.exe -NoProfile -Command "\$WshShell = New-Object -ComObject WScript.Shell; \$Shortcut = \$WshShell.CreateShortcut(\"\$env:USERPROFILE\\Desktop\\Claude Workspace.lnk\"); \$Shortcut.TargetPath = 'wsl.exe'; \$Shortcut.Arguments = '-d $wsl_distro -- bash -lc \"~/startup.sh\"'; \$Shortcut.IconLocation = 'C:\\Windows\\System32\\wsl.exe,0'; \$Shortcut.Save()" 2>/dev/null; then
        log_ok "Desktop shortcut created: Claude Workspace"
    else
        log_warn "Could not create desktop shortcut"
        log_hint "Create manually: see README.md"
    fi
}
