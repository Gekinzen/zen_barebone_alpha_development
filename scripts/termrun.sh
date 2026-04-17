#!/usr/bin/env bash
# Toggle a dedicated terminal window (termi.toml)

PID_FILE="$HOME/.config/alacritty/termrun.pid"

if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    kill $(cat "$PID_FILE")
    rm "$PID_FILE"
else
    alacritty \
        --title "TermiWindow" \
        --config-file "$HOME/.config/alacritty/termi.toml" \
        --working-directory "$HOME" &
    echo $! > "$PID_FILE"
fi
