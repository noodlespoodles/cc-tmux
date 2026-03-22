param([string]$FolderPath)

if (-not $FolderPath) { exit 1 }

# Call WSL-side helper directly with absolute path.
# __WSL_HOME__ is replaced with the actual WSL home path
# (e.g., /home/ben) at install time by install_context_menu().
# This avoids bash -c entirely, eliminating CRLF issues.
wsl.exe -- __WSL_HOME__/.cc-tmux/templates/open-in-cctmux.sh $FolderPath
