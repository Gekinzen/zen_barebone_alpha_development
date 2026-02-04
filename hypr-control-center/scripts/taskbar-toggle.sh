#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Taskbar Panel Toggle - v2.4 PRECISION Edition
# ═══════════════════════════════════════════════════════════════════════════════
# - Captures cursor position for accurate panel alignment (4px gap)
# - Panel matches Waybar opacity & border-radius from style.css
# - Instant toggle with PID-based process management
# - Panel reads config.jsonc FRESH every launch — auto-adapts to
#   position/height/margin/module-section changes from Control Center
#
# Usage:
#   taskbar-toggle.sh              # Normal toggle
#   taskbar-toggle.sh debug        # Toggle with debug output
#   taskbar-toggle.sh start        # Force start
#   taskbar-toggle.sh stop         # Force stop
# ═══════════════════════════════════════════════════════════════════════════════

PANEL_SCRIPT="$HOME/.config/hypr-control-center/src/panel/panel_widget.py"
PID_FILE="/tmp/hypr-panel.pid"

# ── Detect debug mode (either first or second arg) ──────────────────────
DEBUG_FLAG=""
for arg in "$@"; do
    [ "$arg" = "debug" ] && DEBUG_FLAG="--debug"
done

# ── Fast check using PID file (no pgrep delay) ──────────────────────────
is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# ── Start panel ─────────────────────────────────────────────────────────
start_panel() {
    # Don't start if already running
    is_running && exit 0

    # Capture cursor position BEFORE launching (for alignment)
    # This tells panel_widget.py exactly where the user clicked
    CURSOR=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')

    # Launch immediately in background with cursor position
    # panel_widget.py reads config.jsonc FRESH on every launch
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
    GDK_BACKEND=wayland \
        python3 "$PANEL_SCRIPT" --cursor "$CURSOR" $DEBUG_FLAG &

    echo $! > "$PID_FILE"
}

# ── Stop panel ──────────────────────────────────────────────────────────
stop_panel() {
    # Fast kill using PID file
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi

    # Cleanup any orphans (async, don't wait)
    pkill -f "panel_widget.py" 2>/dev/null &
}

# ── Determine action (ignore "debug" as an action) ──────────────────────
ACTION="toggle"
for arg in "$@"; do
    case "$arg" in
        start|stop|toggle) ACTION="$arg" ;;
        debug) ;;  # Skip, handled above
    esac
done

# ── Execute ─────────────────────────────────────────────────────────────
case "$ACTION" in
    start)  start_panel ;;
    stop)   stop_panel ;;
    *)
        if is_running; then
            stop_panel
        else
            start_panel
        fi
        ;;
esac