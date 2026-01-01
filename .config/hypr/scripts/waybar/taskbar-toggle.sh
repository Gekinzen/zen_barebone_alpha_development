#!/usr/bin/env bash

APP_ID="$1"
[ -z "$APP_ID" ] && exit 0

ACTIVE_CLASS=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')
CLIENTS=$(hyprctl clients -j 2>/dev/null | jq -r --arg app "$APP_ID" '[.[] | select(.class == $app)] | length')

# If app not running, launch it
if [ "$CLIENTS" -eq 0 ]; then
    # Try different launch methods
    gtk-launch "$APP_ID" 2>/dev/null || \
    "$APP_ID" 2>/dev/null || \
    hyprctl dispatch exec "$APP_ID" &
    exit 0
fi

# If single window
if [ "$CLIENTS" -eq 1 ]; then
    ADDR=$(hyprctl clients -j 2>/dev/null | jq -r --arg app "$APP_ID" '.[] | select(.class == $app) | .address')
    
    # If already active, minimize
    if [ "$ACTIVE_CLASS" = "$APP_ID" ]; then
        hyprctl dispatch movetoworkspacesilent special:hidden,address:$ADDR
    else
        hyprctl dispatch focuswindow address:$ADDR
    fi
    exit 0
fi

# Multiple windows - show rofi selector
~/.config/hypr/scripts/waybar/taskbar-windows.sh "$APP_ID"