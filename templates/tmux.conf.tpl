# ============================================
# CC x TMUX -- tmux configuration
# Auto-generated from template. Do not hand-edit.
# ============================================

# --- Mouse support (clickable tabs, scrolling, pane resize) ---
set -g mouse on

# --- Quality of life ---
set -g history-limit 50000
set -g display-time 3000
set -g status-interval 5
set -g default-terminal "tmux-256color"
set -g focus-events on
set -s escape-time 0

# --- Start numbering at 1 ---
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# --- Status bar (Catppuccin-inspired) ---
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left "#[bg=#89b4fa,fg=#1e1e2e,bold]  #S "
set -g status-left-length 30
set -g status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + #[default] #[fg=#a6adc8]%H:%M  %d-%b "
set -g status-right-length 30

# --- Tab styling ---
setw -g window-status-format " #I:#W "
setw -g window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold] #I:#W "
setw -g window-status-separator ""

# --- Keybindings ---
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind R source-file ~/.tmux.conf \; display-message "Config reloaded"
bind c new-window -c "#{pane_current_path}"
bind -n M-Left previous-window
bind -n M-Right next-window

# --- Clickable + button creates new PowerShell tab ---
bind -n MouseDown1StatusRight new-window -c "/mnt/c/Users/__USERNAME__/Documents" \; send-keys "powershell.exe" Enter

# --- Mobile auto-detect on attach ---
set-hook -g client-attached 'run-shell "~/.cc-tmux/templates/mobile-check.sh"'

# --- Mobile mode toggle (Ctrl+B, Shift+M) ---
bind M set status-left "" \; set status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + " \; set status-right-length 5 \; setw window-status-format "#[bg=#45475a,fg=#cdd6f4]  #I: #W  " \; setw window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold]  #I: #W  " \; setw window-status-separator " " \; display-message "Mobile mode"

# --- Desktop mode toggle (Ctrl+B, Shift+N) ---
bind N source-file ~/.tmux.conf \; display-message "Desktop mode"
