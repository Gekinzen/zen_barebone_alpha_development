#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# ZenPyBar - Python Waybar Replacement
# Location: ~/.config/hypr-control-center/scripts/start-zenpybar.sh
# ═══════════════════════════════════════════════════════════════

ZENPYBAR_DIR="$HOME/.config/hypr-control-center"
ZENPYBAR_PID="/tmp/zenpybar.pid"
ZENPYBAR_LOG="/tmp/zenpybar.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${CYAN}[ZenPyBar]${NC} $1"; }
print_success() { echo -e "${GREEN}[ZenPyBar]${NC} $1"; }
print_error() { echo -e "${RED}[ZenPyBar]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[ZenPyBar]${NC} $1"; }

is_running() {
    if [ -f "$ZENPYBAR_PID" ]; then
        pid=$(cat "$ZENPYBAR_PID")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    pgrep -f "python3.*zenpybar" > /dev/null 2>&1
    return $?
}

start_bar() {
    if is_running; then
        print_warning "ZenPyBar already running"
        return 1
    fi
    
    print_status "Starting ZenPyBar..."
    
    # Kill Waybar if running
    if pgrep -x waybar > /dev/null; then
        print_status "Stopping Waybar..."
        pkill waybar
        sleep 0.5
    fi
    
    cd "$ZENPYBAR_DIR"
    
    # CRITICAL: LD_PRELOAD for GTK4 Layer Shell
    export LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so
    
    # Start bar
    nohup python3 src/zenpybar/bar.py > "$ZENPYBAR_LOG" 2>&1 &
    pid=$!
    echo "$pid" > "$ZENPYBAR_PID"
    
    sleep 1
    
    if ps -p "$pid" > /dev/null 2>&1; then
        print_success "ZenPyBar started (PID: $pid)"
        return 0
    else
        print_error "Failed to start. Check: $ZENPYBAR_LOG"
        tail -20 "$ZENPYBAR_LOG"
        return 1
    fi
}

stop_bar() {
    if ! is_running; then
        print_warning "ZenPyBar not running"
        return 1
    fi
    
    print_status "Stopping ZenPyBar..."
    
    if [ -f "$ZENPYBAR_PID" ]; then
        kill $(cat "$ZENPYBAR_PID") 2>/dev/null
        rm -f "$ZENPYBAR_PID"
    fi
    
    pkill -f "python3.*zenpybar" 2>/dev/null
    
    print_success "ZenPyBar stopped"
}

restart_bar() {
    print_status "Restarting ZenPyBar..."
    stop_bar
    sleep 1
    start_bar
}

status_bar() {
    if is_running; then
        pid=$(cat "$ZENPYBAR_PID" 2>/dev/null || pgrep -f "python3.*zenpybar")
        print_success "Running (PID: $pid)"
    else
        print_warning "Not running"
    fi
}

logs_bar() {
    if [ -f "$ZENPYBAR_LOG" ]; then
        tail -f "$ZENPYBAR_LOG"
    else
        print_error "No log file"
    fi
}

switch_to_waybar() {
    print_status "Switching to Waybar..."
    stop_bar
    sleep 0.5
    waybar &
    print_success "Waybar started"
}

case "${1:-start}" in
    start)   start_bar ;;
    stop)    stop_bar ;;
    restart) restart_bar ;;
    toggle)  is_running && stop_bar || start_bar ;;
    status)  status_bar ;;
    logs)    logs_bar ;;
    waybar)  switch_to_waybar ;;
    *)
        echo "ZenPyBar - Python Waybar Replacement"
        echo ""
        echo "Usage: $0 {start|stop|restart|toggle|status|logs|waybar}"
        echo ""
        echo "Commands:"
        echo "  start   - Start ZenPyBar (stops Waybar first)"
        echo "  stop    - Stop ZenPyBar"
        echo "  restart - Restart ZenPyBar"
        echo "  toggle  - Toggle on/off"
        echo "  status  - Check if running"
        echo "  logs    - View logs"
        echo "  waybar  - Switch back to Waybar"
        ;;
esac
