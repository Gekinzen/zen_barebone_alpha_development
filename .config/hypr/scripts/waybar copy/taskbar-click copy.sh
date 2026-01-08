#!/usr/bin/env bash

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"
CACHE_DIR="$HOME/.cache/waybar"
APPS_FILE="$CACHE_DIR/taskbar-apps"

mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

# Get click position (character index in the taskbar text)
CLICK_POS="${1:-0}"

# Get current taskbar apps from cache
[ ! -f "$APPS_FILE" ] && exit 0

# Read apps into array
mapfile -t APPS < "$APPS_FILE"

# Calculate which app was clicked based on position
# Each app icon is roughly 2-3 characters wide (icon + space)
APP_INDEX=$((CLICK_POS / 3))

# Get the clicked app
APP="${APPS[$APP_INDEX]}"
[ -z "$APP" ] && exit 0

# Check if app is running
IS_RUNNING=$(hyprctl clients -j 2>/dev/null | jq -e --arg app "$APP" 'map(select(.class == $app)) | length > 0')

if [ "$IS_RUNNING" = "true" ]; then
    # App is running - focus or show menu
    WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -r --arg app "$APP" '
        map(select(.class == $app)) | .[] | .address
    ')
    
    WINDOW_COUNT=$(echo "$WINDOWS" | wc -l)
    
    if [ "$WINDOW_COUNT" -eq 1 ]; then
        # Single window - just focus it
        ADDR=$(echo "$WINDOWS" | head -1)
        hyprctl dispatch focuswindow address:$ADDR
    else
        # Multiple windows - show menu
        "$HOME/.config/hypr/scripts/waybar/taskbar-menu.sh" "$APP"
    fi
else
    # App is NOT running - it's pinned, so launch it
    # Try to launch the app
    APP_LOWER=$(echo "$APP" | tr '[:upper:]' '[:lower:]')
    
    # Common app launch commands
    case "$APP_LOWER" in
        firefox|org.mozilla.firefox)
            firefox &
            ;;
        chrome|google-chrome)
            google-chrome-stable &
            ;;
        chromium*)
            chromium &
            ;;
        code|vscode|code-oss)
            code &
            ;;
        kitty)
            kitty &
            ;;
        alacritty)
            alacritty &
            ;;
        thunar)
            thunar &
            ;;
        nautilus|org.gnome.nautilus)
            nautilus &
            ;;
        discord)
            discord &
            ;;
        telegram*)
            telegram-desktop &
            ;;
        spotify)
            spotify &
            ;;
        vlc)
            vlc &
            ;;
        obs)
            obs &
            ;;
        steam)
            steam &
            ;;
        gimp*)
            gimp &
            ;;
        *)
            # Try to launch using the class name directly
            if command -v "$APP" &>/dev/null; then
                "$APP" &
            elif command -v "$APP_LOWER" &>/dev/null; then
                "$APP_LOWER" &
            else
                # Try with gtk-launch
                gtk-launch "$APP" 2>/dev/null || \
                gtk-launch "$APP_LOWER" 2>/dev/null || \
                notify-send "Taskbar" "Could not launch $APP"
            fi
            ;;
    esac
fi