#!/usr/bin/env bash
# ============================================
# install.sh -- CC-TMUX v2 Installer
#
# Single entry point for installing cc-tmux.
# Sources lib/ modules for each capability.
#
# Usage:
#   bash install.sh          # Interactive mode
#   bash install.sh --yes    # Non-interactive mode
# ============================================

# Self-heal CRLF if cloned on Windows without .gitattributes
if head -1 "$0" | grep -q $'\r'; then
    echo "Fixing Windows line endings..."
    find "$(dirname "$0")" -name "*.sh" -exec sed -i 's/\r$//' {} +
    exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------
# Source library modules
# ------------------------------------------

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/deps.sh"
source "$SCRIPT_DIR/lib/setup.sh"
source "$SCRIPT_DIR/lib/ssh-hardening.sh"
source "$SCRIPT_DIR/lib/tunnel/provider.sh"

# ------------------------------------------
# Argument parsing
# ------------------------------------------

NONINTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) NONINTERACTIVE=true; shift ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

export NONINTERACTIVE

# ------------------------------------------
# Banner
# ------------------------------------------

print_banner() {
    echo ""
    echo "========================================"
    echo "  Claude Code x tmux -- Installer v2"
    echo "========================================"
    echo ""
}

# ------------------------------------------
# Step 1: Preflight checks
# ------------------------------------------

step_preflight() {
    log_step 1 "Running preflight checks..."

    require_wsl
    log_ok "Running in WSL2"

    require_sudo
    log_ok "sudo access confirmed"

    if check_internet; then
        log_ok "Internet connectivity"
    fi

    # Check bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
        log_error "Bash 5.0+ required (found ${BASH_VERSION})"
        log_hint "Update: sudo apt install bash"
        exit 1
    fi
    log_ok "Bash ${BASH_VERSION}"
}

# ------------------------------------------
# Step 4: Detect environment
# ------------------------------------------

step_detect_environment() {
    log_step 4 "Detecting environment..."

    # Detect Windows username
    WIN_USERNAME=""
    WIN_USERNAME=$(detect_windows_username) || true

    if [[ -z "$WIN_USERNAME" ]]; then
        if [[ "$NONINTERACTIVE" == true ]]; then
            # Try to find a non-system user in /mnt/c/Users/
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
            fi

            if [[ ${#candidates[@]} -ge 1 ]]; then
                WIN_USERNAME="${candidates[0]}"
                log_ok "Auto-detected Windows user: $WIN_USERNAME"
            else
                log_error "Could not detect Windows username in non-interactive mode"
                log_hint "Run without --yes flag, or ensure /mnt/c/Users/ is accessible"
                exit 1
            fi
        else
            read -rp "  What is your Windows username? " WIN_USERNAME
            if [[ -z "$WIN_USERNAME" ]]; then
                log_error "Windows username is required"
                exit 1
            fi
        fi
    else
        log_ok "Windows user: $WIN_USERNAME"
    fi

    # Detect WSL distro
    WSL_DISTRO=""
    WSL_DISTRO=$(detect_wsl_distro) || true
    if [[ -n "$WSL_DISTRO" ]]; then
        log_ok "WSL distro: $WSL_DISTRO"
    else
        WSL_DISTRO="Unknown"
        log_warn "Could not detect WSL distro name"
    fi

    # Detect Windows home path
    WIN_HOME=""
    WIN_HOME=$(detect_win_home "$WIN_USERNAME") || true
    if [[ -n "$WIN_HOME" ]]; then
        log_ok "Windows home: $WIN_HOME"
    else
        WIN_HOME="/mnt/c/Users/$WIN_USERNAME"
        log_warn "Using default Windows home: $WIN_HOME"
    fi

    export WIN_USERNAME WSL_DISTRO WIN_HOME
}

# ------------------------------------------
# Step 5: Configure
# ------------------------------------------

step_configure() {
    log_step 5 "Writing configuration..."

    ensure_config_dir

    write_config \
        CC_TMUX_VERSION "2.0.0" \
        CC_TMUX_INSTALL_DATE "$(date +%Y-%m-%d)" \
        CC_TMUX_REPO "$SCRIPT_DIR" \
        WIN_USERNAME "$WIN_USERNAME" \
        WIN_HOME "$WIN_HOME" \
        WSL_DISTRO "$WSL_DISTRO" \
        TUNNEL_PROVIDER "ngrok" \
        SESSION_NAME "work"

    log_ok "Configuration written to $CONFIG_FILE"

    # Set up ngrok auth token
    setup_ngrok_token

    # Interactive project setup
    if [[ -f "$PROJECTS_FILE" ]] && [[ -s "$PROJECTS_FILE" ]]; then
        log_ok "Projects already configured ($(project_count) projects)"
        return 0
    fi

    if [[ "$NONINTERACTIVE" == true ]]; then
        add_project "home" "$WIN_HOME/Documents"
        return 0
    fi

    # Interactive project loop
    echo ""
    echo "  Add project folders that will become tabs in your workspace."
    echo "  Give each project a short name and its path."
    echo ""

    local added=0
    while true; do
        read -rp "  Project name (or 'done' to finish): " name

        [[ "$name" == "done" || -z "$name" ]] && break

        read -rp "  Folder path [$WIN_HOME/Documents]: " path
        path="${path:-$WIN_HOME/Documents}"

        # Validate path exists
        if [[ ! -d "$path" ]]; then
            log_warn "Path does not exist: $path"
            read -rp "  Add anyway? (y/N): " confirm
            [[ "$confirm" != [yY] ]] && continue
        fi

        add_project "$name" "$path"
        ((added++))
        echo ""
    done

    # Default if none added
    if [[ $added -eq 0 ]]; then
        add_project "home" "$WIN_HOME/Documents"
        log_warn "No projects added. Using default: home -> $WIN_HOME/Documents"
    fi
}

# ------------------------------------------
# Step 6: System setup
# ------------------------------------------

step_setup_system() {
    log_step 6 "Configuring system..."

    setup_ssh_config
    setup_sudoers
    setup_bashrc_hook
}

# ------------------------------------------
# Summary
# ------------------------------------------

print_summary() {
    local num_projects
    num_projects=$(project_count)

    echo ""
    echo "========================================"
    echo "  Installation complete!"
    echo "========================================"
    echo ""
    echo "  Your config:    ~/.cc-tmux/config.env"
    echo "  Your projects:  ~/.cc-tmux/projects.conf"
    echo "  Projects:       $num_projects configured"
    echo ""
    echo "  Next steps:"
    echo ""
    echo "  1. Start your workspace:"
    echo "     bash ~/startup.sh"
    echo ""
    echo "  2. Set up Termius on your phone:"
    echo "     Hostname and port will be shown at startup"
    echo "     Username: $USER"
    echo ""
    echo "  Run 'bash install.sh' again anytime -- it's safe to re-run."
    echo ""
}

# ------------------------------------------
# Main
# ------------------------------------------

main() {
    TOTAL_STEPS=9
    export TOTAL_STEPS

    print_banner

    step_preflight          # [1/9]
    step_install_deps       # [2/9]
    step_install_ngrok      # [3/9]
    step_detect_environment # [4/9]
    step_configure          # [5/9]
    step_setup_system       # [6/9]
    log_step 7 "Hardening SSH security..."
    step_harden_ssh         # [7/9]
    step_deploy             # [8/9]
    log_step 9 "Deploying startup script..."
    deploy_file "$SCRIPT_DIR/startup.sh" "$HOME/startup.sh" 755
    log_ok "startup.sh deployed to ~/startup.sh"
    step_verify             # Final verification

    print_summary
}

main "$@"
