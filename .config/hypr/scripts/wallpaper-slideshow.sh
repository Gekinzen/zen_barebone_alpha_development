#!/bin/bash
CONFIG="$HOME/.config/hypr-control-center/preferences/wallpaper.json"

while true; do
    if [ -f "$CONFIG" ]; then
        ENABLED=$(jq -r '.slideshow_enabled // false' "$CONFIG" 2>/dev/null || echo "false")
        
        if [ "$ENABLED" = "true" ]; then
            FOLDER=$(jq -r '.folder // "~/wallpapers"' "$CONFIG" 2>/dev/null)
            FOLDER="${FOLDER/#\~/$HOME}"
            INTERVAL=$(jq -r '.slideshow_interval // 60' "$CONFIG" 2>/dev/null)
            
            IMG=$(find "$FOLDER" -type f \( -iname "*.jpg" -o -iname "*.png" \) 2>/dev/null | shuf -n 1)
            
            if [ -n "$IMG" ]; then
                swww img "$IMG" --transition-type fade 2>/dev/null
                sleep "$INTERVAL"
            else
                sleep 5
            fi
        else
            sleep 2
        fi
    else
        sleep 2
    fi
done
