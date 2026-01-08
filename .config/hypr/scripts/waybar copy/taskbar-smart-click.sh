#!/usr/bin/env bash
# Smart wlr/taskbar click handler
# - If 1 window: activate (focus)
# - If 2+ windows: show rofi menu

# ═══════════════════════════════════════════════════════════════
# GET CLICKED APP CLASS
# ═══════════════════════════════════════════════════════════════

# wlr/taskbar focuses the window before running script, so get active window
APP_CLASS=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')

if [ -z "$APP_CLASS" ] || [ "$APP_CLASS" = "null" ]; then
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# COUNT WINDOWS OF THIS APP (across ALL workspaces)
# ═══════════════════════════════════════════════════════════════

WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$APP_CLASS" \
    'map(select(.class == $app))')

WINDOW_COUNT=$(echo "$WINDOWS" | jq 'length')

# ═══════════════════════════════════════════════════════════════
# IF ONLY 1 WINDOW - Just activate (already done by wlr/taskbar)
# ═══════════════════════════════════════════════════════════════

if [ "$WINDOW_COUNT" -le 1 ]; then
    # Single window - already focused by wlr/taskbar, nothing to do
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# IF MULTIPLE WINDOWS - Show rofi menu to choose
# ═══════════════════════════════════════════════════════════════

MENU=""
declare -A ADDR_MAP

while IFS= read -r window; do
    TITLE=$(echo "$window" | jq -r '.title')
    WORKSPACE=$(echo "$window" | jq -r '.workspace.name')
    ADDRESS=$(echo "$window" | jq -r '.address')
    
    # Truncate title if too long
    if [ ${#TITLE} -gt 60 ]; then
        TITLE="${TITLE:0:60}..."
    fi
    
    # Format: [WS X] Title
    MENU_ITEM="[WS $WORKSPACE] $TITLE"
    MENU="$MENU$MENU_ITEM\n"
    
    # Store address mapping
    ADDR_MAP["$MENU_ITEM"]="$ADDRESS"
done < <(echo "$WINDOWS" | jq -c '.[]')

# Show rofi menu
CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "Switch to ($WINDOW_COUNT windows)" -format s)

# Focus selected window
if [ -n "$CHOICE" ]; then
    ADDRESS="${ADDR_MAP[$CHOICE]}"
    
    if [ -n "$ADDRESS" ]; then
        hyprctl dispatch focuswindow address:$ADDRESS
    fi
fi