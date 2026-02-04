#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Start Menu Toggle - v4.0 ULTRA-OPTIMIZED
# ═══════════════════════════════════════════════════════════════════════════════
# FIXES:
# - Autostart daemon on login (no cold start delay)
# - Parallel daemon start while waiting
# - Reduced polling intervals
# - Background preload option
# ═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR="$HOME/.config/hypr-control-center"
START_MENU="$CONFIG_DIR/start-menu.py"
PID_FILE="/tmp/hypr-startmenu.pid"
READY_FILE="/tmp/hypr-startmenu.ready"

# ═══════════════════════════════════════════════════════════════════════════════
# FAST PID CHECK (optimized)
# ═══════════════════════════════════════════════════════════════════════════════

get_daemon_pid() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid=$(<"$PID_FILE")
    [[ -n "$pid" && -d "/proc/$pid" ]] && echo "$pid" && return 0
    return 1
}

is_ready() {
    # Check both PID exists AND ready file (GTK fully initialized)
    [[ -f "$READY_FILE" ]] && get_daemon_pid >/dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════════
# DAEMON START - OPTIMIZED
# ═══════════════════════════════════════════════════════════════════════════════

start_daemon() {
    local pid
    pid=$(get_daemon_pid 2>/dev/null)
    
    if [[ -n "$pid" ]]; then
        [[ "${1:-}" != "-q" ]] && echo "[StartMenu] Daemon already running (PID: $pid)"
        return 0
    fi
    
    [[ "${1:-}" != "-q" ]] && echo "[StartMenu] 🚀 Starting daemon..."
    
    # Clean stale files
    rm -f "$PID_FILE" "$READY_FILE" 2>/dev/null
    
    cd "$CONFIG_DIR" || exit 1
    
    # Start with optimized environment
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
    GDK_BACKEND=wayland \
    GTK_USE_PORTAL=0 \
    GDK_SYNCHRONIZE=0 \
    python3 -O "$START_MENU" --daemon &
    
    disown
    
    # Fast poll: 20ms intervals, max 3 seconds
    local i
    for i in {1..150}; do
        if is_ready; then
            [[ "${1:-}" != "-q" ]] && echo "[StartMenu] ✅ Ready in ~$((i * 20))ms"
            return 0
        fi
        sleep 0.02
    done
    
    # Fallback: just check PID
    if get_daemon_pid >/dev/null 2>&1; then
        [[ "${1:-}" != "-q" ]] && echo "[StartMenu] ✅ Daemon started (ready file pending)"
        return 0
    fi
    
    [[ "${1:-}" != "-q" ]] && echo "[StartMenu] ❌ Daemon failed to start"
    return 1
}

stop_daemon() {
    local pid
    pid=$(get_daemon_pid)
    
    if [[ -n "$pid" ]]; then
        echo "[StartMenu] 🛑 Stopping daemon (PID: $pid)..."
        kill "$pid" 2>/dev/null
        rm -f "$PID_FILE" "$READY_FILE"
        echo "[StartMenu] ✅ Stopped"
    else
        echo "[StartMenu] ⚠️ Not running"
        rm -f "$PID_FILE" "$READY_FILE"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# TOGGLE - INSTANT
# ═══════════════════════════════════════════════════════════════════════════════

toggle_menu() {
    local pid
    pid=$(get_daemon_pid)
    
    if [[ -n "$pid" ]]; then
        # INSTANT - daemon running, just signal
        kill -USR1 "$pid" 2>/dev/null
        return 0
    fi
    
    # Cold start: start daemon in background, wait for ready, then toggle
    (
        start_daemon -q
        pid=$(get_daemon_pid)
        [[ -n "$pid" ]] && sleep 0.1 && kill -USR1 "$pid" 2>/dev/null
    ) &
    
    # Show brief feedback that we're starting
    # notify-send -t 500 -u low "Starting menu..." 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRELOAD - Run on login for instant first click
# ═══════════════════════════════════════════════════════════════════════════════
# Add to hyprland.conf:
#   exec-once = ~/.config/hypr/scripts/toggle-startmenu.sh preload

preload_daemon() {
    # Wait for desktop to settle (don't compete with other startup items)
    sleep 2
    
    if ! get_daemon_pid >/dev/null 2>&1; then
        echo "[StartMenu] 🔄 Preloading daemon..."
        start_daemon -q
        echo "[StartMenu] ✅ Preloaded - first click will be instant!"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# THEME RELOAD
# ═══════════════════════════════════════════════════════════════════════════════

reload_theme() {
    local pid
    pid=$(get_daemon_pid)
    
    if [[ -n "$pid" ]]; then
        kill -USR2 "$pid" 2>/dev/null
        echo "[StartMenu] 🎨 Theme reloaded"
    else
        echo "[StartMenu] ⚠️ Not running"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS
# ═══════════════════════════════════════════════════════════════════════════════

show_status() {
    local pid
    pid=$(get_daemon_pid)
    
    if [[ -n "$pid" ]]; then
        echo "┌─────────────────────────────────────┐"
        echo "│ Start Menu Daemon v4.0              │"
        echo "├─────────────────────────────────────┤"
        echo "│ Status: ✅ Running                  │"
        echo "│ PID: $pid                            "
        [[ -f "$READY_FILE" ]] && echo "│ GTK: ✅ Ready                       │" || echo "│ GTK: ⏳ Initializing                │"
        echo "├─────────────────────────────────────┤"
        echo "│ Signals:                            │"
        echo "│   SIGUSR1 → Toggle visibility       │"
        echo "│   SIGUSR2 → Reload theme            │"
        echo "└─────────────────────────────────────┘"
    else
        echo "┌─────────────────────────────────────┐"
        echo "│ Start Menu Daemon v4.0              │"
        echo "├─────────────────────────────────────┤"
        echo "│ Status: ❌ Not running              │"
        echo "│ Run 'preload' or 'toggle' to start  │"
        echo "└─────────────────────────────────────┘"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

case "${1:-toggle}" in
    toggle)           toggle_menu ;;
    daemon|start)     start_daemon ;;
    stop)             stop_daemon ;;
    restart)          stop_daemon; sleep 0.2; start_daemon ;;
    reload|theme)     reload_theme ;;
    preload)          preload_daemon ;;
    status)           show_status ;;
    *)
        echo "Start Menu Toggle v4.0"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  toggle    Toggle menu (default, starts daemon if needed)"
        echo "  preload   Start daemon in background (for autostart)"
        echo "  daemon    Start daemon"
        echo "  stop      Stop daemon"
        echo "  restart   Restart daemon"
        echo "  reload    Reload theme CSS"
        echo "  status    Show status"
        echo ""
        echo "Autostart (add to hyprland.conf):"
        echo "  exec-once = ~/.config/hypr/scripts/toggle-startmenu.sh preload"
        ;;
esac