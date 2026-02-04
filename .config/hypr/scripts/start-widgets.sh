#!/bin/bash
# ~/.config/hypr/scripts/start-widgets.sh
# Desktop widgets with layer shell support
# Reads config from widgets.json for enable/disable
#
# Usage:
#   start-widgets.sh              # Start enabled widgets only
#   start-widgets.sh stop         # Stop all widgets
#   start-widgets.sh restart      # Restart enabled widgets
#   start-widgets.sh status       # Show status
#   start-widgets.sh clock        # Toggle/start clock only
#   start-widgets.sh weather      # Toggle/start weather only
#   start-widgets.sh system_monitor # Toggle/start sysmon only

WIDGETS_DIR="$HOME/.config/hypr-control-center/widgets"
CONFIG_FILE="$HOME/.config/hypr-control-center/preferences/widgets.json"
LAYER_SHELL_LIB="/usr/lib/libgtk4-layer-shell.so"
LOCK_DIR="/tmp/hypr-widgets"

# ═══════════════════════════════════════════════════════════════
# CONFIG FUNCTIONS
# ═══════════════════════════════════════════════════════════════

is_widget_enabled() {
    local widget_name="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        # Default: all enabled if no config
        echo "true"
        return
    fi
    
    # Use jq if available, fallback to grep
    if command -v jq &>/dev/null; then
        local enabled=$(jq -r ".widgets.${widget_name}.enabled // true" "$CONFIG_FILE" 2>/dev/null)
        echo "$enabled"
    else
        # Fallback: grep for enabled field
        if grep -q "\"${widget_name}\"" "$CONFIG_FILE" 2>/dev/null; then
            if grep -A5 "\"${widget_name}\"" "$CONFIG_FILE" | grep -q '"enabled": false'; then
                echo "false"
            else
                echo "true"
            fi
        else
            echo "true"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════
# WIDGET FUNCTIONS
# ═══════════════════════════════════════════════════════════════

start_widget() {
    local widget_name="$1"
    local force="$2"  # "force" to ignore config
    local widget_file="$WIDGETS_DIR/${widget_name}_widget.py"
    local lock_file="$LOCK_DIR/$widget_name.lock"
    
    if [ ! -f "$widget_file" ]; then
        echo "⚠️  $widget_name not found: $widget_file"
        return 1
    fi
    
    # Check if enabled in config (unless forced)
    if [ "$force" != "force" ]; then
        local enabled=$(is_widget_enabled "$widget_name")
        if [ "$enabled" = "false" ]; then
            echo "⏸️  $widget_name disabled in config, skipping"
            return 0
        fi
    fi
    
    # Kill existing first
    kill_widget "$widget_name" "quiet"
    
    echo "🚀 Starting $widget_name..."
    
    # Run with LD_PRELOAD for layer shell
    if [ -f "$LAYER_SHELL_LIB" ]; then
        LD_PRELOAD="$LAYER_SHELL_LIB" python3 "$widget_file" &
    else
        python3 "$widget_file" &
    fi
    
    local pid=$!
    echo "$pid" > "$lock_file"
    
    sleep 0.3
    
    # Verify it started
    if kill -0 "$pid" 2>/dev/null; then
        echo "✅ $widget_name started (PID: $pid)"
        return 0
    else
        echo "❌ $widget_name failed to start"
        return 1
    fi
}

kill_widget() {
    local widget_name="$1"
    local quiet="$2"
    local lock_file="$LOCK_DIR/$widget_name.lock"
    
    local pids=$(pgrep -f "${widget_name}_widget.py" 2>/dev/null)
    
    if [ -n "$pids" ]; then
        [ "$quiet" != "quiet" ] && echo "🛑 Stopping $widget_name ($pids)..."
        kill $pids 2>/dev/null
        sleep 0.2
        kill -9 $pids 2>/dev/null
    fi
    
    rm -f "$lock_file" 2>/dev/null
}

kill_all_widgets() {
    echo "🛑 Stopping all widgets..."
    
    kill_widget "clock" "quiet"
    kill_widget "weather" "quiet"
    kill_widget "system_monitor" "quiet"
    
    rm -rf "$LOCK_DIR" 2>/dev/null
    
    echo "✅ All widgets stopped"
}

show_status() {
    echo "═══════════════════════════════════════════════════════════"
    echo "                    Widget Status"
    echo "═══════════════════════════════════════════════════════════"
    
    for widget in clock weather system_monitor; do
        local pid=$(pgrep -f "${widget}_widget.py" 2>/dev/null)
        local enabled=$(is_widget_enabled "$widget")
        local status_icon="❌"
        local config_icon="⏸️"
        
        [ -n "$pid" ] && status_icon="✅"
        [ "$enabled" = "true" ] && config_icon="🟢" || config_icon="🔴"
        
        printf "   %s %-15s Config: %s" "$status_icon" "$widget" "$config_icon"
        [ -n "$pid" ] && printf " (PID: %s)" "$pid"
        echo ""
    done
    
    echo "═══════════════════════════════════════════════════════════"
    echo "Config: $CONFIG_FILE"
    echo "═══════════════════════════════════════════════════════════"
}

start_enabled_widgets() {
    echo "🚀 Starting enabled widgets..."
    echo ""
    
    start_widget "clock"
    start_widget "weather"
    start_widget "system_monitor"
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

mkdir -p "$LOCK_DIR"

# Check layer shell
if [ -f "$LAYER_SHELL_LIB" ]; then
    echo "✅ Layer shell: $LAYER_SHELL_LIB"
else
    echo "⚠️  gtk4-layer-shell not found"
fi
echo ""

case "$1" in
    stop|kill)
        kill_all_widgets
        ;;
    restart)
        kill_all_widgets
        sleep 0.3
        start_enabled_widgets
        show_status
        ;;
    status)
        show_status
        ;;
    clock)
        # Toggle or start clock
        if pgrep -f "clock_widget.py" &>/dev/null; then
            kill_widget "clock"
        else
            start_widget "clock" "force"
        fi
        ;;
    weather)
        if pgrep -f "weather_widget.py" &>/dev/null; then
            kill_widget "weather"
        else
            start_widget "weather" "force"
        fi
        ;;
    system_monitor|sysmon)
        if pgrep -f "system_monitor_widget.py" &>/dev/null; then
            kill_widget "system_monitor"
        else
            start_widget "system_monitor" "force"
        fi
        ;;
    ""|start)
        kill_all_widgets
        sleep 0.3
        start_enabled_widgets
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|clock|weather|system_monitor}"
        exit 1
        ;;
esac