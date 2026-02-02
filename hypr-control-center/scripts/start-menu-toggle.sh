#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Start Menu Toggle - v2.3 DAEMON MODE
# ═══════════════════════════════════════════════════════════════════════════════
# INSTANT toggle using daemon mode - menu stays resident, just show/hide

CONFIG_DIR="$HOME/.config/hypr-control-center"
START_MENU="$CONFIG_DIR/start-menu.py"
PID_FILE="/tmp/hypr-startmenu.pid"

# ═══════════════════════════════════════════════════════════════════════════════
# DAEMON STATUS CHECK
# ═══════════════════════════════════════════════════════════════════════════════

get_daemon_pid() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
    fi
    return 1
}

is_daemon_running() {
    get_daemon_pid >/dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════════
# DAEMON CONTROL
# ═══════════════════════════════════════════════════════════════════════════════

start_daemon() {
    if is_daemon_running; then
        echo "[StartMenu] Daemon already running (PID: $(get_daemon_pid))"
        return 0
    fi
    
    echo "[StartMenu] 🚀 Starting daemon..."
    cd "$CONFIG_DIR" || exit 1
    
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
    GDK_BACKEND=wayland \
    python3 "$START_MENU" --daemon &
    
    disown
    
    # Wait for daemon to start
    sleep 0.3
    
    if is_daemon_running; then
        echo "[StartMenu] ✅ Daemon started (PID: $(get_daemon_pid))"
    else
        echo "[StartMenu] ❌ Daemon failed to start"
        return 1
    fi
}

stop_daemon() {
    local pid
    pid=$(get_daemon_pid)
    
    if [ -n "$pid" ]; then
        echo "[StartMenu] 🛑 Stopping daemon (PID: $pid)..."
        kill "$pid" 2>/dev/null
        rm -f "$PID_FILE"
        echo "[StartMenu] ✅ Daemon stopped"
    else
        echo "[StartMenu] ⚠️ Daemon not running"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# TOGGLE - INSTANT via SIGUSR1
# ═══════════════════════════════════════════════════════════════════════════════

toggle_menu() {
    local pid
    pid=$(get_daemon_pid)
    
    if [ -n "$pid" ]; then
        # INSTANT! Just send signal to toggle
        kill -USR1 "$pid" 2>/dev/null
    else
        # Start daemon first, then show
        start_daemon
        sleep 0.2
        pid=$(get_daemon_pid)
        if [ -n "$pid" ]; then
            kill -USR1 "$pid" 2>/dev/null
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY MODE (non-daemon)
# ═══════════════════════════════════════════════════════════════════════════════

start_legacy() {
    echo "[StartMenu] 🚀 Starting (legacy mode)..."
    cd "$CONFIG_DIR" || exit 1
    
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
    GDK_BACKEND=wayland \
    python3 "$START_MENU" &
    
    disown
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

case "${1:-toggle}" in
    toggle)
        toggle_menu
        ;;
    daemon|start-daemon)
        start_daemon
        ;;
    stop|stop-daemon)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 0.3
        start_daemon
        ;;
    status)
        if is_daemon_running; then
            echo "[StartMenu] ✅ Daemon running (PID: $(get_daemon_pid))"
        else
            echo "[StartMenu] ❌ Daemon not running"
        fi
        ;;
    legacy)
        start_legacy
        ;;
    *)
        echo "Usage: $0 {toggle|daemon|stop|restart|status|legacy}"
        echo ""
        echo "Commands:"
        echo "  toggle   - Toggle menu visibility (starts daemon if needed)"
        echo "  daemon   - Start daemon in background"
        echo "  stop     - Stop daemon"
        echo "  restart  - Restart daemon"
        echo "  status   - Check daemon status"
        echo "  legacy   - Start without daemon (slower)"
        ;;
esac