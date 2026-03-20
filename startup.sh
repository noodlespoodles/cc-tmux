#!/usr/bin/env bash
# ============================================
# startup.sh -- Start cc-tmux workspace
#
# Starts SSH, tunnel, and attaches to tmux.
# Deployed to ~/startup.sh by the installer.
#
# Usage: bash ~/startup.sh
# ============================================

set -euo pipefail

# ------------------------------------------
# Source runtime libraries from deployed location
# ------------------------------------------

CC_TMUX_DIR="$HOME/.cc-tmux"

if [[ ! -d "$CC_TMUX_DIR/lib" ]]; then
    echo "cc-tmux not installed. Run install.sh first."
    exit 1
fi

source "$CC_TMUX_DIR/lib/common.sh"
source "$CC_TMUX_DIR/lib/config.sh"
source "$CC_TMUX_DIR/lib/tunnel/provider.sh"
source "$CC_TMUX_DIR/lib/workspace.sh"

# ------------------------------------------
# QR code display for phone onboarding
# ------------------------------------------

show_qr_code() {
    local addr="$1"  # host:port format
    local host="${addr%:*}"
    local port="${addr##*:}"
    local ssh_uri="ssh://$USER@$host:$port"

    if command -v qrencode &>/dev/null; then
        echo ""
        echo "  Scan to connect from phone:"
        echo ""
        qrencode -t ANSIUTF8 -m 1 "$ssh_uri"
        echo ""
    else
        echo "  (Install qrencode for a scannable QR code: sudo apt install qrencode)"
    fi
}

# ------------------------------------------
# Main
# ------------------------------------------

main() {
    # Banner
    echo ""
    echo "========================================"
    echo "  CC-TMUX -- Starting workspace"
    echo "========================================"
    echo ""

    # ------------------------------------------
    # 1. Start SSH server
    # ------------------------------------------

    if sudo -n service ssh start 2>/dev/null; then
        log_ok "SSH server running"
    else
        log_warn "Could not start SSH (may already be running)"
    fi

    # ------------------------------------------
    # 2. Load and start tunnel (warn but continue on failure)
    # ------------------------------------------

    local tunnel_available=false

    if load_tunnel_provider; then
        if tunnel_start; then
            # tunnel_start already logs success and prints URL
            tunnel_available=true
        else
            log_warn "Tunnel failed to start -- workspace will run locally"
            log_hint "Check: ngrok config check"
            log_hint "Or run later: source ~/.cc-tmux/lib/tunnel/provider.sh && load_tunnel_provider && tunnel_start"
        fi
    else
        log_warn "Tunnel provider not available -- workspace will run locally"
    fi

    # ------------------------------------------
    # 3. Workspace session (creates project tabs from config)
    # ------------------------------------------

    local SESSION_NAME
    SESSION_NAME=$(get_config "SESSION_NAME" 2>/dev/null) || SESSION_NAME="work"

    workspace_init
    log_ok "Workspace ready"

    # ------------------------------------------
    # 4. Display connection info before attaching
    # ------------------------------------------

    echo ""
    echo "========================================"
    if [[ "$tunnel_available" == true ]] && declare -f tunnel_url &>/dev/null && tunnel_url &>/dev/null; then
        local addr
        addr=$(tunnel_url)
        echo "  Workspace is running!"
        echo ""
        echo "  SSH from phone:"
        echo "    Host: ${addr%:*}"
        echo "    Port: ${addr##*:}"
        echo "    User: $USER"
        echo ""
        echo "  Or: ssh -p ${addr##*:} $USER@${addr%:*}"
        show_qr_code "$addr"
    else
        echo "  Workspace is running (local only)"
        echo "  Tunnel not connected -- check: tunnel_status"
    fi
    echo "========================================"
    echo ""

    # ------------------------------------------
    # 5. Attach to tmux (exec replaces shell process)
    # ------------------------------------------

    exec tmux attach -t "$SESSION_NAME"
}

main "$@"
