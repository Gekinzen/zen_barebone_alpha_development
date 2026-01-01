#!/usr/bin/env bash
APP_ID="$1"
[ -z "$APP_ID" ] && exit 0

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"
mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

IS_PINNED=$(jq -r --arg app "$APP_ID" '.pinned | index($app)' "$PIN_FILE")
WINDOW_COUNT=$(hyprctl clients -j | jq -r --arg app "$APP_ID" '[.[] | select(.class == $app)] | length')

# Build menu
MENU=""
[ "$IS_PINNED" = "null" ] && MENU="Pin to taskbar" || MENU="Unpin from taskbar"
[ "$WINDOW_COUNT" -gt 1 ] && MENU="$MENU\nShow all windows ($WINDOW_COUNT)"
[ "$WINDOW_COUNT" -gt 0 ] && MENU="$MENU\nClose all windows"
[ "$WINDOW_COUNT" -eq 0 ] && MENU="$MENU\nLaunch"

CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "$APP_ID")

case "$CHOICE" in
    "Pin to taskbar")
        jq --arg app "$APP_ID" '.pinned += [$app] | .pinned |= unique' \
            "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
        ;;
    "Unpin from taskbar")
        jq --arg app "$APP_ID" '.pinned -= [$app]' \
            "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
        ;;
    "Show all windows"*)
        ~/.config/hypr/scripts/waybar/taskbar-windows.sh "$APP_ID"
        ;;
    "Close all windows")
        hyprctl clients -j | jq -r --arg app "$APP_ID" '
          .[] | select(.class == $app) | .address
        ' | while read -r addr; do
            hyprctl dispatch closewindow address:$addr
        done
        ;;
    "Launch")
        gtk-launch "$APP_ID" 2>/dev/null || "$APP_ID" &
        ;;
esac