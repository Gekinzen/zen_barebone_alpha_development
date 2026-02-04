#!/usr/bin/env bash

# Close Rofi if already open
if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
fi

theme="$HOME/.config/rofi/pw.rasi"

rofi_cmd() {
    rofi -dmenu -theme "$theme" -p "Power"
}

run_rofi() {
    echo -e "  \n  \n  " | rofi_cmd
}

# Actions
chosen="$(run_rofi | tr -d '[:space:]')"

case "$chosen" in
    "") /usr/bin/systemctl reboot ;;
    "") loginctl terminate-user "$USER" ;;
    "") /usr/bin/systemctl poweroff ;;
esac

