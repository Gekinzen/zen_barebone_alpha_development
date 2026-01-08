#!/usr/bin/env bash
# Wrapper for wlr/taskbar click - shows rofi only if multiple windows

# This script needs to be triggered by a keybind, not directly from waybar
# Because wlr/taskbar's on-click only supports built-in actions

# Get focused window class
APP_CLASS=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')

if [ -z "$APP_CLASS" ] || [ "$APP_CLASS" = "null" ]; then
    exit 0
fi

# Count windows of this app
WINDOW_COUNT=$(hyprctl clients -j 2>/dev/null | jq --arg app "$APP_CLASS" \
    'map(select(.class == $app)) | length')

# If only 1 window, just focus it (do nothing, already focused)
if [ "$WINDOW_COUNT" -le 1 ]; then
    exit 0
fi

# If multiple windows, show rofi menu
WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$APP_CLASS" \
    'map(select(.class == $app)) | 
     map({
         address: .address,
         title: .title,
         workspace: .workspace.name
     })')

# Build menu
MENU=""
declare -A ADDR_MAP

while IFS= read -r window; do
    TITLE=$(echo "$window" | jq -r '.title')
    WORKSPACE=$(echo "$window" | jq -r '.workspace')
    ADDRESS=$(echo "$window" | jq -r '.address')
    
    # Truncate title
    if [ ${#TITLE} -gt 60 ]; then
        TITLE="${TITLE:0:60}..."
    fi
    
    MENU_ITEM="[WS $WORKSPACE] $TITLE"
    MENU="$MENU$MENU_ITEM\n"
    ADDR_MAP["$MENU_ITEM"]="$ADDRESS"
done < <(echo "$WINDOWS" | jq -c '.[]')

# Show rofi
CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "$APP_CLASS ($WINDOW_COUNT windows)")

if [ -n "$CHOICE" ]; then
    ADDRESS="${ADDR_MAP[$CHOICE]}"
    if [ -n "$ADDRESS" ]; then
        hyprctl dispatch focuswindow address:$ADDRESS
    fi
fi