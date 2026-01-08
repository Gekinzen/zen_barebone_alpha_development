#!/usr/bin/env bash
# Taskbar click - Always show rofi menu for accurate selection

TASKBAR_JSON="$HOME/.config/hypr-control-center/preferences/taskbar.json"

# ═══════════════════════════════════════════════════════════════
# GET ALL APPS (pinned + running)
# ═══════════════════════════════════════════════════════════════

# Get pinned apps
PINNED_APPS=$(jq -r '.pinned[]?' "$TASKBAR_JSON" 2>/dev/null)

# Get running apps with icons
get_icon() {
    local app="$1"
    local app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    
    case "$app_lower" in
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

# Build menu with running apps
MENU=""
declare -A APP_DATA

# Add running apps
while IFS= read -r window_data; do
    [ -z "$window_data" ] && continue
    
    APP=$(echo "$window_data" | jq -r '.app')
    COUNT=$(echo "$window_data" | jq -r '.count')
    
    ICON=$(get_icon "$APP")
    
    if [ "$COUNT" -gt 1 ]; then
        MENU_ITEM="$ICON  $APP ($COUNT windows)"
    else
        MENU_ITEM="$ICON  $APP"
    fi
    
    MENU="$MENU$MENU_ITEM\n"
    APP_DATA["$MENU_ITEM"]="$APP"
done < <(hyprctl clients -j 2>/dev/null | jq -r 'group_by(.class) | map({app: .[0].class, count: length}) | .[]' | jq -c .)

# Add pinned apps that are NOT running
while IFS= read -r app; do
    [ -z "$app" ] && continue
    
    # Check if already in menu (running)
    if [[ "$MENU" != *"$app"* ]]; then
        ICON=$(get_icon "$app")
        MENU_ITEM="$ICON  $app (pinned)"
        MENU="$MENU$MENU_ITEM\n"
        APP_DATA["$MENU_ITEM"]="$app"
    fi
done <<< "$PINNED_APPS"

# ═══════════════════════════════════════════════════════════════
# SHOW MENU
# ═══════════════════════════════════════════════════════════════

if [ -z "$MENU" ]; then
    notify-send "Taskbar" "No apps running"
    exit 0
fi

CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "Switch to" -format s)

[ -z "$CHOICE" ] && exit 0

# Get app name from choice
SELECTED_APP="${APP_DATA[$CHOICE]}"

[ -z "$SELECTED_APP" ] && exit 0

# ═══════════════════════════════════════════════════════════════
# CHECK IF APP IS RUNNING
# ═══════════════════════════════════════════════════════════════

WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$SELECTED_APP" \
    'map(select(.class == $app))')

WINDOW_COUNT=$(echo "$WINDOWS" | jq 'length')

if [ "$WINDOW_COUNT" -eq 0 ]; then
    # App is pinned but not running - launch it
    launch_app "$SELECTED_APP"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# IF MULTIPLE WINDOWS - Show second menu to choose which one
# ═══════════════════════════════════════════════════════════════

if [ "$WINDOW_COUNT" -gt 1 ]; then
    WINDOW_MENU=""
    declare -A WINDOW_MAP
    
    while IFS= read -r window; do
        TITLE=$(echo "$window" | jq -r '.title')
        WORKSPACE=$(echo "$window" | jq -r '.workspace.name')
        ADDRESS=$(echo "$window" | jq -r '.address')
        
        # Truncate long titles
        if [ ${#TITLE} -gt 60 ]; then
            TITLE="${TITLE:0:60}..."
        fi
        
        MENU_ITEM="[WS $WORKSPACE] $TITLE"
        WINDOW_MENU="$WINDOW_MENU$MENU_ITEM\n"
        WINDOW_MAP["$MENU_ITEM"]="$ADDRESS"
    done < <(echo "$WINDOWS" | jq -c '.[]')
    
    WINDOW_CHOICE=$(echo -e "$WINDOW_MENU" | rofi -dmenu -i -p "$SELECTED_APP ($WINDOW_COUNT windows)" -format s)
    
    if [ -n "$WINDOW_CHOICE" ]; then
        ADDRESS="${WINDOW_MAP[$WINDOW_CHOICE]}"
        [ -n "$ADDRESS" ] && hyprctl dispatch focuswindow address:$ADDRESS
    fi
else
    # Single window - focus it
    ADDRESS=$(echo "$WINDOWS" | jq -r '.[0].address')
    hyprctl dispatch focuswindow address:$ADDRESS
fi

# ═══════════════════════════════════════════════════════════════
# LAUNCH FUNCTION
# ═══════════════════════════════════════════════════════════════

launch_app() {
    local app="$1"
    local app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    
    case "$app_lower" in
        *firefox*|*mozilla*) firefox & ;;
        *chrome*|google-chrome*) google-chrome-stable & ;;
        *chromium*) chromium & ;;
        *brave*) brave & ;;
        *code*|*vscode*) code & ;;
        *kitty*) kitty & ;;
        *alacritty*) alacritty & ;;
        *thunar*) thunar & ;;
        *nemo*) nemo & ;;
        *nautilus*) nautilus & ;;
        *discord*) discord & ;;
        *telegram*) telegram-desktop & ;;
        *spotify*) spotify & ;;
        *steam*) steam & ;;
        *obs*) obs & ;;
        *)
            if command -v "$app" &>/dev/null; then
                "$app" &
            elif command -v "$app_lower" &>/dev/null; then
                "$app_lower" &
            else
                gtk-launch "$app" 2>/dev/null || notify-send "Taskbar" "Could not launch $app"
            fi
            ;;
    esac
}