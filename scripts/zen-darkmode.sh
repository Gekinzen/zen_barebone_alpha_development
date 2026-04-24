#!/usr/bin/env bash
# zen-darkmode.sh — unified dark/light mode switcher
#
# Syncs:
#   - gsettings color-scheme preference (GNOME / libadwaita apps)
#   - gsettings gtk-theme name (Adwaita / Adwaita-dark for GTK3)
#   - Qt color scheme via XDG_CURRENT_DESKTOP hint + envvar
#   - Writes state to ~/.local/share/zen-shell/darkmode.state
#
# Usage:
#   zen-darkmode.sh dark
#   zen-darkmode.sh light
#   zen-darkmode.sh toggle
#   zen-darkmode.sh status    # prints current state to stdout

set -u

STATE_DIR="$HOME/.local/share/zen-shell"
STATE_FILE="$STATE_DIR/darkmode.state"
LOG="$HOME/.cache/zen-shell/darkmode.log"
mkdir -p "$STATE_DIR" "$(dirname "$LOG")"

# GTK themes to use — configurable via env
#   ZEN_GTK_DARK    (default: Adwaita-dark)
#   ZEN_GTK_LIGHT   (default: Adwaita)
#   ZEN_ICONS_DARK  (default: Adwaita)  (optional override)
#   ZEN_ICONS_LIGHT (default: Adwaita)
GTK_DARK="${ZEN_GTK_DARK:-Adwaita-dark}"
GTK_LIGHT="${ZEN_GTK_LIGHT:-Adwaita}"

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }

read_current_state() {
    if [ -r "$STATE_FILE" ]; then
        cat "$STATE_FILE" | tr -d '[:space:]'
    else
        # Default: infer from gsettings
        local scheme
        scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$scheme" == "prefer-dark" ]]; then
            echo "dark"
        else
            echo "light"
        fi
    fi
}

apply_gtk() {
    local mode="$1"
    local scheme gtktheme
    if [ "$mode" = "dark" ]; then
        scheme="prefer-dark"
        gtktheme="$GTK_DARK"
    else
        scheme="default"
        gtktheme="$GTK_LIGHT"
    fi

    # gsettings — covers libadwaita + GTK4 apps
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null \
            && log "color-scheme → $scheme"
        gsettings set org.gnome.desktop.interface gtk-theme "$gtktheme" 2>/dev/null \
            && log "gtk-theme → $gtktheme"
    fi

    # GTK3 settings.ini — persists across sessions, some older apps
    # don't respect gsettings
    local gtk3_dir="$HOME/.config/gtk-3.0"
    local gtk3_file="$gtk3_dir/settings.ini"
    mkdir -p "$gtk3_dir"
    if [ -f "$gtk3_file" ]; then
        # Update existing gtk-theme-name + add gtk-application-prefer-dark-theme
        if grep -q "^gtk-theme-name=" "$gtk3_file"; then
            sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$gtktheme|" "$gtk3_file"
        else
            # Ensure [Settings] header + append
            grep -q "^\[Settings\]" "$gtk3_file" || echo "[Settings]" >> "$gtk3_file"
            echo "gtk-theme-name=$gtktheme" >> "$gtk3_file"
        fi
        if grep -q "^gtk-application-prefer-dark-theme=" "$gtk3_file"; then
            sed -i "s|^gtk-application-prefer-dark-theme=.*|gtk-application-prefer-dark-theme=$( [ "$mode" = "dark" ] && echo 1 || echo 0 )|" "$gtk3_file"
        else
            echo "gtk-application-prefer-dark-theme=$( [ "$mode" = "dark" ] && echo 1 || echo 0 )" >> "$gtk3_file"
        fi
    else
        cat > "$gtk3_file" <<EOF
[Settings]
gtk-theme-name=$gtktheme
gtk-application-prefer-dark-theme=$( [ "$mode" = "dark" ] && echo 1 || echo 0 )
EOF
    fi
    log "GTK3 settings.ini updated"

    # GTK4 settings.ini — libadwaita respects gsettings color-scheme
    # but some GTK4 non-libadwaita apps still read this file
    local gtk4_dir="$HOME/.config/gtk-4.0"
    local gtk4_file="$gtk4_dir/settings.ini"
    mkdir -p "$gtk4_dir"
    cat > "$gtk4_file" <<EOF
[Settings]
gtk-theme-name=$gtktheme
gtk-application-prefer-dark-theme=$( [ "$mode" = "dark" ] && echo 1 || echo 0 )
EOF
    log "GTK4 settings.ini updated"
}

save_state() {
    echo "$1" > "$STATE_FILE"
    log "state saved: $1"
}

case "${1:-toggle}" in
    dark|light)
        apply_gtk "$1"
        save_state "$1"
        log "applied: $1"
        # Emit a desktop notification (optional, silent if notify-send absent)
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -t 1500 "Zen Shell" "Switched to $1 mode"
        fi
        echo "$1"
        ;;
    toggle)
        current=$(read_current_state)
        if [ "$current" = "dark" ]; then
            target="light"
        else
            target="dark"
        fi
        exec "$0" "$target"
        ;;
    status)
        read_current_state
        ;;
    *)
        echo "Usage: zen-darkmode.sh {dark|light|toggle|status}" >&2
        exit 1
        ;;
esac
