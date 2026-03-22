# ============================================
# open-in-cctmux.ps1 -- Open folder in cc-tmux
#
# Called by Windows Explorer context menu.
# Converts Windows path to WSL path and creates
# a new tmux window in the cc-tmux workspace.
#
# Usage: powershell.exe -File open-in-cctmux.ps1 "C:\path\to\folder"
# ============================================

param([string]$FolderPath)

if (-not $FolderPath) {
    Write-Host "No folder path provided."
    exit 1
}

# Get the WSL distro from cc-tmux config (default to Ubuntu)
$distro = "Ubuntu"
$configFile = "$env:USERPROFILE\.wslconfig-cctmux-distro"
# We'll use a simpler approach: just use the default WSL distro

# Convert Windows path to WSL path and create tmux window
$escapedPath = $FolderPath -replace '\\', '\\'
$folderName = Split-Path $FolderPath -Leaf

# Build the WSL command
$wslCmd = @"
wsl_path=`$(wslpath '$($FolderPath -replace "'", "'\''")')
session="work"
name="$folderName"

# If tmux session exists, add a window
if tmux has-session -t "`$session" 2>/dev/null; then
    tmux new-window -t "`$session" -n "`$name" -c "`$wsl_path"
    tmux send-keys -t "`$session:`$name" "powershell.exe" Enter
    echo "Tab '`$name' added to workspace"
else
    echo "Workspace not running. Start it first: cc-tmux start"
    echo "Press Enter to exit..."
    read
    exit 1
fi
"@

wsl.exe -- bash -c $wslCmd
