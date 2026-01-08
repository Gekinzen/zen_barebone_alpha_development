#!/usr/bin/env bash
# Smart wlr/taskbar click handler
# - If 1 window: activate (focus)
# - If 2+ windows: show rofi menu (running windows only, then minimized separately)

# ═══════════════════════════════════════════════════════════════
# GET CLICKED APP CLASS
# ═══════════════════════════════════════════════════════════════
# wlr/taskbar focuses the window before running script, so get active window
APP_CLASS=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')

if [ -z "$APP_CLASS" ] || [ "$APP_CLASS" = "null" ]; then
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# COUNT WINDOWS OF THIS APP (not minimized)
# ═══════════════════════════════════════════════════════════════
WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$APP_CLASS" \
    '[.[] | select(.class == $app and .workspace.name != "special:minimized")]')

WINDOW_COUNT=$(echo "$WINDOWS" | jq 'length')

# ═══════════════════════════════════════════════════════════════
# IF ONLY 1 WINDOW - Just activate (already done by wlr/taskbar)
# ═══════════════════════════════════════════════════════════════
if [ "$WINDOW_COUNT" -le 1 ]; then
    # Single window - already focused by wlr/taskbar, nothing to do
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# IF MULTIPLE WINDOWS - Show rofi menu (running first, minimized below)
# ═══════════════════════════════════════════════════════════════
MENU=""
declare -A ADDR_MAP
declare -A WINDOW_STATE

# Section 1: Regular windows (not minimized)
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
    WINDOW_STATE["$MENU_ITEM"]="regular"
done < <(echo "$WINDOWS" | jq -c '.[]')

# Section 2: Minimized windows of this app (if any)
MINIMIZED_WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$APP_CLASS" \
    '[.[] | select(.class == $app and .workspace.name == "special:minimized")]')

MINIMIZED_COUNT=$(echo "$MINIMIZED_WINDOWS" | jq 'length')

if [ "$MINIMIZED_COUNT" -gt 0 ]; then
    MENU="$MENU\n━━━━━━━ 󰖰 Minimized ($MINIMIZED_COUNT) ━━━━━━━\n"
    
    while IFS= read -r window; do
        TITLE=$(echo "$window" | jq -r '.title')
        ADDRESS=$(echo "$window" | jq -r '.address')
        
        # Truncate title if too long
        if [ ${#TITLE} -gt 60 ]; then
            TITLE="${TITLE:0:60}..."
        fi
        
        MENU_ITEM="󰖰  $TITLE"
        MENU="$MENU$MENU_ITEM\n"
        
        ADDR_MAP["$MENU_ITEM"]="$ADDRESS"
        WINDOW_STATE["$MENU_ITEM"]="minimized"
    done < <(echo "$MINIMIZED_WINDOWS" | jq -c '.[]')
fi

TOTAL_COUNT=$((WINDOW_COUNT + MINIMIZED_COUNT))

# Show rofi menu
CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "$APP_CLASS ($TOTAL_COUNT windows)" -format s)

# Handle selection
if [ -n "$CHOICE" ] && [[ "$CHOICE" != "━━━"* ]]; then
    ADDRESS="${ADDR_MAP[$CHOICE]}"
    STATE="${WINDOW_STATE[$CHOICE]}"
    
    if [ -n "$ADDRESS" ]; then
        if [ "$STATE" = "minimized" ]; then
            # Restore to CURRENT workspace and focus
            CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
            hyprctl dispatch movetoworkspace "$CURRENT_WS,address:$ADDRESS"
            hyprctl dispatch focuswindow "address:$ADDRESS"
            notify-send "󰖰 Window" "Restored to workspace $CURRENT_WS" -t 1000
        else
            # Focus regular window
            hyprctl dispatch focuswindow address:$ADDRESS
        fi
    fi
fi