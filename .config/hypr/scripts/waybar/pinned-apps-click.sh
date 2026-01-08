#!/usr/bin/env bash
# Pinned Apps Click - Show pinned apps separated by running status (SMART DETECTION)

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"

mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

# ═══════════════════════════════════════════════════════════════
# SMART APP DETECTION
# ═══════════════════════════════════════════════════════════════

normalize_app_name() {
    local app="$1"
    local normalized=$(echo "$app" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    echo "$normalized"
}

is_same_app() {
    local app1="$1"
    local app2="$2"
    
    local norm1=$(normalize_app_name "$app1")
    local norm2=$(normalize_app_name "$app2")
    
    # Direct match
    [[ "$norm1" == "$norm2" ]] && return 0
    
    # Check if one contains the other
    [[ "$norm1" == *"$norm2"* ]] || [[ "$norm2" == *"$norm1"* ]] && return 0
    
    # Special cases
    case "$norm1" in
        *chrome*|*chromium*|*googlechrome*)
            [[ "$norm2" == *"chrome"* ]] || [[ "$norm2" == *"chromium"* ]] && return 0
            ;;
        *firefox*|*mozilla*)
            [[ "$norm2" == *"firefox"* ]] || [[ "$norm2" == *"mozilla"* ]] && return 0
            ;;
        *code*|*vscode*|*vscodium*)
            [[ "$norm2" == *"code"* ]] || [[ "$norm2" == *"vscode"* ]] && return 0
            ;;
        *discord*)
            [[ "$norm2" == *"discord"* ]] && return 0
            ;;
        *spotify*)
            [[ "$norm2" == *"spotify"* ]] && return 0
            ;;
    esac
    
    return 1
}

# ═══════════════════════════════════════════════════════════════
# GET ICON
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
# LAUNCH FUNCTION WITH SMART FALLBACKS
# ═══════════════════════════════════════════════════════════════

launch_app() {
    local app="$1"
    local app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    
    case "$app_lower" in
        *firefox*|*mozilla*)
            flatpak run org.mozilla.firefox 2>/dev/null || \
            snap run firefox 2>/dev/null || \
            firefox &
            ;;
        *chrome*|*google-chrome*)
            flatpak run com.google.Chrome 2>/dev/null || \
            google-chrome-stable 2>/dev/null || \
            google-chrome 2>/dev/null || \
            chromium &
            ;;
        *chromium*)
            flatpak run org.chromium.Chromium 2>/dev/null || \
            chromium &
            ;;
        *brave*)
            flatpak run com.brave.Browser 2>/dev/null || \
            brave &
            ;;
        *code*|*vscode*)
            flatpak run com.visualstudio.code 2>/dev/null || \
            code &
            ;;
        *discord*)
            flatpak run com.discordapp.Discord 2>/dev/null || \
            discord &
            ;;
        *spotify*)
            flatpak run com.spotify.Client 2>/dev/null || \
            spotify &
            ;;
        *steam*)
            flatpak run com.valvesoftware.Steam 2>/dev/null || \
            steam &
            ;;
        *obs*)
            flatpak run com.obsproject.Studio 2>/dev/null || \
            obs &
            ;;
        *telegram*)
            flatpak run org.telegram.desktop 2>/dev/null || \
            telegram-desktop &
            ;;
        *kitty*) kitty & ;;
        *alacritty*) alacritty & ;;
        *thunar*) thunar & ;;
        *nemo*) nemo & ;;
        *nautilus*) nautilus & ;;
        *)
            if command -v "$app" &>/dev/null; then
                "$app" &
            elif command -v "$app_lower" &>/dev/null; then
                "$app_lower" &
            else
                FLATPAK_APP=$(flatpak list --app 2>/dev/null | grep -i "$app_lower" | head -1 | awk '{print $2}')
                if [ -n "$FLATPAK_APP" ]; then
                    flatpak run "$FLATPAK_APP" &
                else
                    gtk-launch "$app" 2>/dev/null || notify-send "Pinned Apps" "Could not launch $app"
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

# Get all running apps for smart matching
ALL_RUNNING=$(hyprctl clients -j 2>/dev/null | jq -r '.[].class' | sort -u)

# Separate running and not running
RUNNING_MENU=""
NOT_RUNNING_MENU=""
declare -A APP_MAP

while IFS= read -r app; do
    [ -z "$app" ] && continue
    
    ICON=$(get_icon "$app")
    
    # Smart check if app is running
    IS_RUNNING=false
    MATCHED_COUNT=0
    
    while IFS= read -r running_class; do
        [ -z "$running_class" ] && continue
        if is_same_app "$app" "$running_class"; then
            IS_RUNNING=true
            # Count windows
            MATCHED_COUNT=$(hyprctl clients -j 2>/dev/null | jq --arg class "$running_class" \
                '[.[] | select(.class == $class)] | length')
            break
        fi
    done <<< "$ALL_RUNNING"
    
    if [ "$IS_RUNNING" = true ]; then
        # App is running
        if [ "$MATCHED_COUNT" -gt 1 ]; then
            MENU_ITEM="$ICON  $app ($MATCHED_COUNT windows)"
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

if [ -n "$RUNNING_MENU" ]; then
    MENU_ITEMS="Running
$RUNNING_MENU"
fi

if [ -n "$RUNNING_MENU" ] && [ -n "$NOT_RUNNING_MENU" ]; then
    MENU_ITEMS="${MENU_ITEMS}───────────────
"
fi

if [ -n "$NOT_RUNNING_MENU" ]; then
    MENU_ITEMS="${MENU_ITEMS}Not Running
$NOT_RUNNING_MENU"
fi

# ═══════════════════════════════════════════════════════════════
# SHOW ROFI MENU
# ═══════════════════════════════════════════════════════════════

CHOICE=$(echo -e "$MENU_ITEMS" | rofi -dmenu -i -p "Pinned Apps" -format s)

[ -z "$CHOICE" ] && exit 0

# Skip section headers
if [[ "$CHOICE" == "Running" ]] || [[ "$CHOICE" == "Not Running" ]] || [[ "$CHOICE" == "───────────────" ]]; then
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# GET SELECTED APP AND LAUNCH/FOCUS
# ═══════════════════════════════════════════════════════════════

SELECTED_APP="${APP_MAP[$CHOICE]}"
[ -z "$SELECTED_APP" ] && exit 0

# Smart match to find running windows
MATCHED_WINDOWS="[]"
while IFS= read -r window; do
    WINDOW_CLASS=$(echo "$window" | jq -r '.class')
    if is_same_app "$SELECTED_APP" "$WINDOW_CLASS"; then
        MATCHED_WINDOWS=$(echo "$MATCHED_WINDOWS" | jq ". += [$window]")
    fi
done < <(hyprctl clients -j 2>/dev/null | jq -c '.[]')

WINDOW_COUNT=$(echo "$MATCHED_WINDOWS" | jq 'length')

if [ "$WINDOW_COUNT" -eq 0 ]; then
    # Not running - launch it
    launch_app "$SELECTED_APP"
elif [ "$WINDOW_COUNT" -eq 1 ]; then
    # Single window - focus it
    ADDRESS=$(echo "$MATCHED_WINDOWS" | jq -r '.[0].address')
    hyprctl dispatch focuswindow address:$ADDRESS
else
    # Multiple windows - show selection menu
    WINDOW_MENU=""
    declare -A WINDOW_MAP
    
    while IFS= read -r window; do
        TITLE=$(echo "$window" | jq -r '.title')
        WORKSPACE=$(echo "$window" | jq -r '.workspace.name')
        ADDRESS=$(echo "$window" | jq -r '.address')
        
        if [ ${#TITLE} -gt 60 ]; then
            TITLE="${TITLE:0:60}..."
        fi
        
        MENU_ITEM="[WS $WORKSPACE] $TITLE"
        WINDOW_MENU="$WINDOW_MENU$MENU_ITEM
"
        WINDOW_MAP["$MENU_ITEM"]="$ADDRESS"
    done < <(echo "$MATCHED_WINDOWS" | jq -c '.[]')
    
    WINDOW_CHOICE=$(echo -e "$WINDOW_MENU" | rofi -dmenu -i -p "$SELECTED_APP ($WINDOW_COUNT windows)" -format s)
    
    if [ -n "$WINDOW_CHOICE" ]; then
        ADDRESS="${WINDOW_MAP[$WINDOW_CHOICE]}"
        [ -n "$ADDRESS" ] && hyprctl dispatch focuswindow address:$ADDRESS
    fi
fi