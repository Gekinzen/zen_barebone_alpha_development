#!/usr/bin/env bash
# wlr/taskbar right-click menu - Shows all running apps to choose which to pin/unpin

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"
mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

# ═══════════════════════════════════════════════════════════════
# GET ALL RUNNING APPS
# ═══════════════════════════════════════════════════════════════

RUNNING_APPS=$(hyprctl clients -j 2>/dev/null | jq -r 'group_by(.class) | map(.[0].class) | .[]' | sort -u)

if [ -z "$RUNNING_APPS" ]; then
    notify-send "Taskbar" "No running applications"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# BUILD APP LIST WITH PIN STATUS
# ═══════════════════════════════════════════════════════════════

MENU=""
while IFS= read -r app; do
    # Check if pinned
    IS_PINNED=$(jq -e --arg app "$app" '.pinned | index($app)' "$PIN_FILE" 2>/dev/null)
    
    if [ "$IS_PINNED" != "null" ] && [ -n "$IS_PINNED" ]; then
        MENU="$MENU📌 $app\n"
    else
        MENU="$MENU   $app\n"
    fi
done <<< "$RUNNING_APPS"

# Add global options
MENU="${MENU}───────────────\n"
MENU="${MENU}Manage Pinned Apps\n"
MENU="${MENU}Close All Windows"

# ═══════════════════════════════════════════════════════════════
# SHOW MENU AND GET SELECTION
# ═══════════════════════════════════════════════════════════════

CHOICE=$(echo -e "$MENU" | rofi -dmenu -i -p "Taskbar")

[ -z "$CHOICE" ] && exit 0

# ═══════════════════════════════════════════════════════════════
# HANDLE SELECTION
# ═══════════════════════════════════════════════════════════════

case "$CHOICE" in
    "───────────────")
        exit 0
        ;;
    
    "Manage Pinned Apps")
        # Show submenu to manage pinned apps
        PINNED=$(jq -r '.pinned[]?' "$PIN_FILE" 2>/dev/null)
        
        if [ -z "$PINNED" ]; then
            notify-send "Taskbar" "No pinned apps"
            exit 0
        fi
        
        UNPIN_APP=$(echo "$PINNED" | rofi -dmenu -i -p "Unpin which app?")
        
        if [ -n "$UNPIN_APP" ]; then
            jq --arg app "$UNPIN_APP" '.pinned -= [$app]' \
                "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
            notify-send "Taskbar" "📌 Unpinned $UNPIN_APP"
        fi
        ;;
    
    "Close All Windows")
        # Confirm
        CONFIRM=$(echo -e "No\nYes" | rofi -dmenu -i -p "Close all windows?")
        
        if [ "$CONFIRM" = "Yes" ]; then
            hyprctl clients -j 2>/dev/null | jq -r '.[].address' | while read -r addr; do
                hyprctl dispatch closewindow address:$addr
            done
            notify-send "Taskbar" "❌ All windows closed"
        fi
        ;;
    
    *)
        # Selected an app - show action menu
        # Remove pin emoji if present
        APP=$(echo "$CHOICE" | sed 's/^📌 //' | sed 's/^   //')
        
        # Check if pinned
        IS_PINNED=$(jq -e --arg app "$APP" '.pinned | index($app)' "$PIN_FILE" 2>/dev/null)
        
        # Build app-specific menu
        if [ "$IS_PINNED" != "null" ] && [ -n "$IS_PINNED" ]; then
            ACTION_MENU="Unpin from Taskbar\nFocus Window\nClose Window\n───────────────\nClose All Windows of $APP"
        else
            ACTION_MENU="Pin to Taskbar\nFocus Window\nClose Window\n───────────────\nClose All Windows of $APP"
        fi
        
        ACTION=$(echo -e "$ACTION_MENU" | rofi -dmenu -i -p "$APP")
        
        case "$ACTION" in
            "Pin to Taskbar")
                jq --arg app "$APP" '.pinned += [$app] | .pinned |= unique' \
                    "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
                notify-send "Taskbar" "📌 Pinned $APP"
                ;;
            
            "Unpin from Taskbar")
                jq --arg app "$APP" '.pinned -= [$app]' \
                    "$PIN_FILE" > "$PIN_FILE.tmp" && mv "$PIN_FILE.tmp" "$PIN_FILE"
                notify-send "Taskbar" "📌 Unpinned $APP"
                ;;
            
            "Focus Window")
                # Get first window of this app and focus it
                ADDR=$(hyprctl clients -j 2>/dev/null | jq -r --arg app "$APP" \
                    'map(select(.class == $app)) | .[0].address // ""')
                
                if [ -n "$ADDR" ]; then
                    hyprctl dispatch focuswindow address:$ADDR
                fi
                ;;
            
            "Close Window")
                # Close first window
                ADDR=$(hyprctl clients -j 2>/dev/null | jq -r --arg app "$APP" \
                    'map(select(.class == $app)) | .[0].address // ""')
                
                if [ -n "$ADDR" ]; then
                    hyprctl dispatch closewindow address:$ADDR
                fi
                ;;
            
            "Close All Windows of $APP")
                hyprctl clients -j 2>/dev/null | jq -r --arg app "$APP" \
                    'map(select(.class == $app)) | .[].address' | while read -r addr; do
                    hyprctl dispatch closewindow address:$addr
                done
                notify-send "Taskbar" "❌ Closed all $APP windows"
                ;;
        esac
        ;;
esac