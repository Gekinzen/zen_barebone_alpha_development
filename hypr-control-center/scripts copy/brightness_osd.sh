#!/bin/bash
# Brightness OSD with notifications

ACTION="$1"

get_brightness() {
    brightnessctl get
}

get_max_brightness() {
    brightnessctl max
}

get_brightness_percent() {
    CURRENT=$(get_brightness)
    MAX=$(get_max_brightness)
    echo $((CURRENT * 100 / MAX))
}

case "$ACTION" in
    up)
        # Brightness up 5%
        brightnessctl set 5%+
        PERCENT=$(get_brightness_percent)
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:brightness -h int:value:$PERCENT "󰃠 Brightness" "$PERCENT%"
        ;;
    down)
        # Brightness down 5%
        brightnessctl set 5%-
        PERCENT=$(get_brightness_percent)
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:brightness -h int:value:$PERCENT "󰃠 Brightness" "$PERCENT%"
        ;;
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
esac