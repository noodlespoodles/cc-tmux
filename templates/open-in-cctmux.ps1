param([string]$FolderPath)

if (-not $FolderPath) { exit 1 }

$folderName = Split-Path $FolderPath -Leaf
$safePath = $FolderPath -replace "'", "'\''"

wsl.exe -- bash -c "p=`$(wslpath '$safePath') && tmux has-session -t work 2>/dev/null && tmux new-window -t work -n '$folderName' -c `"`$p`" && tmux send-keys -t 'work:$folderName' 'powershell.exe' Enter || echo 'Workspace not running. Run: cc-tmux start'"
