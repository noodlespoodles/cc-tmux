#!/usr/bin/env bash
# ============================================
# Mobile auto-detection for tmux
# Called by set-hook client-attached in tmux.conf
#
# Checks terminal width and applies fat tabs
# for easy tapping on phone screens.
# ============================================

WIDTH=$(tmux display -p '#{client_width}')

if [ "$WIDTH" -lt 80 ]; then
    tmux set status-left "" \; \
         set status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + " \; \
         set status-right-length 5 \; \
         setw window-status-format "#[bg=#45475a,fg=#cdd6f4]    #I: #W    " \; \
         setw window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold]    #I: #W    " \; \
         setw window-status-separator " " \; \
         display-message "Mobile mode"
else
    tmux source-file ~/.tmux.conf
fi
