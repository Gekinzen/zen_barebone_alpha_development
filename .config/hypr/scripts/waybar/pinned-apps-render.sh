#!/usr/bin/env bash
# Show pinned apps that are NOT currently running

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"

[ ! -f "$PIN_FILE" ] && echo '{"text":"","tooltip":"No pinned apps","class":"pinned"}' && exit 0

# Get pinned apps
PINNED_APPS=$(jq -r '.pinned[]?' "$PIN_FILE" 2>/dev/null)

[ -z "$PINNED_APPS" ] && echo '{"text":"","tooltip":"No pinned apps","class":"pinned"}' && exit 0

# Get running apps
RUNNING_APPS=$(hyprctl clients -j 2>/dev/null | jq -r '.[].class' | sort -u)

# Filter: only show pinned apps that are NOT running
PINNED_NOT_RUNNING=""
TOOLTIP=""

while IFS= read -r app; do
    if ! echo "$RUNNING_APPS" | grep -qx "$app"; then
        # App is pinned but not running - show it
        
        # Get icon (Nerd Font mapping)
        case "$(echo "$app" | tr '[:upper:]' '[:lower:]')" in
            *firefox*|*mozilla*) icon="󰈹" ;;
            *chrome*|*chromium*) icon="󰊯" ;;
            *code*|*vscode*) icon="󰨞" ;;
            *kitty*|*alacritty*|*terminal*) icon="󰆍" ;;
            *thunar*|*nautilus*|*dolphin*) icon="󰝰" ;;
            *discord*) icon="󰙯" ;;
            *telegram*) icon="󰚩" ;;
            *spotify*) icon="󰓇" ;;
            *steam*) icon="󰓓" ;;
            *gimp*) icon="󰏘" ;;
            *obs*) icon="󰑋" ;;
            *) icon="󰣆" ;;
        esac
        
        PINNED_NOT_RUNNING="$PINNED_NOT_RUNNING$icon  "  # Double space for spacing
        TOOLTIP="$TOOLTIP$app (pinned - click to launch)\n"
    fi
done <<< "$PINNED_APPS"

# Output JSON for Waybar
if [ -n "$PINNED_NOT_RUNNING" ]; then
    # Remove trailing spaces
    PINNED_NOT_RUNNING=$(echo "$PINNED_NOT_RUNNING" | sed 's/  $//')
    echo "{\"text\":\"$PINNED_NOT_RUNNING\",\"tooltip\":\"$TOOLTIP\",\"class\":\"pinned\"}"
else
    echo "{\"text\":\"\",\"tooltip\":\"All pinned apps running\",\"class\":\"pinned\"}"
fi