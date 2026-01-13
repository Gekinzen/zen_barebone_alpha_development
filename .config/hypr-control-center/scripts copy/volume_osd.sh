#!/bin/bash
# Volume OSD with notifications

ACTION="$1"

get_volume() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'
}

get_mute_status() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "MUTED" && echo "true" || echo "false"
}

case "$ACTION" in
    up)
        # Volume up 5%
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
        VOLUME=$(get_volume)
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:volume -h int:value:$VOLUME "󰕾 Volume" "$VOLUME%"
        ;;
    down)
        # Volume down 5%
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        VOLUME=$(get_volume)
        notify-send -u low -t 1500 -h string:x-canonical-private-synchronous:volume -h int:value:$VOLUME "󰕾 Volume" "$VOLUME%"
        ;;
    mute)
        # Toggle mute
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