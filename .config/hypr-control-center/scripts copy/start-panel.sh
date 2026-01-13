#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Hyprland Panel - Launch Script
# Location: ~/.config/hypr-control-center/scripts/start-panel.sh
# ═══════════════════════════════════════════════════════════════

PANEL_DIR="$HOME/.config/hypr-control-center"
PANEL_PID_FILE="/tmp/hypr-panel.pid"
PANEL_LOG="/tmp/hypr-panel.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[HyprPanel]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[HyprPanel]${NC} $1"
}

print_error() {
    echo -e "${RED}[HyprPanel]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[HyprPanel]${NC} $1"
}

# Check if panel is running
is_running() {
    if [ -f "$PANEL_PID_FILE" ]; then
        local pid=$(cat "$PANEL_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    # Also check by process name
    pgrep -f "python3.*daemon.py" > /dev/null 2>&1
    return $?
}

# Start the panel
start_panel() {
    if is_running; then
        print_warning "Panel is already running"
        return 1
    fi
    
    print_status "Starting Hyprland Panel..."
    
    cd "$PANEL_DIR"
    
    # Start panel in background
    nohup python3 -m src.panel.daemon > "$PANEL_LOG" 2>&1 &
    local pid=$!
    
    echo "$pid" > "$PANEL_PID_FILE"
    
    # Wait a moment and check if it started
    sleep 1
    
    if ps -p "$pid" > /dev/null 2>&1; then
        print_success "Panel started (PID: $pid)"
        return 0
    else
        print_error "Failed to start panel. Check log: $PANEL_LOG"
        return 1
    fi
}

# Stop the panel
stop_panel() {
    if ! is_running; then
        print_warning "Panel is not running"
        return 1
    fi
    
    print_status "Stopping Hyprland Panel..."
    
    # Kill by PID file
    if [ -f "$PANEL_PID_FILE" ]; then
        local pid=$(cat "$PANEL_PID_FILE")
        kill "$pid" 2>/dev/null
        rm -f "$PANEL_PID_FILE"
    fi
    
    # Also kill any remaining processes
    pkill -f "python3.*daemon.py" 2>/dev/null
    
    print_success "Panel stopped"
    return 0
}

# Restart the panel
restart_panel() {
    print_status "Restarting Hyprland Panel..."
    stop_panel
    sleep 1
    start_panel
}

# Toggle panel (start if stopped, stop if running)
toggle_panel() {
    if is_running; then
        stop_panel
    else
        start_panel
    fi
}

# Show status
status_panel() {
    if is_running; then
        local pid=$(cat "$PANEL_PID_FILE" 2>/dev/null || pgrep -f "python3.*daemon.py")
        print_success "Panel is running (PID: $pid)"
        return 0
    else
        print_warning "Panel is not running"
        return 1
    fi
}

# Show logs
logs_panel() {
    if [ -f "$PANEL_LOG" ]; then
        tail -f "$PANEL_LOG"
    else
        print_error "No log file found"
    fi
}

# Main
case "${1:-start}" in
    start)
        start_panel
        ;;
    stop)
        stop_panel
        ;;
    restart)
        restart_panel
        ;;
    toggle)
        toggle_panel
        ;;
    status)
        status_panel
        ;;
    logs)
        logs_panel
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|toggle|status|logs}"
        exit 1
        ;;
esac