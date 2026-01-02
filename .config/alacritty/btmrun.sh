#!/usr/bin/env bash

# Check if btm is running
if pgrep -x btm >/dev/null; then
    # Kill btm and the Alacritty window running it
    pkill -x btm
    pkill -f "alacritty.*btm"
else
    # Launch new instance
    alacritty \
      --title "btmWindow" \
      --config-file ~/.config/alacritty/btm.toml \
      -e btm &
fi

