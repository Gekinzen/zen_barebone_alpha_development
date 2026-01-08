#!/usr/bin/env bash
APP_ID="$1"
[ -z "$APP_ID" ] && exit 0

ACTIVE_ADDR=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // ""')

CLIENTS=$(hyprctl clients -j | jq -r --arg app "$APP_ID" --arg active "$ACTIVE_ADDR" '
  .[] 
  | select(.class == $app) 
  | (if .address == $active then "▶ " else "  " end) + .title + "\t" + .address
')

[ -z "$CLIENTS" ] && exit 0

CHOICE=$(echo "$CLIENTS" | rofi -dmenu -i -p "$APP_ID windows" -format "s")
ADDR=$(echo "$CHOICE" | awk -F'\t' '{print $2}')

[ -n "$ADDR" ] && hyprctl dispatch focuswindow address:$ADDR