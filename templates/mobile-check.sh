#!/usr/bin/env bash
# ============================================
# Mobile auto-detection for tmux
# Called by set-hook client-attached in tmux.conf
#
# Checks terminal width on each attach and
# applies mobile styling if width < 80 columns.
# If width >= 80, desktop layout is already
# active from tmux.conf -- no action needed.
# ============================================

WIDTH=$(tmux display -p '#{client_width}')

if [ "$WIDTH" -lt 80 ]; then
    # Mobile mode: hide session name, minimal status-right,
    # wider tab labels with extra spacing for tap targets
    tmux set status-left "" \; \
         set status-right "#[bg=#89b4fa,fg=#1e1e2e,bold] + " \; \
         set status-right-length 5 \; \
         setw window-status-format "#[bg=#45475a,fg=#cdd6f4]  #I: #W  " \; \
         setw window-status-current-format "#[bg=#89b4fa,fg=#1e1e2e,bold]  #I: #W  " \; \
         setw window-status-separator " " \; \
         display-message "Mobile mode"
fi
# If width >= 80, desktop layout is already active from tmux.conf
