#!/bin/bash

# Paths
BLUR="$HOME/.config/rofi/blur.png"
STATE_FILE="/tmp/blur_wallpaper_state"
TMP_FILE="/tmp/current_wallpaper.txt"

# Toggle: if blur is active, restore original wallpaper
if [[ -f "$STATE_FILE" ]]; then
    if [[ -f "$TMP_FILE" ]]; then
        ORIGINAL=$(cat "$TMP_FILE")
        swaybg -i "$ORIGINAL" -m fill &
    fi
    rm -f "$STATE_FILE" "$TMP_FILE"
    exit 0
fi

# Get current wallpaper from swaybg
CURRENT_WALLPAPER=$(pgrep -a swaybg | tail -n1 | grep -oP '(?<=-i )\S+')

# Save original wallpaper path
echo "$CURRENT_WALLPAPER" > "$TMP_FILE"

# Fast blur: scale down, blur, then scale back up
magick "$CURRENT_WALLPAPER" -resize 25% -blur 0x8 -resize 400% "$BLUR"

# Apply blurred wallpaper
swaybg -i "$BLUR" -m fill &

# Mark blur as active
touch "$STATE_FILE"

