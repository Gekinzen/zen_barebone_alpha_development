#!/usr/bin/env bash
# Alt+Tab TRUE Cycling - Spam Tab to cycle like Windows
# Uses Hyprland's cyclenext with visual feedback

# ═══════════════════════════════════════════════════════════════
# CYCLE TO NEXT WINDOW
# ═══════════════════════════════════════════════════════════════

# Use Hyprland's built-in window cycling
hyprctl dispatch cyclenext

# Small delay for focus to register
sleep 0.05

# ═══════════════════════════════════════════════════════════════
# GET ACTIVE WINDOW INFO
# ═══════════════════════════════════════════════════════════════

ACTIVE_WINDOW=$(hyprctl activewindow -j 2>/dev/null)

if [ "$(echo "$ACTIVE_WINDOW" | jq -r '.address')" = "0x" ]; then
    exit 0
fi

# Get window details
APP=$(echo "$ACTIVE_WINDOW" | jq -r '.class')
TITLE=$(echo "$ACTIVE_WINDOW" | jq -r '.title')
WORKSPACE=$(echo "$ACTIVE_WINDOW" | jq -r '.workspace.id')
X=$(echo "$ACTIVE_WINDOW" | jq -r '.at[0]')
Y=$(echo "$ACTIVE_WINDOW" | jq -r '.at[1]')
W=$(echo "$ACTIVE_WINDOW" | jq -r '.size[0]')
H=$(echo "$ACTIVE_WINDOW" | jq -r '.size[1]')

# ═══════════════════════════════════════════════════════════════
# AUTO MOUSE MOVEMENT
# ═══════════════════════════════════════════════════════════════

CENTER_X=$((X + W/2))
CENTER_Y=$((Y + H/2))

hyprctl dispatch movecursor $CENTER_X $CENTER_Y

# ═══════════════════════════════════════════════════════════════
# VISUAL FEEDBACK (Optional notification)
# ═══════════════════════════════════════════════════════════════

# Get icon for app
get_icon() {
    local app=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$app" in
        *firefox*|*mozilla*) echo "󰈹" ;;
        *chrome*|*chromium*|*brave*) echo "󰊯" ;;
        *code*|*vscode*|*vscodium*) echo "󰨞" ;;
        *kitty*|*alacritty*|*terminal*) echo "󰆍" ;;
        *thunar*|*nautilus*|*nemo*|*dolphin*) echo "󰝰" ;;
        *discord*) echo "󰙯" ;;
        *telegram*) echo "󰚩" ;;
        *spotify*) echo "󰓇" ;;
        *steam*) echo "󰓓" ;;
        *obs*) echo "󰑋" ;;
        *) echo "󰣆" ;;
    esac
}

ICON=$(get_icon "$APP")

# Truncate long titles
if [ ${#TITLE} -gt 45 ]; then
    TITLE="${TITLE:0:45}..."
fi

# Count total windows
TOTAL_WINDOWS=$(hyprctl clients -j | jq '[.[] | select(.workspace.name != "special:minimized")] | length')

# Show quick notification (very brief)
notify-send -t 600 -r 9999 \
    "󰖲 $APP" \
    "$TITLE" \
    -h string:x-canonical-private-synchronous:alt-tab