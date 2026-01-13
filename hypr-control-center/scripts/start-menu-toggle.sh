#!/bin/bash
#
# Start Menu Toggle Script for Waybar
# ====================================
# Location: ~/.config/hypr-control-center/scripts/start-menu-toggle.sh
#
# Features:
# - Auto-positions based on Waybar config (same as panel widget)
# - GTK4 Layer Shell support for proper window positioning
# - Smart window detection via Hyprland IPC
#
# Usage: 
#   start-menu-toggle.sh        # Toggle start menu
#   start-menu-toggle.sh open   # Force open
#   start-menu-toggle.sh close  # Force close
#

CONFIG_DIR="$HOME/.config/hypr-control-center"
START_MENU="$CONFIG_DIR/start-menu.py"

# Check if start menu window exists using Hyprland IPC
is_running() {
    hyprctl clients -j | jq -e '.[] | select(.class == "com.hyprland.startmenu" or .title == "Start Menu")' > /dev/null 2>&1
}

# Get window address if running
get_window_address() {
    hyprctl clients -j | jq -r '.[] | select(.class == "com.hyprland.startmenu" or .title == "Start Menu") | .address' 2>/dev/null | head -1
}

# Launch start menu with Layer Shell support
launch_menu() {
    echo "[StartMenu Toggle] 🚀 Opening start menu..."
    echo "[StartMenu Toggle] 📍 Position will be auto-detected from Waybar config"
    
    # Launch with GTK4 Layer Shell preload for proper positioning
    cd "$CONFIG_DIR" && LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 "$START_MENU" &
    
    # Wait a moment to ensure it starts
    sleep 0.1
    
    echo "[StartMenu Toggle] ✅ Start menu launched!"
}

case "${1:-toggle}" in
    open)
        if ! is_running; then
            launch_menu
        else
            # Already open, focus it
            addr=$(get_window_address)
            [ -n "$addr" ] && hyprctl dispatch focuswindow "address:$addr"
            echo "[StartMenu Toggle] ℹ️ Start menu already open, focusing..."
        fi
        ;;
        
    close)
        if is_running; then
            echo "[StartMenu Toggle] 🚪 Closing start menu..."
            addr=$(get_window_address)
            [ -n "$addr" ] && hyprctl dispatch closewindow "address:$addr"
            echo "[StartMenu Toggle] ✅ Start menu closed!"
        else
            echo "[StartMenu Toggle] ℹ️ Start menu not running"
        fi
        ;;
        
    toggle|*)
        if is_running; then
            echo "[StartMenu Toggle] 🚪 Closing start menu..."
            addr=$(get_window_address)
            [ -n "$addr" ] && hyprctl dispatch closewindow "address:$addr"
            echo "[StartMenu Toggle] ✅ Start menu closed!"
        else
            launch_menu
        fi
        ;;
esac