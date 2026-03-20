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
    echo "  Copy everything between the lines below:"
    echo ""
    echo "  ---- BEGIN KEY (copy from here) ----"
    cat "$key_path"
    echo "  ---- END KEY (copy to here) ----"
    echo ""
    echo "  HOW TO IMPORT INTO TERMIUS (Android):"
    echo ""
    echo "  1. Open Termius on your phone"
    echo "  2. Tap Settings (gear icon)"
    echo "  3. Tap Keychain"
    echo "  4. Tap + (plus) to add a new key"
    echo "  5. Tap 'Paste from clipboard'"
    echo "  6. Paste the key you copied above"
    echo "  7. Give it a name like 'cc-tmux'"
    echo "  8. Tap Save"
    echo ""
    echo "  Then when setting up your SSH connection"
    echo "  in Termius, select this key instead of"
    echo "  using a password."
    echo ""
    echo "========================================"
}
