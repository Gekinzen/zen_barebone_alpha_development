#!/usr/bin/env bash

# Close Rofi if already open
if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
fi

theme="$HOME/.config/rofi/switcher.rasi"

rofi_cmd() {
    rofi -dmenu -theme "$theme" -p "Themes"
}

run_rofi() {
    # 3 icons (buttons)
    echo -e "  \n  \n  " | rofi_cmd
}

chosen="$(run_rofi | tr -d '[:space:]')"

case "$chosen" in
    "") bash ~/.config/niriwarm/applyniriwarm.sh ;;      # Button 1
    "") bash ~/.config/niricold/applyniricold.sh ;;     # Button 2
    "") bash ~/.config/nirilight/applynirilight.sh ;;   # Button 3
esac

