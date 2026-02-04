#!/usr/bin/env bash

# Path to your Rofi theme
theme="$HOME/.config/rofi/launcher.rasi"

# Toggle: close Rofi if already open
if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
fi

# Launch Rofi in drun mode
rofi_cmd() {
    rofi -show drun -theme "$theme"
}

# Run Rofi
rofi_cmd

