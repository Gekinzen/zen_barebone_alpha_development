#!/bin/bash
# Minimize window (move to special workspace)

# Get window info before minimizing
WINDOW_INFO=$(hyprctl activewindow -j)
APP_CLASS=$(echo "$WINDOW_INFO" | jq -r '.class')
WINDOW_TITLE=$(echo "$WINDOW_INFO" | jq -r '.title')

# Truncate long titles
if [ ${#WINDOW_TITLE} -gt 40 ]; then
    WINDOW_TITLE="${WINDOW_TITLE:0:40}..."
fi

# Minimize
hyprctl dispatch movetoworkspacesilent special:minimized

# Send notification with app name + title
notify-send "󰖰 $APP_CLASS" "$WINDOW_TITLE minimized" -t 1000