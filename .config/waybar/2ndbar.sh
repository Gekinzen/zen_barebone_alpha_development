#!/usr/bin/env bash

CONFIG="$HOME/.config/waybar/second/config.jsonc"
STYLE="$HOME/.config/waybar/second/style.css"

# Check if this specific waybar instance is running
if pgrep -f "waybar.*second/config.jsonc" > /dev/null; then
    pkill -f "waybar.*second/config.jsonc"
else
    waybar -c "$CONFIG" -s "$STYLE" &
fi

