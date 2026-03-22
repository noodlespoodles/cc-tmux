#!/usr/bin/env bash
# ============================================
# WSL-side helper for Windows Explorer context menu.
# Called by open-in-cctmux.ps1 via wsl.exe.
# Receives Windows folder path as $1.
# ============================================

set -euo pipefail

win_path="${1:-}"
if [[ -z "$win_path" ]]; then
    echo "Usage: open-in-cctmux.sh <windows-folder-path>"
    exit 1
fi

# Convert Windows path to WSL path
wsl_path=$(wslpath "$win_path") || {
    echo "Failed to convert path: $win_path"
    exit 1
}

# Extract folder name for the tmux window name
folder_name=$(basename "$wsl_path")

# Read session name from config (default: work)
CC_TMUX_DIR="$HOME/.cc-tmux"
session_name="work"
if [[ -f "$CC_TMUX_DIR/config.env" ]]; then
    # Source in subshell to get SESSION_NAME
    session_name=$(source "$CC_TMUX_DIR/config.env" 2>/dev/null && echo "${SESSION_NAME:-work}") || session_name="work"
fi

# Check if workspace session exists
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Workspace not running. Run: cc-tmux start"
    exit 1
fi

# Create new tmux window in the session
tmux new-window -t "$session_name" -n "$folder_name" -c "$wsl_path"
tmux send-keys -t "$session_name:$folder_name" 'powershell.exe' Enter
