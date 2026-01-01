#!/usr/bin/env bash

# Use .cache/waybar for temp files
CACHE_DIR="$HOME/.cache/waybar"
mkdir -p "$CACHE_DIR"
APPS_FILE="$CACHE_DIR/taskbar-apps"

if [ ! -f "$APPS_FILE" ]; then
    # Fallback: get all running apps
    APPS=$(hyprctl clients -j | jq -r 'group_by(.class) | map(.[0].class) | .[]')
else
    APPS=$(cat "$APPS_FILE")
fi

[ -z "$APPS" ] && exit 0

# Count apps
APP_COUNT=$(echo "$APPS" | wc -l)

# If only one app, toggle it directly
if [ "$APP_COUNT" -eq 1 ]; then
    ~/.config/hypr/scripts/waybar/taskbar-toggle.sh "$APPS"
    exit 0
fi

# Multiple apps - show rofi selector
CHOICE=$(echo "$APPS" | rofi -dmenu -i -p "Select app" -format "s")

[ -z "$CHOICE" ] && exit 0

# Toggle the selected app
~/.config/hypr/scripts/waybar/taskbar-toggle.sh "$CHOICE"