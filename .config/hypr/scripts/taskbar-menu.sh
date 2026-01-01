#!/usr/bin/env bash

APP_ID="$1"
PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"

# Safety check
[ -z "$APP_ID" ] && exit 0

# Ensure json exists
mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

# Check pin state
IS_PINNED=$(jq -r --arg app "$APP_ID" '.pinned | index($app)' "$PIN_FILE")

if [ "$IS_PINNED" = "null" ]; then
    ACTION="Pin $APP_ID"
else
    ACTION="Unpin $APP_ID"
fi

CHOICE=$(printf "%s\nClose\n" "$ACTION" | rofi -dmenu -i -p "Taskbar")

case "$CHOICE" in
    Pin*)
        jq --arg app "$APP_ID" '.pinned += [$app] | .pinned |= unique' \
            "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
        ;;
    Unpin*)
        jq --arg app "$APP_ID" '.pinned -= [$app]' \
            "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
        ;;
    Close)
        hyprctl dispatch closewindow class:"$APP_ID"
        ;;
esac
