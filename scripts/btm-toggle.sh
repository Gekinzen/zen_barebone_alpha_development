#!/usr/bin/env bash
# Toggle btm (bottom) system monitor in a terminal window

if pgrep -x btm >/dev/null 2>&1; then
    pkill -x btm
    sleep 0.2
    pkill -f "alacritty.*btm\|kitty.*btm" 2>/dev/null
else
    # Try alacritty first, fall back to kitty
    if command -v alacritty >/dev/null 2>&1; then
        if [ -f "$HOME/.config/alacritty/btm.toml" ]; then
            alacritty --title "btmWindow" --config-file "$HOME/.config/alacritty/btm.toml" -e btm &
        else
            alacritty --title "btmWindow" -e btm &
        fi
    elif command -v kitty >/dev/null 2>&1; then
        kitty --title "btmWindow" btm &
    else
        notify-send "No terminal found" "Install alacritty or kitty"
    fi
fi
