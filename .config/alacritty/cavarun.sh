#!/usr/bin/env bash

CAVA_PID=""
ALACRITTY_PID=""

start_cava() {
    if [ -z "$CAVA_PID" ]; then
        alacritty \
            --title "CavaWindow" \
            --config-file ~/.config/alacritty/cava.toml \
            -e cava &
        ALACRITTY_PID=$!
        CAVA_PID="running"
    fi
}

stop_cava() {
    if [ -n "$ALACRITTY_PID" ]; then
        kill "$ALACRITTY_PID" 2>/dev/null
        CAVA_PID=""
        ALACRITTY_PID=""
    fi
}

playerctl -F status | while read -r status; do
    case "$status" in
        Playing)
            start_cava
            ;;
        Paused|Stopped)
            stop_cava
            ;;
    esac
done

