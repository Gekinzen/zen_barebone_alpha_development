#!/usr/bin/env bash

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"
TASKBAR_MENU_SCRIPT="$HOME/.config/hypr/scripts/waybar/taskbar-menu.sh"

mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

# Get all running apps with counts
MENU_ITEMS=$(hyprctl clients -j 2>/dev/null | jq -r '
  group_by(.class) 
  | map({
      app: .[0].class,
      count: length
    })
  | .[] 
  | .app + " (" + (.count|tostring) + " window" + (if .count > 1 then "s" else "" end) + ")"
')

# Add separator and global options
MENU_ITEMS="$MENU_ITEMS
───────────────
Manage Pinned Apps
Close All Windows"

[ -z "$MENU_ITEMS" ] && exit 0

CHOICE=$(echo "$MENU_ITEMS" | rofi -dmenu -i -p "Taskbar Menu")

case "$CHOICE" in
    "Manage Pinned Apps")
        # Show pinned apps manager
        PINNED=$(jq -r '.pinned[]?' "$PIN_FILE" 2>/dev/null)
        
        if [ -z "$PINNED" ]; then
            notify-send "Taskbar" "No pinned apps yet"
            exit 0
        fi
        
        APP=$(echo "$PINNED" | rofi -dmenu -i -p "Unpin app")
        [ -z "$APP" ] && exit 0
        
        # Unpin the app
        jq --arg app "$APP" '.pinned -= [$app]' \
            "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
        
        notify-send "Taskbar" "Unpinned $APP"
        ;;
        
    "Close All Windows")
        # Confirm
        CONFIRM=$(echo -e "No\nYes" | rofi -dmenu -i -p "Close all windows?")
        
        if [ "$CONFIRM" = "Yes" ]; then
            hyprctl clients -j 2>/dev/null | jq -r '.[].address' | while read -r addr; do
                hyprctl dispatch closewindow address:$addr
            done
            notify-send "Taskbar" "All windows closed"
        fi
        ;;
        
    "───────────────")
        exit 0
        ;;
        
    *)
        # Extract app name (remove count)
        APP=$(echo "$CHOICE" | sed 's/ (.*//')
        [ -z "$APP" ] && exit 0
        
        # Show menu for selected app
        "$TASKBAR_MENU_SCRIPT" "$APP"
        ;;
esac