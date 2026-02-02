#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Taskbar Panel Toggle - INSTANT RESPONSE VERSION
# ═══════════════════════════════════════════════════════════════════════════════
# Optimized for speed - minimal checks, instant toggle

PANEL_SCRIPT="$HOME/.config/hypr-control-center/src/panel/panel_widget.py"
PID_FILE="/tmp/hypr-panel.pid"

# Fast check using PID file only (no pgrep delay)
is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start_panel() {
    # Don't start if already running
    is_running && exit 0
    
    # Launch immediately in background
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
    GDK_BACKEND=wayland \
    python3 "$PANEL_SCRIPT" &
    
    echo $! > "$PID_FILE"
}

stop_panel() {
    # Fast kill using PID file
    [ -f "$PID_FILE" ] && {
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    }
    
    # Cleanup any orphans (async, don't wait)
    pkill -f "panel_widget.py" 2>/dev/null &
}

# Main toggle - optimized for speed
case "${1:-toggle}" in
    start)  start_panel ;;
    stop)   stop_panel ;;
    toggle)
        if is_running; then
            stop_panel
        else
            start_panel
        fi
        ;;
    *)
        if is_running; then
            stop_panel
        else
            start_panel
        fi
        ;;
esac