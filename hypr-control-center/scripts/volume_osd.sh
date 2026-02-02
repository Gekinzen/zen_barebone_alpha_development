#!/bin/bash
# Volume OSD with notifications - limited to 100%
ACTION="$1"

get_volume() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'
}

get_mute_status() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "MUTED" && echo "true" || echo "false"
}

case "$ACTION" in
    up)
        # Check current volume first
        CURRENT=$(get_volume)
        if [ "$CURRENT" -lt 100 ]; then
            wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        fi
        VOLUME=$(get_volume)
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:volume -h int:value:$VOLUME "󰕾 Volume" "$VOLUME%"
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        VOLUME=$(get_volume)
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:volume -h int:value:$VOLUME "󰕾 Volume" "$VOLUME%"
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        MUTED=$(get_mute_status)
        if [ "$MUTED" = "true" ]; then
            notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:volume "󰖁 Volume" "Muted"
        else
            VOLUME=$(get_volume)
            notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:volume -h int:value:$VOLUME "󰕾 Volume" "$VOLUME%"
        fi
        ;;
    *)
        echo "Usage: $0 {up|down|mute}"
        exit 1
        ;;
esac