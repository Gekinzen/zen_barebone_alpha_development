#!/usr/bin/env bash

APP="$1"
PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"

[ -z "$APP" ] && exit 0

mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

# Check if app is pinned
IS_PINNED=$(jq -e --arg app "$APP" '.pinned | index($app)' "$PIN_FILE" &>/dev/null && echo "yes" || echo "no")

# Get windows for this app
WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -r --arg app "$APP" '
  map(select(.class == $app)) 
  | .[] 
  | .address + "|" + .title
')

WINDOW_COUNT=$(echo "$WINDOWS" | wc -l)

# Build menu
if [ "$IS_PINNED" = "yes" ]; then
    PIN_OPTION="📌 Unpin from Taskbar"
else
    PIN_OPTION="📌 Pin to Taskbar"
fi

MENU="$PIN_OPTION"

# Add window list if running
if [ "$WINDOW_COUNT" -gt 0 ]; then
    MENU="$MENU
───────────────"
    
    while IFS='|' read -r addr title; do
        MENU="$MENU
🪟 ${title:0:50}"
    done <<< "$WINDOWS"
    
    MENU="$MENU
───────────────
❌ Close All $APP Windows"
fi

# Show menu
CHOICE=$(echo "$MENU" | rofi -dmenu -i -p "$APP Menu")

case "$CHOICE" in
    "📌 Pin to Taskbar")
        # Pin the app
        jq --arg app "$APP" '.pinned += [$app] | .pinned |= unique' \
            "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
        notify-send "Taskbar" "Pinned $APP"
        ;;
        
    "📌 Unpin from Taskbar")
        # Unpin the app
        jq --arg app "$APP" '.pinned -= [$app]' \
            "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
        notify-send "Taskbar" "Unpinned $APP"
        ;;
        
    "❌ Close All $APP Windows")
        # Close all windows of this app
        echo "$WINDOWS" | cut -d'|' -f1 | while read -r addr; do
            hyprctl dispatch closewindow address:$addr
        done
        notify-send "Taskbar" "Closed all $APP windows"
        ;;
        
    🪟*)
        # Focus the selected window
        SELECTED_TITLE=$(echo "$CHOICE" | sed 's/^🪟 //')
        ADDR=$(echo "$WINDOWS" | grep -F "$SELECTED_TITLE" | cut -d'|' -f1 | head -1)
        [ -n "$ADDR" ] && hyprctl dispatch focuswindow address:$ADDR
        ;;
        
    *)
        exit 0
        ;;
esac