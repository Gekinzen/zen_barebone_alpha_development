#!/usr/bin/env bash
# Taskbar renderer - Nerd Fonts with spacing and count

TASKBAR_JSON="$HOME/.config/hypr-control-center/preferences/taskbar.json"
WAYBAR_MENU_JSON="$HOME/.config/hypr-control-center/preferences/waybar-menu.json"

# Ensure files exist
mkdir -p "$(dirname "$TASKBAR_JSON")"
[ ! -f "$TASKBAR_JSON" ] && echo '{"pinned":[]}' > "$TASKBAR_JSON"
[ ! -f "$WAYBAR_MENU_JSON" ] && echo '{"style_mode":"minimal"}' > "$WAYBAR_MENU_JSON"

# Get pinned apps
PINNED_APPS=$(jq -r '.pinned[]?' "$TASKBAR_JSON" 2>/dev/null)

# Get running apps with window count - with error handling
RUNNING_APPS=$(hyprctl clients -j 2>/dev/null | jq -r 'group_by(.class) | map({app: .[0].class, count: length, titles: [.[].title]}) | .[]' 2>/dev/null | jq -c . 2>/dev/null)

# Exit gracefully if no data
if [ -z "$RUNNING_APPS" ]; then
    echo '{"text":"","tooltip":"No windows","class":"taskbar"}'
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# ICON MAPPING (Nerd Fonts)
# ═══════════════════════════════════════════════════════════════

get_icon() {
    local app="$1"
    local app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    
    case "$app_lower" in
        *firefox*|*mozilla*) echo "󰈹" ;;
        *chrome*|*chromium*) echo "󰊯" ;;
        *brave*) echo "󰊯" ;;
        *code*|*vscode*|*vscodium*) echo "󰨞" ;;
        *kitty*) echo "󰆍" ;;
        *alacritty*) echo "" ;;
        *wezterm*) echo "" ;;
        *terminal*|*konsole*) echo "" ;;
        *thunar*|*nautilus*|*dolphin*|*pcmanfm*) echo "󰝰" ;;
        *discord*) echo "󰙯" ;;
        *telegram*) echo "󰚩" ;;
        *signal*) echo "󰍡" ;;
        *spotify*) echo "󰓇" ;;
        *vlc*) echo "󰕼" ;;
        *mpv*) echo "" ;;
        *gimp*) echo "󰏘" ;;
        *inkscape*) echo "󰕉" ;;
        *blender*) echo "󰂫" ;;
        *obs*) echo "󰑋" ;;
        *steam*) echo "󰓓" ;;
        *lutris*) echo "󰺵" ;;
        *gamemode*) echo "󰊗" ;;
        *libreoffice*|*writer*) echo "󰈙" ;;
        *calc*) echo "󱎏" ;;
        *impress*) echo "󰐩" ;;
        *thunderbird*|*mail*) echo "󰇰" ;;
        *btop*|*htop*|*gotop*) echo "" ;;
        *vim*|*nvim*|*neovim*) echo "" ;;
        *emacs*) echo "" ;;
        *sublime*) echo "" ;;
        *atom*) echo "" ;;
        *ranger*|*nnn*|*lf*) echo "󰴉" ;;
        *transmission*|*qbittorrent*) echo "󰶘" ;;
        *pavucontrol*|*pulsemixer*) echo "󰕾" ;;
        *blueman*) echo "󰂯" ;;
        *nm-applet*|*network*) echo "󰖩" ;;
        *bitwarden*|*keepass*) echo "󰌾" ;;
        *1password*) echo "󰷝" ;;
        *eog*|*gwenview*|*feh*) echo "󰋩" ;;
        *zathura*|*evince*|*okular*) echo "󰈦" ;;
        *minecraft*) echo "󰍳" ;;
        *zoom*) echo "󰍫" ;;
        *slack*) echo "󰒱" ;;
        *teams*) echo "󰊻" ;;
        *notion*) echo "󰎚" ;;
        *obsidian*) echo "󰠮" ;;
        *virt-manager*|*virtualbox*) echo "󰨪" ;;
        *docker*) echo "󰡨" ;;
        *postman*|*insomnia*) echo "󰘯" ;;
        *dbeaver*|*mysql*|*postgres*) echo "󰆼" ;;
        *) echo "󰣆" ;;  # Default generic icon
    esac
}

# ═══════════════════════════════════════════════════════════════
# BUILD TASKBAR OUTPUT - RUNNING APPS ONLY
# ═══════════════════════════════════════════════════════════════

TASKBAR_TEXT=""
TOOLTIP_TEXT=""

# Process running apps with grouping
while IFS= read -r window_data; do
    [ -z "$window_data" ] && continue
    
    APP=$(echo "$window_data" | jq -r '.app // empty' 2>/dev/null)
    [ -z "$APP" ] && continue
    
    COUNT=$(echo "$window_data" | jq -r '.count // 1' 2>/dev/null)
    TITLES=$(echo "$window_data" | jq -r '.titles[]? // empty' 2>/dev/null)
    
    ICON=$(get_icon "$APP")
    
    # Show icon with count if multiple windows
    if [ "$COUNT" -gt 1 ]; then
        TASKBAR_TEXT="${TASKBAR_TEXT}${ICON}(${COUNT})  "
    else
        TASKBAR_TEXT="${TASKBAR_TEXT}${ICON}  "
    fi
    
    # Build tooltip
    if [ "$COUNT" -gt 1 ]; then
        TOOLTIP_TEXT="${TOOLTIP_TEXT}${APP} (${COUNT} windows):\n"
        while IFS= read -r title; do
            [ -z "$title" ] && continue
            # Truncate long titles
            if [ ${#title} -gt 50 ]; then
                title="${title:0:50}..."
            fi
            # Escape special characters for Pango markup
            title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&apos;/g')
            TOOLTIP_TEXT="${TOOLTIP_TEXT}  • ${title}\n"
        done <<< "$TITLES"
    else
        # Single window
        TITLE=$(echo "$TITLES" | head -n1)
        [ -n "$TITLE" ] && {
            if [ ${#TITLE} -gt 50 ]; then
                TITLE="${TITLE:0:50}..."
            fi
            # Escape special characters for Pango markup
            TITLE=$(echo "$TITLE" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&apos;/g')
            TOOLTIP_TEXT="${TOOLTIP_TEXT}${APP}: ${TITLE}\n"
        }
    fi
    
    TOOLTIP_TEXT="${TOOLTIP_TEXT}\n"
done <<< "$RUNNING_APPS"

# Remove trailing spaces and newlines
TASKBAR_TEXT=$(echo "$TASKBAR_TEXT" | sed 's/[[:space:]]*$//')
TOOLTIP_TEXT=$(echo "$TOOLTIP_TEXT" | sed 's/\\n$//')

# Fallback if empty
[ -z "$TASKBAR_TEXT" ] && TASKBAR_TEXT="󰍹"
[ -z "$TOOLTIP_TEXT" ] && TOOLTIP_TEXT="No active windows"

# Output JSON for Waybar - with proper escaping
printf '{"text":"%s","tooltip":"%s","class":"taskbar"}\n' "$TASKBAR_TEXT" "$TOOLTIP_TEXT"