#!/usr/bin/env bash
# Toggle nmtui (WiFi / network manager) in a dedicated Alacritty window

if pgrep -x nmtui >/dev/null; then
    pkill -x nmtui
    pkill -f "alacritty.*nmtui"
else
    alacritty \
        --title "nmtuiWindow" \
        --config-file ~/.config/alacritty/nmtui.toml \
        -e nmtui &
fi
