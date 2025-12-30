#!/bin/bash
# Hyprland Control Center - Wallpaper Slideshow Daemon
# Place in: ~/.config/hypr/scripts/wallpaper-slideshow.sh
# Add to hyprland.conf: exec-once = ~/.config/hypr/scripts/wallpaper-slideshow.sh

CONFIG_FILE="$HOME/.config/hypr-control-center/preferences/wallpaper.json"
WALLPAPER_FOLDER=""
INTERVAL=60
TRANSITION="fade"
RANDOM_TRANSITION=false

# Function to read JSON config
read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found: $CONFIG_FILE"
        exit 0
    fi
    
    # Check if slideshow is enabled
    ENABLED=$(jq -r '.slideshow_enabled // false' "$CONFIG_FILE")
    
    if [ "$ENABLED" != "true" ]; then
        echo "Slideshow disabled in config"
        exit 0
    fi
    
    # Read settings
    WALLPAPER_FOLDER=$(jq -r '.wallpaper_folder // "~/wallpapers"' "$CONFIG_FILE")
    WALLPAPER_FOLDER="${WALLPAPER_FOLDER/#\~/$HOME}"  # Expand ~
    
    INTERVAL=$(jq -r '.slideshow_interval // 60' "$CONFIG_FILE")
    TRANSITION=$(jq -r '.transition_type // "fade"' "$CONFIG_FILE")
    RANDOM_TRANSITION=$(jq -r '.random_transition // false' "$CONFIG_FILE")
    
    echo "Slideshow enabled!"
    echo "Folder: $WALLPAPER_FOLDER"
    echo "Interval: ${INTERVAL}s"
    echo "Transition: $TRANSITION"
    echo "Random: $RANDOM_TRANSITION"
}

# Function to get random wallpaper
get_random_wallpaper() {
    find "$WALLPAPER_FOLDER" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) | shuf -n 1
}

# Function to get random transition
get_random_transition() {
    transitions=("fade" "wipe" "grow" "outer" "wave")
    echo "${transitions[$RANDOM % ${#transitions[@]}]}"
}

# Function to apply wallpaper
apply_wallpaper() {
    local wallpaper="$1"
    local transition="$2"
    
    if [ -z "$wallpaper" ]; then
        echo "No wallpaper found!"
        return 1
    fi
    
    echo "Applying: $wallpaper (transition: $transition)"
    swww img "$wallpaper" --transition-type "$transition"
}

# Main loop
main() {
    # Check if swww is running
    if ! pgrep -x "swww-daemon" > /dev/null; then
        echo "Starting swww daemon..."
        swww-daemon &
        sleep 2
    fi
    
    # Read config
    read_config
    
    # Main slideshow loop
    while true; do
        # Re-read config each iteration (in case user changed it)
        ENABLED=$(jq -r '.slideshow_enabled // false' "$CONFIG_FILE" 2>/dev/null)
        
        if [ "$ENABLED" != "true" ]; then
            echo "Slideshow disabled, exiting..."
            exit 0
        fi
        
        # Get wallpaper
        wallpaper=$(get_random_wallpaper)
        
        # Determine transition
        RANDOM_TRANSITION=$(jq -r '.random_transition // false' "$CONFIG_FILE" 2>/dev/null)
        TRANSITION=$(jq -r '.transition_type // "fade"' "$CONFIG_FILE" 2>/dev/null)
        
        if [ "$RANDOM_TRANSITION" = "true" ] || [ "$TRANSITION" = "random" ]; then
            transition=$(get_random_transition)
        else
            transition="$TRANSITION"
        fi
        
        # Apply
        apply_wallpaper "$wallpaper" "$transition"
        
        # Wait for interval (re-read in case changed)
        INTERVAL=$(jq -r '.slideshow_interval // 60' "$CONFIG_FILE" 2>/dev/null)
        sleep "$INTERVAL"
    done
}

# Run main loop
main