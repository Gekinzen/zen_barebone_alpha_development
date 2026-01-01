#!/usr/bin/env bash

APP="$1"
PIN_FILE="$HOME/.config/waybar/pinned-apps.json"

mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{"pinned":[]}' > "$PIN_FILE"

if jq -e ".pinned[] | select(. == \"$APP\")" "$PIN_FILE" >/dev/null; then
    CHOICE=$(printf "Unpin\nCancel" | rofi -dmenu -p "$APP")
    [ "$CHOICE" = "Unpin" ] && \
      jq ".pinned -= [\"$APP\"]" "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
else
    CHOICE=$(printf "Pin\nCancel" | rofi -dmenu -p "$APP")
    [ "$CHOICE" = "Pin" ] && \
      jq ".pinned += [\"$APP\"]" "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
fi

pkill -SIGUSR2 waybar
