#!/usr/bin/env bash
# ============================================
# lib/workspace.sh -- Workspace management
#
# Provides: workspace_init() and workspace_attach()
#   for config-driven tmux session creation
#   from ~/.cc-tmux/projects.conf
#
# Assumes lib/common.sh and lib/config.sh have
# already been sourced by the caller.
# ============================================

# ------------------------------------------
# workspace_init -- Create tmux session
#   from projects.conf (idempotent)
# ------------------------------------------

workspace_init() {
    local session_name
    session_name=$(get_config "SESSION_NAME" 2>/dev/null) || session_name="work"

    # Already running -- skip (idempotent)
    if tmux has-session -t "$session_name" 2>/dev/null; then
        return 0
    fi

    local projects_file="$CC_TMUX_DIR/projects.conf"

    # Fallback if no projects configured
    if [[ ! -f "$projects_file" ]] || [[ ! -s "$projects_file" ]]; then
        local win_home
        win_home=$(get_config "WIN_HOME" 2>/dev/null) || win_home="/mnt/c/Users/$USER/Documents"
        tmux new-session -d -s "$session_name" -n "default" -c "$win_home"
        tmux send-keys -t "$session_name:default" "powershell.exe" Enter
        return 0
    fi

    # Read projects and create windows
    local first=true
    while IFS='|' read -r name path; do
        # Skip empty lines and lines where name is empty
        [[ -z "$name" ]] && continue

        if [[ "$first" == true ]]; then
            # First project -- create session with it
            tmux new-session -d -s "$session_name" -n "$name" -c "$path"
            tmux send-keys -t "$session_name:$name" "powershell.exe" Enter
            first=false
        else
            # Remaining projects -- add windows
            tmux new-window -t "$session_name" -n "$name" -c "$path"
            tmux send-keys -t "$session_name:$name" "powershell.exe" Enter
        fi
    done < "$projects_file"

    # Select first window
    tmux select-window -t "$session_name:1"
}

# ------------------------------------------
# workspace_attach -- Ensure session exists
#   then attach to it
# ------------------------------------------

workspace_attach() {
    local session_name
    session_name=$(get_config "SESSION_NAME" 2>/dev/null) || session_name="work"

    # Ensure session exists
    workspace_init

    # Attach (replaces current shell)
    exec tmux attach -t "$session_name"
}
