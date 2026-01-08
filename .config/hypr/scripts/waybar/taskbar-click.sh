#!/usr/bin/env bash
# Taskbar click - Show menu with running apps + pinned apps, then minimized apps below

TASKBAR_JSON="$HOME/.config/hypr-control-center/preferences/taskbar.json"

# ═══════════════════════════════════════════════════════════════
# SMART APP DETECTION - Handle different package formats
# ═══════════════════════════════════════════════════════════════

normalize_app_name() {
    local app="$1"
    local normalized=$(echo "$app" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    echo "$normalized"
}

is_same_app() {
    local app1="$1"
    local app2="$2"
    
    # Normalize both names (remove special chars, lowercase)
    local norm1=$(normalize_app_name "$app1")
    local norm2=$(normalize_app_name "$app2")
    
    # Direct match
    [[ "$norm1" == "$norm2" ]] && return 0
    
    # Check if one contains the other
    [[ "$norm1" == *"$norm2"* ]] || [[ "$norm2" == *"$norm1"* ]] && return 0
    
    # Special cases for common apps
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
# GET PINNED APPS
# ═══════════════════════════════════════════════════════════════

PINNED_APPS=$(jq -r '.pinned[]?' "$TASKBAR_JSON" 2>/dev/null)

# Build menu with running apps (NOT minimized)
MENU=""
declare -A APP_DATA
declare -A APP_TYPE

# ═══════════════════════════════════════════════════════════════
# SECTION 1: RUNNING APPS (not minimized)
# ═══════════════════════════════════════════════════════════════

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
    APP_TYPE["$MENU_ITEM"]="running"
done < <(hyprctl clients -j 2>/dev/null | jq -r '[.[] | select(.workspace.name != "special:minimized")] | group_by(.class) | map({app: .[0].class, count: length}) | .[]' | jq -c .)

# ═══════════════════════════════════════════════════════════════
# SECTION 2: PINNED APPS (not running) - SMART DETECTION
# ═══════════════════════════════════════════════════════════════

while IFS= read -r pinned_app; do
    [ -z "$pinned_app" ] && continue
    
    # Check if this pinned app is already running using smart detection
    IS_RUNNING=false
    
    while IFS= read -r running_app; do
        [ -z "$running_app" ] && continue
        if is_same_app "$pinned_app" "$running_app"; then
            IS_RUNNING=true
            break
        fi
    done < <(hyprctl clients -j 2>/dev/null | jq -r '[.[] | select(.workspace.name != "special:minimized")] | .[].class' | sort -u)
    
    # Only add if not running
    if [ "$IS_RUNNING" = false ]; then
        ICON=$(get_icon "$pinned_app")
        MENU_ITEM="$ICON  $pinned_app (pinned)"
        MENU="$MENU$MENU_ITEM\n"
        APP_DATA["$MENU_ITEM"]="$pinned_app"
        APP_TYPE["$MENU_ITEM"]="pinned"
    fi
done <<< "$PINNED_APPS"

# ═══════════════════════════════════════════════════════════════
# SECTION 3: MINIMIZED WINDOWS (separate section at bottom)
# ═══════════════════════════════════════════════════════════════

MINIMIZED_WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c '[.[] | select(.workspace.name == "special:minimized")]')
MINIMIZED_COUNT=$(echo "$MINIMIZED_WINDOWS" | jq 'length')

if [ "$MINIMIZED_COUNT" -gt 0 ]; then
    # Add separator
    MENU="$MENU\n━━━━━━━ 󰖰 Minimized ($MINIMIZED_COUNT) ━━━━━━━\n"
    
    # Add each minimized window with APP + TITLE
    while IFS= read -r window; do
        APP=$(echo "$window" | jq -r '.class')
        TITLE=$(echo "$window" | jq -r '.title')
        ADDRESS=$(echo "$window" | jq -r '.address')
        
        # Truncate long titles
        if [ ${#TITLE} -gt 40 ]; then
            TITLE="${TITLE:0:40}..."
        fi
        
        ICON=$(get_icon "$APP")
        MENU_ITEM="󰖰  $APP: $TITLE"
        
        MENU="$MENU$MENU_ITEM\n"
        APP_DATA["$MENU_ITEM"]="$ADDRESS"
        APP_TYPE["$MENU_ITEM"]="minimized"
    done < <(echo "$MINIMIZED_WINDOWS" | jq -c '.[]')
fi

# ═══════════════════════════════════════════════════════════════
# SHOW MENU
# ═══════════════════════════════════════════════════════════════

if [ -z "$MENU" ]; then
    notify-send "Taskbar" "No apps running"
    exit 0
fi

CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "Taskbar Menu" -format s)

[ -z "$CHOICE" ] || [[ "$CHOICE" == "━━━"* ]] && exit 0

# Get app/address and type
SELECTED_DATA="${APP_DATA[$CHOICE]}"
ITEM_TYPE="${APP_TYPE[$CHOICE]}"

[ -z "$SELECTED_DATA" ] && exit 0

# ═══════════════════════════════════════════════════════════════
# HANDLE SELECTION BASED ON TYPE
# ═══════════════════════════════════════════════════════════════

case "$ITEM_TYPE" in
    "minimized")
        # Get app name and title for notification
        APP_NAME=$(echo "$CHOICE" | sed 's/󰖰  //' | cut -d':' -f1 | xargs)
        
        # Restore minimized window to CURRENT workspace and focus
        CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
        hyprctl dispatch movetoworkspace "$CURRENT_WS,address:$SELECTED_DATA"
        hyprctl dispatch focuswindow "address:$SELECTED_DATA"
        notify-send "󰖰 $APP_NAME" "Restored from minimized" -t 1000
        ;;
        
    "pinned")
        # Launch pinned app
        launch_app "$SELECTED_DATA"
        ;;
        
    "running")
        # Handle running app - SMART DETECTION
        SELECTED_APP="$SELECTED_DATA"
        
        # Get all running windows and match smartly
        ALL_WINDOWS=$(hyprctl clients -j 2>/dev/null | jq -c '[.[] | select(.workspace.name != "special:minimized")]')
        
        MATCHED_WINDOWS="[]"
        while IFS= read -r window; do
            WINDOW_CLASS=$(echo "$window" | jq -r '.class')
            if is_same_app "$SELECTED_APP" "$WINDOW_CLASS"; then
                MATCHED_WINDOWS=$(echo "$MATCHED_WINDOWS" | jq ". += [$window]")
            fi
        done < <(echo "$ALL_WINDOWS" | jq -c '.[]')
        
        WINDOW_COUNT=$(echo "$MATCHED_WINDOWS" | jq 'length')
        
        if [ "$WINDOW_COUNT" -eq 0 ]; then
            # Shouldn't happen, but handle anyway
            launch_app "$SELECTED_APP"
            exit 0
        fi
        
        # If multiple windows - show second menu
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
            done < <(echo "$MATCHED_WINDOWS" | jq -c '.[]')
            
            WINDOW_CHOICE=$(echo -e "$WINDOW_MENU" | rofi -dmenu -i -p "$SELECTED_APP ($WINDOW_COUNT windows)" -format s)
            
            if [ -n "$WINDOW_CHOICE" ]; then
                ADDRESS="${WINDOW_MAP[$WINDOW_CHOICE]}"
                [ -n "$ADDRESS" ] && hyprctl dispatch focuswindow address:$ADDRESS
            fi
        else
            # Single window - focus it
            ADDRESS=$(echo "$MATCHED_WINDOWS" | jq -r '.[0].address')
            hyprctl dispatch focuswindow address:$ADDRESS
        fi
        ;;
esac

# ═══════════════════════════════════════════════════════════════
# LAUNCH FUNCTION - SMART LAUNCH WITH FALLBACKS
# ═══════════════════════════════════════════════════════════════

launch_app() {
    local app="$1"
    local app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    
    # Try specific app launchers first
    case "$app_lower" in
        *firefox*|*mozilla*)
            # Try: flatpak > snap > system
            flatpak run org.mozilla.firefox 2>/dev/null || \
            snap run firefox 2>/dev/null || \
            firefox &
            ;;
        *chrome*|*google-chrome*)
            # Try: flatpak > system > chromium fallback
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
            # Generic fallback: try command > flatpak > gtk-launch
            if command -v "$app" &>/dev/null; then
                "$app" &
            elif command -v "$app_lower" &>/dev/null; then
                "$app_lower" &
            else
                # Try to find and launch via flatpak
                FLATPAK_APP=$(flatpak list --app 2>/dev/null | grep -i "$app_lower" | head -1 | awk '{print $2}')
                if [ -n "$FLATPAK_APP" ]; then
                    flatpak run "$FLATPAK_APP" &
                else
                    gtk-launch "$app" 2>/dev/null || notify-send "Taskbar" "Could not launch $app"
                fi
            fi
            ;;
    esac
}