#!/bin/bash
# Hyprland Zoom Script with Notifications - FIXED

ACTION="$1"

# Get current zoom factor
CURRENT=$(hyprctl getoption cursor:zoom_factor -j | jq -r '.float')

# Debug: Check if we got a valid number
if [ -z "$CURRENT" ] || [ "$CURRENT" = "null" ]; then
    notify-send -u critical "Zoom Error" "Could not get zoom factor"
    exit 1
fi

case "$ACTION" in
    in)
        # Zoom in (110%)
        NEW=$(echo "$CURRENT * 1.1" | bc -l)
        
        # Apply zoom
        hyprctl keyword cursor:zoom_factor "$NEW" 2>&1
        
        # Wait a moment for it to apply
        sleep 0.1
        
        # Show notification
        PERCENT=$(printf "%.0f" $(echo "$NEW * 100" | bc -l))
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:zoom "🔍 Zoom In" "$PERCENT%"
        ;;
        
    out)
        # Zoom out (90%), minimum 100%
        NEW=$(echo "$CURRENT * 0.9" | bc -l)
        
        # Check minimum
        MIN_CHECK=$(echo "$NEW < 1" | bc -l)
        if [ "$MIN_CHECK" -eq 1 ]; then
            NEW=1.0
        fi
        
        # Apply zoom
        hyprctl keyword cursor:zoom_factor "$NEW" 2>&1
        
        # Wait a moment for it to apply
        sleep 0.1
        
        # Show notification
        PERCENT=$(printf "%.0f" $(echo "$NEW * 100" | bc -l))
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:zoom "🔍 Zoom Out" "$PERCENT%"
        ;;
        
    reset)
        # Reset to 100%
        hyprctl keyword cursor:zoom_factor 1.0 2>&1
        
        # Wait a moment
        sleep 0.1
        
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:zoom "🔍 Zoom Reset" "100%"
        ;;
        
    *)
        echo "Usage: $0 {in|out|reset}"
        exit 1
        ;;
esac