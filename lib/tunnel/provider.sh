#!/usr/bin/env bash
# ============================================
# lib/tunnel/provider.sh -- Tunnel provider interface
#
# Provides: load_tunnel_provider() which sources
#   the configured provider and validates its interface.
#
# Assumes lib/common.sh and lib/config.sh have
# already been sourced by the caller.
# ============================================

# ------------------------------------------
# Provider directory (where this script lives)
# ------------------------------------------

TUNNEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------
# Load and validate tunnel provider
# ------------------------------------------

load_tunnel_provider() {
    local provider
    provider=$(get_config "TUNNEL_PROVIDER") || provider="ngrok"

    local provider_file="$TUNNEL_DIR/${provider}.sh"

    if [[ ! -f "$provider_file" ]]; then
        log_error "Tunnel provider '$provider' not found"
        log_hint "Available providers:"
        for f in "$TUNNEL_DIR"/*.sh; do
            [[ "$(basename "$f")" == "provider.sh" ]] && continue
            log_hint "  - $(basename "$f" .sh)"
        done
        return 1
    fi

    # shellcheck source=/dev/null
    source "$provider_file"

    # Validate provider implements the required interface
    local required_funcs=(tunnel_start tunnel_stop tunnel_status tunnel_url)
    for func in "${required_funcs[@]}"; do
        if ! declare -f "$func" &>/dev/null; then
            log_error "Provider '$provider' missing required function: $func"
            return 1
        fi
    done
}
