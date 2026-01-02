#!/usr/bin/env bash

PID_FILE="$HOME/.config/alacritty/termrun.pid"

if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    # Terminal is running, kill it
    kill $(cat "$PID_FILE")
    rm "$PID_FILE"
else
    # Terminal not running, launch it
    alacritty \
        --title "TermiWindow" \
        --config-file "$HOME/.config/alacritty/termi.toml" \
        --working-directory "$HOME" &
    # Save its PID
    echo $! > "$PID_FILE"
fi

