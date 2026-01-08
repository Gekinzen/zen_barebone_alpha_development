#!/usr/bin/env bash

OUTPUT_FILE="$HOME/.config/waybar/taskbar-modules.json"

# Get all running apps
APPS=$(hyprctl clients -j 2>/dev/null | jq -r 'group_by(.class) | map(.[0].class) | .[]')

# Start JSON array
echo '[' > "$OUTPUT_FILE"

FIRST=true
for app in $APPS; do
    [ "$FIRST" = false ] && echo ',' >> "$OUTPUT_FILE"
    FIRST=false
    
    cat >> "$OUTPUT_FILE" <<EOF
  "custom/taskbar-${app}"
EOF
done

echo ']' >> "$OUTPUT_FILE"

# Generate module definitions
echo '{' > "$HOME/.config/waybar/taskbar-defs.json"

FIRST=true
for app in $APPS; do
    [ "$FIRST" = false ] && echo ',' >> "$HOME/.config/waybar/taskbar-defs.json"
    FIRST=false
    
    cat >> "$HOME/.config/waybar/taskbar-defs.json" <<EOF
  "custom/taskbar-${app}": {
    "return-type": "json",
    "exec": "$HOME/.config/hypr/scripts/waybar/taskbar-app.sh ${app}",
    "interval": 1,
    "on-click": "$HOME/.config/hypr/scripts/waybar/taskbar-toggle.sh ${app}",
    "on-click-right": "$HOME/.config/hypr/scripts/waybar/taskbar-menu.sh ${app}"
  }
EOF
done

echo '}' >> "$HOME/.config/waybar/taskbar-defs.json"

# Reload waybar
killall waybar
waybar &