#!/usr/bin/env bash
# Alt+Tab with Rofi - Simple & Working
# Rofi already lets you spam Tab to cycle!
# 6-second auto-kill if idle

LOCKFILE="/tmp/alt-tab-rofi.lock"
TIMEOUT=6

# ═══════════════════════════════════════════════════════════════
# PREVENT MULTIPLE INSTANCES
# ═══════════════════════════════════════════════════════════════

if [ -f "$LOCKFILE" ]; then
    exit 0
fi

touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# ═══════════════════════════════════════════════════════════════
# ROFI CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Check for One Dark theme
THEME_FILE="$HOME/.config/rofi/window-switcher-onedark.rasi"

if [ -f "$THEME_FILE" ]; then
    THEME_ARG="-theme $THEME_FILE"
else
    THEME_ARG=""
fi

# ═══════════════════════════════════════════════════════════════
# LAUNCH ROFI WITH 6-SECOND TIMEOUT
# ═══════════════════════════════════════════════════════════════

# Launch rofi in background
(
    rofi -show window \
        $THEME_ARG \
        -window-format "{c}  │  {t}" \
        -selected-row 1 \
        2>/dev/null
) &

ROFI_PID=$!

# Auto-kill timer
(
    sleep $TIMEOUT
    if kill -0 $ROFI_PID 2>/dev/null; then
        kill $ROFI_PID 2>/dev/null
    fi
) &

TIMER_PID=$!

# Wait for rofi to finish
wait $ROFI_PID 2>/dev/null
ROFI_EXIT=$?

# Kill timer
kill $TIMER_PID 2>/dev/null

# Exit if cancelled (ESC or timeout)
[ $ROFI_EXIT -ne 0 ] && exit 0

# ═══════════════════════════════════════════════════════════════
# AUTO MOUSE MOVEMENT TO SELECTED WINDOW
# ═══════════════════════════════════════════════════════════════

sleep 0.1

ACTIVE_WINDOW=$(hyprctl activewindow -j 2>/dev/null)

if [ "$(echo "$ACTIVE_WINDOW" | jq -r '.address')" != "0x" ]; then
    X=$(echo "$ACTIVE_WINDOW" | jq -r '.at[0]')
    Y=$(echo "$ACTIVE_WINDOW" | jq -r '.at[1]')
    W=$(echo "$ACTIVE_WINDOW" | jq -r '.size[0]')
    H=$(echo "$ACTIVE_WINDOW" | jq -r '.size[1]')
    
    # Move mouse to window center
    CENTER_X=$((X + W/2))
    CENTER_Y=$((Y + H/2))
    
    hyprctl dispatch movecursor $CENTER_X $CENTER_Y
fi

rm -f "$LOCKFILE"