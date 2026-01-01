#!/usr/bin/env bash

APP_ID="$1"
[ -z "$APP_ID" ] && exit 0

ACTIVE_CLASS="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')"

# Get icon
get_icon() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        *firefox*) echo "" ;;
        *code*) echo "󰨞" ;;
        *kitty*|*alacritty*|*foot*) echo "" ;;
        *thunar*|*nautilus*|*dolphin*) echo "󰝰" ;;
        *spotify*) echo "" ;;
        *chromium*|*chrome*) echo "" ;;
        *brave*) echo "󰖟" ;;
        *discord*) echo "󰙯" ;;
        *telegram*) echo "" ;;
        *vlc*|*mpv*) echo "󰕼" ;;
        *obs*) echo "󰑋" ;;
        *gimp*) echo "" ;;
        *) echo "󰣆" ;;
    esac
}

# Get app info
INFO=$(hyprctl clients -j 2>/dev/null | jq -c --arg app "$APP_ID" --arg active "$ACTIVE_CLASS" '
  [.[] | select(.class == $app)]
  | {
      count: length,
      active: (map(select(.class == $active)) | length > 0),
      titles: map(.title)
    }
')

COUNT=$(echo "$INFO" | jq -r '.count')
IS_ACTIVE=$(echo "$INFO" | jq -r '.active')
TITLES=$(echo "$INFO" | jq -r '.titles | join("\n• ")')

[ "$COUNT" -eq 0 ] && exit 0

ICON=$(get_icon "$APP_ID")
DISPLAY="$ICON"
[ "$COUNT" -gt 1 ] && DISPLAY="$DISPLAY ($COUNT)"

CLASS="taskbar-btn"
[ "$IS_ACTIVE" = "true" ] && CLASS="$CLASS active"

TOOLTIP="$APP_ID ($COUNT window"
[ "$COUNT" -gt 1 ] && TOOLTIP="${TOOLTIP}s"
TOOLTIP="$TOOLTIP)"
[ -n "$TITLES" ] && TOOLTIP="$TOOLTIP\n• $TITLES"

jq -n \
  --arg text "$DISPLAY" \
  --arg tooltip "$TOOLTIP" \
  --arg class "$CLASS" \
  '{text: $text, tooltip: $tooltip, class: $class}'