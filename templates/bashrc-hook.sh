#!/usr/bin/env bash
# CC-TMUX auto-attach hook
# Sourced from .bashrc when connecting via SSH
# Attaches to existing tmux workspace or creates one

# Guard: only run in SSH sessions, never inside tmux
if [ -z "$SSH_CONNECTION" ] || [ -n "$TMUX" ]; then
    return 0 2>/dev/null || exit 0
fi

# Source libraries for workspace management
source "$HOME/.cc-tmux/lib/common.sh"
source "$HOME/.cc-tmux/lib/config.sh"
source "$HOME/.cc-tmux/lib/workspace.sh"

# Read session name from config
SESSION_NAME=$(get_config "SESSION_NAME" 2>/dev/null) || SESSION_NAME="work"

# Ensure workspace session exists (creates project tabs if new)
workspace_init

# Attach to session (replaces current shell)
exec tmux attach -t "$SESSION_NAME"
