#!/usr/bin/env bash
# ============================================
# lib/update.sh -- Self-update management
#
# Provides: Git-based version check, dirty repo
#   handling, and re-deploy via step_deploy.
#
# Assumes lib/common.sh and lib/config.sh have
# already been sourced by the caller.
# ============================================

# ------------------------------------------
# Check for updates (local vs remote HEAD)
# ------------------------------------------

check_for_updates() {
    local repo_dir="$1"

    if [[ ! -d "$repo_dir/.git" ]]; then
        log_error "Not a git repository: $repo_dir"
        return 1
    fi

    local local_head
    local_head=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)

    local remote_head
    remote_head=$(timeout 10 git -C "$repo_dir" ls-remote origin HEAD 2>/dev/null | cut -f1)

    if [[ -z "$remote_head" ]]; then
        log_warn "Could not reach remote -- check your internet connection"
        return 1
    fi

    if [[ "$local_head" == "$remote_head" ]]; then
        log_ok "Already up to date (${local_head:0:8})"
        return 0
    fi

    echo "  Update available:"
    echo "    Local:  ${local_head:0:8}"
    echo "    Remote: ${remote_head:0:8}"
    return 2
}

# ------------------------------------------
# Handle dirty repo (uncommitted changes)
# ------------------------------------------

handle_dirty_repo() {
    local repo_dir="$1"

    local status
    status=$(git -C "$repo_dir" status --porcelain 2>/dev/null)

    if [[ -z "$status" ]]; then
        return 0
    fi

    log_warn "Uncommitted changes detected in $repo_dir"
    echo ""
    echo "  1) Stash changes and continue"
    echo "  2) Abort update"
    echo ""
    read -rp "  Choice [1/2]: " choice

    case "$choice" in
        1)
            git -C "$repo_dir" stash
            log_ok "Changes stashed"
            return 0
            ;;
        *)
            log_warn "Update aborted"
            return 1
            ;;
    esac
}

# ------------------------------------------
# Main update orchestrator
# ------------------------------------------

run_update() {
    local repo_dir
    repo_dir=$(get_config "CC_TMUX_REPO" 2>/dev/null) || repo_dir=""

    if [[ -z "$repo_dir" ]] || [[ ! -d "$repo_dir" ]]; then
        log_error "Repository path not found in config."
        log_hint "If you moved the repo, update CC_TMUX_REPO in ~/.cc-tmux/config.env"
        return 1
    fi

    # Check for updates
    check_for_updates "$repo_dir"
    local rc=$?

    if [[ $rc -eq 0 ]]; then
        return 0
    fi

    if [[ $rc -eq 1 ]]; then
        return 1
    fi

    # rc == 2: update available
    handle_dirty_repo "$repo_dir" || return 1

    # Backup config files
    cp "$CC_TMUX_DIR/config.env" "$CC_TMUX_DIR/config.env.bak"
    cp "$CC_TMUX_DIR/projects.conf" "$CC_TMUX_DIR/projects.conf.bak" 2>/dev/null || true
    log_ok "Config backed up (config.env.bak, projects.conf.bak)"

    # Pull latest changes (fast-forward only)
    if ! git -C "$repo_dir" pull --ff-only; then
        log_error "git pull failed -- you may have local commits that conflict"
        log_hint "Try: cd $repo_dir && git pull --rebase"
        return 1
    fi
    log_ok "Code updated"

    # Re-deploy from freshly pulled repo
    # Source from REPO directory (not ~/.cc-tmux/) so step_deploy finds new files
    source "$repo_dir/lib/common.sh"
    source "$repo_dir/lib/setup.sh"
    step_deploy

    # Restore user config files (step_deploy may have overwritten them)
    cp "$CC_TMUX_DIR/config.env.bak" "$CC_TMUX_DIR/config.env"
    cp "$CC_TMUX_DIR/projects.conf.bak" "$CC_TMUX_DIR/projects.conf" 2>/dev/null || true

    log_ok "Update complete! Restart your workspace to use the new version."
}
