#!/bin/bash

# Hyprland Auto-Tiling Script - Floating Window Snap (Windows-style)
# Keeps windows floating, just snaps them to edges like Windows

# Configuration
EDGE_THRESHOLD=50
LOG_FILE="/tmp/auto-tiling.log"
PID_FILE="/tmp/auto-tiling.pid"
POLL_INTERVAL=0.1

# Single instance check
check_single_instance() {
    if [[ -f "$PID_FILE" ]]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "Killing old instance (PID: $old_pid)..."
            kill "$old_pid" 2>/dev/null
            sleep 0.5
            kill -9 "$old_pid" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    
    echo $$ > "$PID_FILE"
    trap "rm -f '$PID_FILE'; exit" INT TERM EXIT
}

> "$LOG_FILE"

log_debug() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Get monitor info for window position
get_window_monitor() {
    local win_x=$1
    local win_y=$2
    
    local monitors=$(hyprctl monitors -j 2>/dev/null)
    
    echo "$monitors" | jq -c '.[]' | while read -r mon; do
        local mon_name=$(echo "$mon" | jq -r '.name')
        local mon_x=$(echo "$mon" | jq -r '.x')
        local mon_y=$(echo "$mon" | jq -r '.y')
        local mon_width=$(echo "$mon" | jq -r '.width')
        local mon_height=$(echo "$mon" | jq -r '.height')
        
        local mon_right=$((mon_x + mon_width))
        local mon_bottom=$((mon_y + mon_height))
        
        if [[ $win_x -ge $mon_x && $win_x -lt $mon_right && \
              $win_y -ge $mon_y && $win_y -lt $mon_bottom ]]; then
            echo "$mon_name $mon_x $mon_y $mon_width $mon_height"
            return 0
        fi
    done
    
    # Fallback to first monitor
    echo "$monitors" | jq -r '.[0] | "\(.name) \(.x) \(.y) \(.width) \(.height)"'
}

# Snap window (stays floating, just resize/move)
snap_window() {
    local win_addr="$1"
    
    local win_info=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.address == \"$win_addr\")")
    
    if [[ -z "$win_info" ]]; then
        return 1
    fi
    
    local win_x=$(echo "$win_info" | jq -r '.at[0]')
    local win_y=$(echo "$win_info" | jq -r '.at[1]')
    local win_width=$(echo "$win_info" | jq -r '.size[0]')
    local win_height=$(echo "$win_info" | jq -r '.size[1]')
    local is_floating=$(echo "$win_info" | jq -r '.floating')
    local win_class=$(echo "$win_info" | jq -r '.class')
    
    # Only floating windows
    if [[ "$is_floating" != "true" ]]; then
        return 1
    fi
    
    # Get monitor
    local mon_info=$(get_window_monitor $win_x $win_y)
    if [[ -z "$mon_info" ]]; then
        return 1
    fi
    
    read mon_name mon_x mon_y mon_width mon_height <<< "$mon_info"
    
    local right_edge=$((mon_x + mon_width))
    local bottom_edge=$((mon_y + mon_height))
    local win_right=$((win_x + win_width))
    local win_bottom=$((win_y + win_height))
    
    local left_dist=$((win_x - mon_x))
    local right_dist=$((right_edge - win_right))
    local top_dist=$((win_y - mon_y))
    local bottom_dist=$((bottom_edge - win_bottom))
    
    # Calculate half dimensions
    local half_width=$((mon_width / 2))
    local half_height=$((mon_height / 2))
    
    # Corners (quarter screen, stays floating)
    if [[ $left_dist -le $EDGE_THRESHOLD && $top_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "↖ $win_class → Top-Left (floating)"
        hyprctl dispatch resizewindowpixel exact ${half_width} ${half_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact ${mon_x} ${mon_y},address:$win_addr
        return 0
    fi
    
    if [[ $right_dist -le $EDGE_THRESHOLD && $top_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "↗ $win_class → Top-Right (floating)"
        hyprctl dispatch resizewindowpixel exact ${half_width} ${half_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact $((mon_x + half_width)) ${mon_y},address:$win_addr
        return 0
    fi
    
    if [[ $left_dist -le $EDGE_THRESHOLD && $bottom_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "↙ $win_class → Bottom-Left (floating)"
        hyprctl dispatch resizewindowpixel exact ${half_width} ${half_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact ${mon_x} $((mon_y + half_height)),address:$win_addr
        return 0
    fi
    
    if [[ $right_dist -le $EDGE_THRESHOLD && $bottom_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "↘ $win_class → Bottom-Right (floating)"
        hyprctl dispatch resizewindowpixel exact ${half_width} ${half_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact $((mon_x + half_width)) $((mon_y + half_height)),address:$win_addr
        return 0
    fi
    
    # Edges (half screen, stays floating)
    if [[ $left_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "← $win_class → Left (floating)"
        hyprctl dispatch resizewindowpixel exact ${half_width} ${mon_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact ${mon_x} ${mon_y},address:$win_addr
        return 0
    fi
    
    if [[ $right_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "→ $win_class → Right (floating)"
        hyprctl dispatch resizewindowpixel exact ${half_width} ${mon_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact $((mon_x + half_width)) ${mon_y},address:$win_addr
        return 0
    fi
    
    if [[ $top_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "↑ $win_class → Top (floating)"
        hyprctl dispatch resizewindowpixel exact ${mon_width} ${half_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact ${mon_x} ${mon_y},address:$win_addr
        return 0
    fi
    
    if [[ $bottom_dist -le $EDGE_THRESHOLD ]]; then
        log_debug "↓ $win_class → Bottom (floating)"
        hyprctl dispatch resizewindowpixel exact ${mon_width} ${half_height},address:$win_addr
        hyprctl dispatch movewindowpixel exact ${mon_x} $((mon_y + half_height)),address:$win_addr
        return 0
    fi
    
    return 1
}

# Track window positions
declare -A window_positions
declare -A last_check_time

# Monitor using polling
monitor_windows() {
    check_single_instance
    
    log_debug "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_debug "  FLOATING WINDOW SNAP (Windows-style)"
    log_debug "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_debug "Threshold: ${EDGE_THRESHOLD}px"
    log_debug "Poll interval: ${POLL_INTERVAL}s"
    log_debug "Mode: Snap only (stays floating)"
    
    echo ""
    echo "✓ Window Snap Active (PID: $$)"
    echo "  • Drag floating windows to edges to snap"
    echo "  • Windows stay floating (no tiling)"
    echo "  • Corners = quarter screen"
    echo "  • Edges = half screen"
    echo "  • Log: tail -f $LOG_FILE"
    echo ""
    
    local check_count=0
    
    while true; do
        # Get all floating windows
        local floating_windows=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.floating == true) | .address')
        
        if [[ -n "$floating_windows" ]]; then
            while IFS= read -r win_addr; do
                if [[ -z "$win_addr" ]]; then
                    continue
                fi
                
                # Get current position
                local win_info=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.address == \"$win_addr\")")
                if [[ -z "$win_info" ]]; then
                    continue
                fi
                
                local win_x=$(echo "$win_info" | jq -r '.at[0]')
                local win_y=$(echo "$win_info" | jq -r '.at[1]')
                local current_pos="${win_x},${win_y}"
                
                # Check if position changed
                local last_pos="${window_positions[$win_addr]}"
                
                if [[ "$current_pos" != "$last_pos" ]]; then
                    window_positions[$win_addr]="$current_pos"
                    
                    # Debounce - only check if enough time passed
                    local now=$(date +%s)
                    local last_check="${last_check_time[$win_addr]:-0}"
                    
                    if [[ $((now - last_check)) -ge 1 ]]; then
                        snap_window "$win_addr"
                        last_check_time[$win_addr]=$now
                    fi
                fi
            done <<< "$floating_windows"
        fi
        
        sleep $POLL_INTERVAL
        
        # Log status every 100 checks
        check_count=$((check_count + 1))
        if [[ $((check_count % 100)) -eq 0 ]]; then
            log_debug "Monitoring... (${check_count} checks)"
        fi
    done
}

# Stop
stop_monitor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping (PID: $pid)..."
            kill "$pid"
            rm -f "$PID_FILE"
            echo "✓ Stopped"
        else
            rm -f "$PID_FILE"
            echo "No running instance"
        fi
    else
        echo "No running instance"
    fi
}

# Status
show_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "✓ Running (PID: $pid)"
            echo "  Log: $LOG_FILE"
            return 0
        else
            rm -f "$PID_FILE"
            echo "✗ Not running"
            return 1
        fi
    else
        echo "✗ Not running"
        return 1
    fi
}

# Main
case "${1:-monitor}" in
    monitor|start)
        monitor_windows
        ;;
    stop)
        stop_monitor
        ;;
    restart)
        stop_monitor
        sleep 1
        monitor_windows
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 [monitor|start|stop|restart|status]"
        echo "  monitor/start - Start window snap monitor"
        echo "  stop          - Stop monitor"
        echo "  restart       - Restart monitor"
        echo "  status        - Check if running"
        exit 1
        ;;
esac