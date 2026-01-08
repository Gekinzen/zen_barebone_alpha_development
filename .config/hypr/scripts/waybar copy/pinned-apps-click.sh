#!/usr/bin/env bash
# Pinned Apps Click - Show pinned apps separated by running status

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"

mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

# ═══════════════════════════════════════════════════════════════
# GET ICON FOR APP
# ═══════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════
# LAUNCH FUNCTION (DEFINED EARLY SO IT'S AVAILABLE)
# ═══════════════════════════════════════════════════════════════

launch_app() {
    local app="$1"
    local app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    
    echo "DEBUG: Attempting to launch: $app (lowercase: $app_lower)" >&2
    
    case "$app_lower" in
        *firefox*|*mozilla*)
            echo "DEBUG: Launching firefox" >&2
            firefox &
            ;;
        *chrome*|*google-chrome*)
            echo "DEBUG: Launching google-chrome-stable" >&2
            google-chrome-stable &
            ;;
        *chromium*)
            echo "DEBUG: Launching chromium" >&2
            chromium &
            ;;
        *brave*)
            echo "DEBUG: Launching brave" >&2
            brave &
            ;;
        *code*|*vscode*)
            echo "DEBUG: Launching code" >&2
            code &
            ;;
        *kitty*)
            echo "DEBUG: Launching kitty" >&2
            kitty &
            ;;
        *alacritty*)
            echo "DEBUG: Launching alacritty" >&2
            alacritty &
            ;;
        *thunar*)
            echo "DEBUG: Launching thunar" >&2
            thunar &
            ;;
        *nemo*)
            echo "DEBUG: Launching nemo" >&2
            nemo &
            ;;
        *nautilus*)
            echo "DEBUG: Launching nautilus" >&2
            nautilus &
            ;;
        *discord*)
            echo "DEBUG: Launching discord" >&2
            discord &
            ;;
        *telegram*)
            echo "DEBUG: Launching telegram-desktop" >&2
            telegram-desktop &
            ;;
        *spotify*)
            echo "DEBUG: Launching spotify" >&2
            spotify &
            ;;
        *steam*)
            echo "DEBUG: Launching steam" >&2
            steam &
            ;;
        *obs*)
            echo "DEBUG: Launching obs" >&2
            obs &
            ;;
        *)
            echo "DEBUG: Trying generic launch methods" >&2
            
            # Try exact command name
            if command -v "$app" &>/dev/null; then
                echo "DEBUG: Found command: $app" >&2
                "$app" &
            # Try lowercase
            elif command -v "$app_lower" &>/dev/null; then
                echo "DEBUG: Found command: $app_lower" >&2
                "$app_lower" &
            # Try gtk-launch
            else
                echo "DEBUG: Trying gtk-launch $app" >&2
                if gtk-launch "$app" 2>/dev/null; then
                    echo "DEBUG: gtk-launch succeeded" >&2
                else
                    echo "DEBUG: All launch methods failed" >&2
                    notify-send "Pinned Apps" "Could not launch $app"
                fi
            fi
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# GET PINNED APPS
# ═══════════════════════════════════════════════════════════════

PINNED_APPS=$(jq -r '.pinned[]?' "$PIN_FILE" 2>/dev/null)

if [ -z "$PINNED_APPS" ]; then
    notify-send "Pinned Apps" "No pinned apps"
    exit 0
fi

# Separate running and not running
RUNNING_MENU=""
NOT_RUNNING_MENU=""
declare -A APP_MAP

while IFS= read -r app; do
    [ -z "$app" ] && continue
    
    ICON=$(get_icon "$app")
    
    # Check if app is running (case insensitive match)
    WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$app" \
        'map(select(.class | ascii_downcase | contains($app | ascii_downcase)))')
    
    WINDOW_COUNT=$(echo "$WINDOWS" | jq 'length')
    
    if [ "$WINDOW_COUNT" -gt 0 ]; then
        # App is running
        if [ "$WINDOW_COUNT" -gt 1 ]; then
            MENU_ITEM="$ICON  $app ($WINDOW_COUNT windows)"
        else
            MENU_ITEM="$ICON  $app"
        fi
        RUNNING_MENU="$RUNNING_MENU$MENU_ITEM
"
    else
        # App not running
        MENU_ITEM="$ICON  $app"
        NOT_RUNNING_MENU="$NOT_RUNNING_MENU$MENU_ITEM
"
    fi
    
    APP_MAP["$MENU_ITEM"]="$app"
done <<< "$PINNED_APPS"

# ═══════════════════════════════════════════════════════════════
# BUILD FINAL MENU
# ═══════════════════════════════════════════════════════════════

MENU_ITEMS=""

# Add running apps section
if [ -n "$RUNNING_MENU" ]; then
    MENU_ITEMS="Running
$RUNNING_MENU"
fi

# Add separator if both sections exist
if [ -n "$RUNNING_MENU" ] && [ -n "$NOT_RUNNING_MENU" ]; then
    MENU_ITEMS="${MENU_ITEMS}───────────────
"
fi

# Add not running section
if [ -n "$NOT_RUNNING_MENU" ]; then
    MENU_ITEMS="${MENU_ITEMS}Not Running
$NOT_RUNNING_MENU"
fi

# ═══════════════════════════════════════════════════════════════
# SHOW ROFI MENU
# ═══════════════════════════════════════════════════════════════

CHOICE=$(echo -e "$MENU_ITEMS" | rofi -dmenu -i -p "Pinned Apps" -format s)

[ -z "$CHOICE" ] && exit 0

# Skip section headers and separator
if [[ "$CHOICE" == "Running" ]] || [[ "$CHOICE" == "Not Running" ]] || [[ "$CHOICE" == "───────────────" ]]; then
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# GET SELECTED APP AND LAUNCH/FOCUS
# ═══════════════════════════════════════════════════════════════

SELECTED_APP="${APP_MAP[$CHOICE]}"
[ -z "$SELECTED_APP" ] && exit 0

echo "DEBUG: Selected app: $SELECTED_APP" >&2

# Check if app is running (case insensitive)
WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$SELECTED_APP" \
    'map(select(.class | ascii_downcase | contains($app | ascii_downcase)))')

WINDOW_COUNT=$(echo "$WINDOWS" | jq 'length')

echo "DEBUG: Window count: $WINDOW_COUNT" >&2

if [ "$WINDOW_COUNT" -eq 0 ]; then
    # Not running - launch it
    echo "DEBUG: Launching $SELECTED_APP" >&2
    launch_app "$SELECTED_APP"
elif [ "$WINDOW_COUNT" -eq 1 ]; then
    # Single window - focus it
    ADDRESS=$(echo "$WINDOWS" | jq -r '.[0].address')
    echo "DEBUG: Focusing single window: $ADDRESS" >&2
    hyprctl dispatch focuswindow address:$ADDRESS
else
    # Multiple windows - show selection menu
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
        WINDOW_MENU="$WINDOW_MENU$MENU_ITEM
"
        WINDOW_MAP["$MENU_ITEM"]="$ADDRESS"
    done < <(echo "$WINDOWS" | jq -c '.[]')
    
    WINDOW_CHOICE=$(echo -e "$WINDOW_MENU" | rofi -dmenu -i -p "$SELECTED_APP ($WINDOW_COUNT windows)" -format s)
    
    if [ -n "$WINDOW_CHOICE" ]; then
        ADDRESS="${WINDOW_MAP[$WINDOW_CHOICE]}"
        echo "DEBUG: Focusing window: $ADDRESS" >&2
        [ -n "$ADDRESS" ] && hyprctl dispatch focuswindow address:$ADDRESS
    fi
fi