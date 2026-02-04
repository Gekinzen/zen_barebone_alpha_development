#!/bin/bash

BLUR="$HOME/.config/rofi/blur.png"  # or /tmp/rofi_blur.png if you prefer

# Check if rofi is already running
if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
fi

# Take screenshot of current screen state
grim "$BLUR"

# Blur the screenshot
magick "$BLUR" -blur 0x18 "$BLUR"

# Show blurred screenshot behind Rofi
swaybg -i "$BLUR" -m fill &
BG_PID=$!

# Launch Rofi immediately
rofi -show drun -theme "$HOME/.config/rofi/launcher.rasi"

# Cleanup after Rofi closes
kill $BG_PID
rm -f "$BLUR"

