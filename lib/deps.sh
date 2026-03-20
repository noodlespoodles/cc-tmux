#!/usr/bin/env bash
# ============================================
# lib/deps.sh -- Dependency installation
#
# Provides: apt package installation and ngrok
#           setup via apt repository (NOT snap).
#
# Assumes lib/common.sh has already been sourced
# by the caller (uses log_ok, log_error, etc.).
# ============================================

# ------------------------------------------
# Step: Install apt packages
# ------------------------------------------

step_install_deps() {
    log_step 2 "Installing system dependencies..."

    sudo apt update -qq 2>/dev/null

    install_package "tmux"
    install_package "openssh-server"
    install_package "jq"
    install_package "fail2ban"
    install_package "qrencode"
}

# ------------------------------------------
# ngrok installation via apt repository
# ------------------------------------------

install_ngrok() {
    if command -v ngrok &>/dev/null; then
        log_ok "ngrok already installed ($(ngrok version 2>/dev/null || echo 'unknown'))"
        return 0
    fi

    # Add GPG signing key
    if ! curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null; then
        log_error "Failed to download ngrok signing key"
        log_hint "Check your internet connection and try again"
        return 1
    fi

    # Add apt repository
    if ! echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null; then
        log_error "Failed to add ngrok apt repository"
        return 1
    fi

    # Install ngrok
    sudo apt update -qq 2>/dev/null
    if sudo apt install -y ngrok; then
        log_ok "ngrok installed ($(ngrok version 2>/dev/null || echo 'unknown'))"
    else
        log_error "Failed to install ngrok"
        log_hint "Try manually: sudo apt update && sudo apt install ngrok"
        return 1
    fi
}

# ------------------------------------------
# Step: Install ngrok
# ------------------------------------------

step_install_ngrok() {
    log_step 3 "Installing ngrok..."
    install_ngrok
}

# ------------------------------------------
# ngrok auth token setup (interactive)
# ------------------------------------------

setup_ngrok_token() {
    # Check if already configured
    if ngrok config check &>/dev/null; then
        log_ok "ngrok auth token already configured"
        return 0
    fi

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
        if ngrok config add-authtoken "$token"; then
            log_ok "ngrok auth token saved"
        else
            log_error "Failed to save ngrok token"
            return 1
        fi
    else
        log_warn "Skipped. Run later: ngrok config add-authtoken YOUR_TOKEN"
    fi
}
