#!/usr/bin/env bash

APP_ID="$1"

CLIENTS=$(hyprctl clients -j | jq -r --arg app "$APP_ID" '
  .[] | select(.class == $app) |
  "\(.address)\t\(.title)"
')

[ -z "$CLIENTS" ] && exit 0

CHOICE=$(echo "$CLIENTS" | rofi -dmenu -i -p "Windows")

ADDR=$(echo "$CHOICE" | cut -f1)

[ -n "$ADDR" ] && hyprctl dispatch focuswindow address:$ADDR
