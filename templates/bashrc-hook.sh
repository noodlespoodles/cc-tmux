#!/usr/bin/env bash
# CC-TMUX auto-attach hook
# Sourced from .bashrc when connecting via SSH
# Attaches to existing tmux workspace or creates one

# Guard: only run in SSH sessions, never inside tmux
if [ -z "$SSH_CONNECTION" ] || [ -n "$TMUX" ]; then
    return 0 2>/dev/null || exit 0
fi

SESSION_NAME="work"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    exec tmux attach -t "$SESSION_NAME"
else
    # Workspace init will be added in Phase 4
    # For now, create a basic session
    tmux new-session -d -s "$SESSION_NAME"
    exec tmux attach -t "$SESSION_NAME"
fi
