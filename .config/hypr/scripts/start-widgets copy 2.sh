#!/bin/bash
# ~/.config/hypr/scripts/start-widgets.sh
# Desktop widgets with layer shell support
#
# Usage:
#   start-widgets.sh          # Start all (kills existing first)
#   start-widgets.sh stop     # Stop all widgets
#   start-widgets.sh restart  # Restart all
#   start-widgets.sh status   # Show status

WIDGETS_DIR="$HOME/.config/hypr-control-center/widgets"
LAYER_SHELL_LIB="/usr/lib/libgtk4-layer-shell.so"
LOCK_DIR="/tmp/hypr-widgets"

# ═══════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════

start_widget() {
    local widget_name="$1"
    local widget_file="$WIDGETS_DIR/${widget_name}_widget.py"
    local lock_file="$LOCK_DIR/$widget_name.lock"
    
    if [ ! -f "$widget_file" ]; then
        echo "⚠️  $widget_name not found"
        return 1
    fi
    
    # Kill existing first
    local existing_pids=$(pgrep -f "${widget_name}_widget.py" 2>/dev/null)
    if [ -n "$existing_pids" ]; then
        echo "🔄 Killing $widget_name ($existing_pids)..."
        kill $existing_pids 2>/dev/null
        sleep 0.2
        kill -9 $existing_pids 2>/dev/null
    fi
    
    rm -f "$lock_file" 2>/dev/null
    
    echo "🚀 Starting $widget_name..."
    
    # ═══════════════════════════════════════════════════════════
    # CRITICAL FIX: Run with LD_PRELOAD in the command itself
    # ═══════════════════════════════════════════════════════════
    if [ -f "$LAYER_SHELL_LIB" ]; then
        LD_PRELOAD="$LAYER_SHELL_LIB" python3 "$widget_file" &
    else
        python3 "$widget_file" &
    fi
    
    echo "$!" > "$lock_file"
    
    sleep 0.3
}

kill_all_widgets() {
    echo "🛑 Stopping all widgets..."
    
    pkill -f "clock_widget.py" 2>/dev/null
    pkill -f "weather_widget.py" 2>/dev/null
    pkill -f "system_monitor_widget.py" 2>/dev/null
    
    sleep 0.2
    
    pkill -9 -f "clock_widget.py" 2>/dev/null
    pkill -9 -f "weather_widget.py" 2>/dev/null
    pkill -9 -f "system_monitor_widget.py" 2>/dev/null
    
    rm -rf "$LOCK_DIR" 2>/dev/null
    
    echo "✅ Stopped"
}

show_status() {
    echo "═══════════════════════════════════════"
    echo "        Widget Status"
    echo "═══════════════════════════════════════"
    for widget in clock weather system_monitor; do
        local pid=$(pgrep -f "${widget}_widget.py" 2>/dev/null)
        if [ -n "$pid" ]; then
            echo "   ✅ $widget (PID: $pid)"
        else
            echo "   ❌ $widget"
        fi
    done
    echo "═══════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

case "$1" in
    stop|kill)
        kill_all_widgets
        exit 0
        ;;
    restart)
        kill_all_widgets
        sleep 0.3
        ;;
    status)
        show_status
        exit 0
        ;;
    ""|start)
        kill_all_widgets
        sleep 0.3
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

mkdir -p "$LOCK_DIR"

# ═══════════════════════════════════════════════════════════════
# LAYER SHELL CHECK
# ═══════════════════════════════════════════════════════════════
if [ -f "$LAYER_SHELL_LIB" ]; then
    echo "✅ Layer shell enabled: $LAYER_SHELL_LIB"
else
    echo "⚠️  gtk4-layer-shell not found at $LAYER_SHELL_LIB"
fi

# ═══════════════════════════════════════════════════════════════
# START WIDGETS
# ═══════════════════════════════════════════════════════════════
cd "$WIDGETS_DIR" || {
    echo "❌ Directory not found: $WIDGETS_DIR"
    exit 1
}

start_widget "clock"
start_widget "weather"
start_widget "system_monitor"

echo ""
show_status