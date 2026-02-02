#!/bin/bash
#
# Pacman Updates Checker for Waybar
# Location: ~/.config/hypr-control-center/scripts/pacman-updates.sh
#

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/pacman-updates"
CACHE_FILE="$CACHE_DIR/updates.cache"
CACHE_TIMEOUT=600

mkdir -p "$CACHE_DIR"

cache_valid() {
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE")))
        [[ $cache_age -lt $CACHE_TIMEOUT ]]
    else
        return 1
    fi
}

get_pacman_updates() {
    checkupdates 2>/dev/null || echo ""
}

get_aur_updates() {
    if command -v yay &>/dev/null; then
        yay -Qua 2>/dev/null || echo ""
    elif command -v paru &>/dev/null; then
        paru -Qua 2>/dev/null || echo ""
    else
        echo ""
    fi
}

refresh_cache() {
    local pacman_updates=$(get_pacman_updates)
    local aur_updates=$(get_aur_updates)
    
    {
        echo "PACMAN:"
        echo "$pacman_updates"
        echo "AUR:"
        echo "$aur_updates"
    } > "$CACHE_FILE"
}

get_updates() {
    if ! cache_valid || [[ "$1" == "--refresh" ]]; then
        refresh_cache
    fi
    cat "$CACHE_FILE"
}

format_waybar() {
    local updates=$(get_updates "$1")
    
    local pacman_list=$(echo "$updates" | sed -n '/^PACMAN:/,/^AUR:/p' | grep -v "^PACMAN:" | grep -v "^AUR:" | grep -v "^$")
    local aur_list=$(echo "$updates" | sed -n '/^AUR:/,$p' | grep -v "^AUR:" | grep -v "^$")
    
    local pacman_count=0
    local aur_count=0
    
    if [[ -n "$pacman_list" ]]; then
        pacman_count=$(echo "$pacman_list" | wc -l)
    fi
    
    if [[ -n "$aur_list" ]]; then
        aur_count=$(echo "$aur_list" | wc -l)
    fi
    
    local total_count=$((pacman_count + aur_count))
    
    # Colors
    local green="#98c379"
    local blue="#61afef"
    local yellow="#e5c07b"
    local red="#e06c75"
    local cyan="#56b6c2"
    local magenta="#c678dd"
    local gray="#5c6370"
    
    # Build detailed tooltip with Pango markup
    local tooltip=""
    
    if [[ $pacman_count -gt 0 ]]; then
        tooltip+="<span color='$blue' font_weight='bold'>󰮯 Official Repos ($pacman_count)</span>\n"
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local pkg=$(echo "$line" | awk '{print $1}')
                local old_ver=$(echo "$line" | awk '{print $2}')
                local new_ver=$(echo "$line" | awk '{print $4}')
                tooltip+="<span color='$cyan'>  $pkg</span>\n"
                tooltip+="<span color='$gray'>    $old_ver</span> <span color='$green'>→ $new_ver</span>\n"
            fi
        done <<< "$pacman_list"
    fi
    
    if [[ $aur_count -gt 0 ]]; then
        if [[ -n "$tooltip" ]]; then
            tooltip+="\n"
        fi
        tooltip+="<span color='$magenta' font_weight='bold'>󱓞 AUR ($aur_count)</span>\n"
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local pkg=$(echo "$line" | awk '{print $1}')
                local old_ver=$(echo "$line" | awk '{print $2}')
                local new_ver=$(echo "$line" | awk '{print $4}')
                tooltip+="<span color='$cyan'>  $pkg</span>\n"
                tooltip+="<span color='$gray'>    $old_ver</span> <span color='$green'>→ $new_ver</span>\n"
            fi
        done <<< "$aur_list"
    fi
    
    if [[ -z "$tooltip" ]]; then
        tooltip="<span color='$green' font_weight='bold'>✓ System is up to date</span>"
    else
        tooltip+="\n<span color='$yellow'>󰑓 Click to update</span>\n<span color='$gray'>󰜉 Right-click to refresh</span>"
    fi
    
    # Escape for JSON but preserve Pango tags
    tooltip=$(echo -e "$tooltip" | sed ':a;N;$!ba;s/\n/\\n/g' | sed "s/'/\\\\u0027/g")
    
    local class="updated"
    if [[ $total_count -gt 50 ]]; then
        class="critical"
    elif [[ $total_count -gt 20 ]]; then
        class="warning"
    elif [[ $total_count -gt 0 ]]; then
        class="pending"
    fi
    
    printf '{"text": "%s", "tooltip": "%s", "class": "%s", "alt": "%s"}\n' "$total_count" "$tooltip" "$class" "$class"
}

run_update() {
    local terminal="${TERMINAL:-kitty}"
    
    if command -v yay &>/dev/null; then
        $terminal -e bash -c "yay -Syu; echo ''; echo 'Press any key to close...'; read -n 1"
    elif command -v paru &>/dev/null; then
        $terminal -e bash -c "paru -Syu; echo ''; echo 'Press any key to close...'; read -n 1"
    else
        $terminal -e bash -c "sudo pacman -Syu; echo ''; echo 'Press any key to close...'; read -n 1"
    fi
    
    sleep 2
    refresh_cache
}

case "$1" in
    --refresh|-r)
        format_waybar "--refresh"
        ;;
    --update|-u)
        run_update
        ;;
    --count|-c)
        updates=$(get_updates)
        pacman_list=$(echo "$updates" | sed -n '/^PACMAN:/,/^AUR:/p' | grep -v "^PACMAN:" | grep -v "^AUR:" | grep -v "^$")
        aur_list=$(echo "$updates" | sed -n '/^AUR:/,$p' | grep -v "^AUR:" | grep -v "^$")
        pacman_count=0
        aur_count=0
        [[ -n "$pacman_list" ]] && pacman_count=$(echo "$pacman_list" | wc -l)
        [[ -n "$aur_list" ]] && aur_count=$(echo "$aur_list" | wc -l)
        echo $((pacman_count + aur_count))
        ;;
    --list|-l)
        get_updates | grep -v "^PACMAN:" | grep -v "^AUR:" | grep -v "^$"
        ;;
    *)
        format_waybar
        ;;
esac