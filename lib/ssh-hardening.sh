#!/usr/bin/env bash
# ============================================
# lib/ssh-hardening.sh -- SSH security hardening
#
# Provides: Ed25519 key generation, sshd config
#           hardening, fail2ban setup, and key
#           display for phone import.
#
# Assumes lib/common.sh and lib/config.sh have
# already been sourced by the caller.
# ============================================

# ------------------------------------------
# Ed25519 key pair generation (idempotent)
# ------------------------------------------

generate_ssh_keys() {
    local key_dir="$CC_TMUX_DIR/keys"
    local key_path="$key_dir/cc-tmux_ed25519"

    mkdir -p "$key_dir"
    chmod 700 "$key_dir"

    if [[ -f "$key_path" ]]; then
        log_ok "SSH key pair already exists"
        return 0
    fi

    ssh-keygen -t ed25519 -f "$key_path" -N "" -C "cc-tmux-$(date +%Y%m%d)"
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"

    write_config CC_TMUX_SSH_KEY "$key_path"
    log_ok "Ed25519 key pair generated at $key_path"
}

# ------------------------------------------
# Public key installation (idempotent)
# ------------------------------------------

install_public_key() {
    local pub_key_path="$CC_TMUX_DIR/keys/cc-tmux_ed25519.pub"
    local auth_keys="$HOME/.ssh/authorized_keys"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    local pub_key
    pub_key=$(cat "$pub_key_path")

    if grep -qF "$pub_key" "$auth_keys" 2>/dev/null; then
        log_ok "Public key already in authorized_keys"
        return 0
    fi

    echo "$pub_key" >> "$auth_keys"
    chmod 600 "$auth_keys"
    log_ok "Public key added to authorized_keys"
}

# ------------------------------------------
# Private key display with Termius instructions
# ------------------------------------------

display_key_instructions() {
    local key_path="$1"
    local win_home="${WIN_HOME:-/mnt/c/Users/$USER}"
    local desktop_path="$win_home/Desktop"
    local key_filename="cc-tmux-key.txt"
    local saved_path=""

    echo ""
    echo "========================================"
    echo "  Your SSH Private Key"
    echo "========================================"
    echo ""
    echo "  WHY: Your SSH connection now requires"
    echo "  a key instead of a password. This is"
    echo "  much more secure -- like a lock that"
    echo "  only your specific key can open."
    echo ""

    # Copy key file to Windows Desktop for easy transfer
    if [[ -d "$desktop_path" ]]; then
        cp "$key_path" "$desktop_path/$key_filename"
        saved_path="$desktop_path/$key_filename"
        log_ok "Key saved to your Desktop: $key_filename"
    elif [[ -d "$win_home/Documents" ]]; then
        cp "$key_path" "$win_home/Documents/$key_filename"
        saved_path="$win_home/Documents/$key_filename"
        log_ok "Key saved to your Documents: $key_filename"
    else
        # Fallback: just display the key
        echo "  Could not find Desktop or Documents folder."
        echo "  Key file is at: $key_path"
        echo ""
        cat "$key_path"
        echo ""
    fi

    echo ""
    echo "  HOW TO GET THE KEY TO YOUR PHONE:"
    echo ""
    if [[ -n "$saved_path" ]]; then
        echo "  1. Find '$key_filename' on your Desktop"
        echo "  2. Email it to yourself, or transfer via"
        echo "     Google Drive / OneDrive / USB"
        echo "  3. On your phone, download the file"
    else
        echo "  1. Copy the key from: $key_path"
        echo "  2. Email it to yourself"
        echo "  3. On your phone, download the file"
    fi
    echo ""
    echo "  HOW TO IMPORT INTO TERMIUS (Android):"
    echo ""
    echo "  1. Open Termius on your phone"
    echo "  2. Tap Settings (gear icon)"
    echo "  3. Tap Keychain"
    echo "  4. Tap + (plus) to add a new key"
    echo "  5. Tap 'Import from file'"
    echo "  6. Select the key file you transferred"
    echo "  7. Give it a name like 'cc-tmux'"
    echo "  8. Tap Save"
    echo ""
    echo "  Then when setting up your SSH connection"
    echo "  in Termius, select this key instead of"
    echo "  using a password."
    echo ""
    if [[ -n "$saved_path" ]]; then
        echo "  ${YELLOW:-}[!]${RESET:-} DELETE the key file from your"
        echo "      Desktop after importing it to your phone."
        echo "      Private keys should not be left lying around."
        echo ""
    fi
    echo "========================================"
}

# ------------------------------------------
# Hardened sshd drop-in config
# ------------------------------------------

write_hardened_ssh_config() {
    local current_user
    current_user=$(whoami)
    local conf="/etc/ssh/sshd_config.d/00-cc-tmux.conf"

    # Remove old Phase 1 drop-in (different filename)
    sudo rm -f /etc/ssh/sshd_config.d/cc-tmux.conf

    # Write hardened config
    sudo tee "$conf" > /dev/null <<EOF
# Managed by cc-tmux installer -- Phase 2 hardened config
# Do not edit manually; re-run installer to regenerate

ListenAddress 0.0.0.0

# Authentication -- key-only for remote connections
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
PermitEmptyPasswords no

# Access control
AllowUsers $current_user

# Security hardening
X11Forwarding no
ClientAliveInterval 120
ClientAliveCountMax 3

# Localhost safety net -- password auth on loopback
Match Address 127.0.0.1,::1
    PasswordAuthentication yes
EOF

    # Validate config before restarting
    if sudo sshd -t; then
        log_ok "SSH config syntax valid"
    else
        log_error "SSH config syntax invalid -- rolling back"
        # Rollback: restore minimal safe config
        sudo tee "$conf" > /dev/null <<'ROLLBACK'
# Managed by cc-tmux installer -- rollback safe config
ListenAddress 0.0.0.0
PasswordAuthentication yes
PubkeyAuthentication yes
ROLLBACK
        return 1
    fi

    sudo service ssh restart
    log_ok "SSH hardened: key-only auth (password on localhost only)"
}

# ------------------------------------------
# fail2ban SSH jail configuration
# ------------------------------------------

configure_fail2ban() {
    local jail_conf="/etc/fail2ban/jail.d/cc-tmux.conf"

    # Auto-detect backend
    local backend
    if [[ -f /var/log/auth.log ]]; then
        backend="auto"
    elif systemctl is-active systemd-journald &>/dev/null; then
        backend="systemd"
    else
        backend="auto"
    fi

    sudo tee "$jail_conf" > /dev/null <<EOF
# Managed by cc-tmux installer
[sshd]
enabled = true
port = ssh
filter = sshd
backend = $backend
maxretry = 5
bantime = 600
findtime = 600
EOF

    sudo service fail2ban restart

    if sudo fail2ban-client status sshd &>/dev/null; then
        log_ok "fail2ban sshd jail active"
    else
        log_warn "fail2ban sshd jail not responding -- may need manual check"
    fi
}

# ------------------------------------------
# Orchestrator: full SSH hardening sequence
# ------------------------------------------

step_harden_ssh() {
    generate_ssh_keys
    install_public_key
    display_key_instructions "$CC_TMUX_DIR/keys/cc-tmux_ed25519"

    # Interactive confirmation before disabling password auth
    if [[ "${NONINTERACTIVE:-false}" != "true" ]]; then
        echo ""
        echo "  ${YELLOW}[!]${RESET} Password authentication will be DISABLED for remote SSH."
        echo "      Make sure you have copied the key above to your phone."
        echo ""
        read -rp "  Continue? (Y/n): " confirm
        if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            log_warn "Skipped SSH hardening. Password auth remains enabled."
            return 0
        fi
    fi

    write_hardened_ssh_config
    configure_fail2ban
    log_ok "SSH security hardening complete"
}
