#!/usr/bin/env bash
# Toggle blueman-manager (show/hide)

if pgrep -x blueman-manager >/dev/null; then
    pkill -x blueman-manager
else
    blueman-manager &
fi
