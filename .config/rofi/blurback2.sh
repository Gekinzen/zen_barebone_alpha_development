#!/bin/bash

# Path to save blurred wallpaper
BLUR="$HOME/.config/rofi/blur.png"

# Toggle: close Rofi if already open
if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
fi

# Get current wallpaper from swaybg
WALLPAPER=$(pgrep -a swaybg | tail -n1 | grep -oP '(?<=-i )\S+')

# Make sure we got a wallpaper
if [[ ! -f "$WALLPAPER" ]]; then
    echo "Cannot find current wallpaper!"
    exit 1
fi

# Copy and blur the wallpaper
cp "$WALLPAPER" "$BLUR"
magick "$BLUR" -blur 0x18 "$BLUR"

# Show blurred wallpaper behind Rofi
swaybg -i "$BLUR" -m fill &
BG_PID=$!

# Launch Rofi
rofi -show drun -theme "$HOME/.config/rofi/launcher.rasi"

# Cleanup
kill $BG_PID
rm -f "$BLUR"

