#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Hyprland Panel - Launch Script (Auto-detect Waybar)
# Location: ~/.config/hypr-control-center/scripts/start-panel.sh
# ═══════════════════════════════════════════════════════════════

PANEL_DIR="$HOME/.config/hypr-control-center"
PANEL_PID="/tmp/hypr-panel.pid"
PANEL_LOG="/tmp/hypr-panel.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[HyprPanel]${NC} $1"; }
print_success() { echo -e "${GREEN}[HyprPanel]${NC} $1"; }
print_error() { echo -e "${RED}[HyprPanel]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[HyprPanel]${NC} $1"; }

is_running() {
    if [ -f "$PANEL_PID" ]; then
        pid=$(cat "$PANEL_PID")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    pgrep -f "python3.*panel_widget" > /dev/null 2>&1
    return $?
}

start_panel() {
    if is_running; then
        print_warning "Panel already running"
        return 1
    fi
    
    print_status "Starting Hyprland Panel..."
    
    cd "$PANEL_DIR"
    
    # CRITICAL: LD_PRELOAD required for GTK4 Layer Shell to work!
    export LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so
    
    # Start panel
    nohup python3 src/panel/panel_widget.py > "$PANEL_LOG" 2>&1 &
    pid=$!
    echo "$pid" > "$PANEL_PID"
    
    sleep 1
    
    if ps -p "$pid" > /dev/null 2>&1; then
        print_success "Panel started (PID: $pid)"
        return 0
    else
        print_error "Failed to start. Check: $PANEL_LOG"
        cat "$PANEL_LOG"
        return 1
    fi
}

stop_panel() {
    if ! is_running; then
        print_warning "Panel not running"
        return 1
    fi
    
    print_status "Stopping panel..."
    
    if [ -f "$PANEL_PID" ]; then
        kill $(cat "$PANEL_PID") 2>/dev/null
        rm -f "$PANEL_PID"
    fi
    
    pkill -f "python3.*panel_widget" 2>/dev/null
    
    print_success "Panel stopped"
}

restart_panel() {
    print_status "Restarting panel..."
    stop_panel
    sleep 1
    start_panel
}

status_panel() {
    if is_running; then
        pid=$(cat "$PANEL_PID" 2>/dev/null || pgrep -f "python3.*src.panel.daemon")
        print_success "Running (PID: $pid)"
    else
        print_warning "Not running"
    fi
}

logs_panel() {
    if [ -f "$PANEL_LOG" ]; then
        tail -f "$PANEL_LOG"
    else
        print_error "No log file"
    fi
}

case "${1:-start}" in
    start)   start_panel ;;
    stop)    stop_panel ;;
    restart) restart_panel ;;
    toggle)  is_running && stop_panel || start_panel ;;
    status)  status_panel ;;
    logs)    logs_panel ;;
    *)       echo "Usage: $0 {start|stop|restart|toggle|status|logs}" ;;
esac