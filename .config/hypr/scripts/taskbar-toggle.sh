#!/usr/bin/env bash

APP_ID="$1"

# Get active window class
ACTIVE_CLASS=$(hyprctl activewindow -j | jq -r '.class')

# Get all clients matching app_id
CLIENTS=$(hyprctl clients -j | jq -r --arg APP "$APP_ID" '
    .[] | select(.class == $APP) | .address
')

# If no running client → launch app
if [[ -z "$CLIENTS" ]]; then
    gtk-launch "$APP_ID" 2>/dev/null || "$APP_ID" &
    exit 0
fi

# If focused → minimize
if [[ "$ACTIVE_CLASS" == "$APP_ID" ]]; then
    hyprctl dispatch movetoworkspacesilent special
    exit 0
fi

# Else → focus first matching client
ADDR=$(echo "$CLIENTS" | head -n1)
hyprctl dispatch focuswindow address:$ADDR
