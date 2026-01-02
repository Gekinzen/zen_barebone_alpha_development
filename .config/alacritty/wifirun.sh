#!/usr/bin/env bash

# Check if nmtui is running
if pgrep -x nmtui >/dev/null; then
    # Kill nmtui and the Alacritty window running it
    pkill -x nmtui
    pkill -f "alacritty.*nmtui"
else
    # Launch new instance with custom Alacritty config
    alacritty \
      --title "nmtuiWindow" \
      --config-file ~/.config/alacritty/nmtui.toml \
      -e nmtui &
fi

