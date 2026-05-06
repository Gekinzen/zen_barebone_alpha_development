#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════
# zen-darkmode.sh — GTK3 / GTK4 / libadwaita dark-mode switcher
# Part of Zen Shell v6.16.4.12.9.8 (Modori)
#
# Synchronizes the dark/light theme state across all four places
# GTK applications look for it:
#
#   1. gsettings org.gnome.desktop.interface color-scheme
#      → libadwaita / GTK4 apps. Values: "prefer-dark" or "default".
#
#   2. gsettings org.gnome.desktop.interface gtk-theme
#      → legacy GTK3 apps that read gsettings.
#      Values: "$ZEN_GTK_DARK" or "$ZEN_GTK_LIGHT" env vars
#      (default Adwaita-dark / Adwaita).
#
#   3. ~/.config/gtk-3.0/settings.ini
#      → some GTK3 apps that DON'T read gsettings (e.g. Thunar with
#      certain themes). Set gtk-application-prefer-dark-theme=1/0
#      and gtk-theme-name.
#
#   4. ~/.config/gtk-4.0/settings.ini
#      → same fallback pattern for GTK4 apps that bypass gsettings.
#
# Plus persists the choice to ~/.local/share/zen-shell/darkmode.state
# so the next shell launch can read it back without re-querying
# gsettings (faster startup, also the source of truth).
#
# Usage:
#   zen-darkmode.sh dark    # → switch to dark
#   zen-darkmode.sh light   # → switch to light
#   zen-darkmode.sh toggle  # → flip whatever is currently set
#   zen-darkmode.sh state   # → echo "dark" or "light" (read state)
#
# Override default GTK theme names via env:
#   ZEN_GTK_DARK=Adwaita-dark   ZEN_GTK_LIGHT=Adwaita
# ═════════════════════════════════════════════════════════════════════

set -uo pipefail

ZEN_STATE_DIR="${HOME}/.local/share/zen-shell"
ZEN_STATE_FILE="${ZEN_STATE_DIR}/darkmode.state"
ZEN_LOG="${HOME}/.cache/zen-shell/darkmode.log"
ZEN_GTK_DARK="${ZEN_GTK_DARK:-Adwaita-dark}"
ZEN_GTK_LIGHT="${ZEN_GTK_LIGHT:-Adwaita}"

mkdir -p "${ZEN_STATE_DIR}" "$(dirname "${ZEN_LOG}")"

_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" >> "${ZEN_LOG}"
}

# Read current state from the state file, fall back to gsettings,
# fall back to "light" if neither answer.
_read_state() {
    if [ -f "${ZEN_STATE_FILE}" ]; then
        local s
        s=$(<"${ZEN_STATE_FILE}")
        if [ "$s" = "dark" ] || [ "$s" = "light" ]; then
            echo "$s"
            return
        fi
    fi
    if command -v gsettings >/dev/null 2>&1; then
        local cs
        cs=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null \
             | tr -d "'")
        case "$cs" in
            prefer-dark) echo "dark" ;;
            *)           echo "light" ;;
        esac
        return
    fi
    echo "light"
}

# Update ~/.config/gtk-3.0/settings.ini — preserve every other key,
# only touch gtk-theme-name + gtk-application-prefer-dark-theme.
_update_gtk_ini() {
    local ini_dir="$1"      # gtk-3.0 or gtk-4.0
    local theme_name="$2"
    local prefer_dark="$3"  # 0 or 1

    local dir="${HOME}/.config/${ini_dir}"
    local ini="${dir}/settings.ini"
    mkdir -p "${dir}"

    if [ ! -f "${ini}" ]; then
        cat > "${ini}" <<EOF
[Settings]
gtk-theme-name=${theme_name}
gtk-application-prefer-dark-theme=${prefer_dark}
EOF
        _log "wrote new ${ini}"
        return
    fi

    # Make sure the file has a [Settings] header
    if ! grep -q "^\[Settings\]" "${ini}"; then
        # Prepend the section
        local tmp
        tmp=$(mktemp)
        echo "[Settings]" > "${tmp}"
        cat "${ini}" >> "${tmp}"
        mv "${tmp}" "${ini}"
    fi

    # Update or insert each key. We use a portable awk approach
    # because sed -i with multi-pattern updates gets messy across
    # GNU/BSD differences.
    awk -v t="${theme_name}" -v d="${prefer_dark}" '
        BEGIN { in_settings=0; saw_theme=0; saw_dark=0 }
        /^\[Settings\]/ {
            print
            in_settings=1
            next
        }
        /^\[/ {
            if (in_settings) {
                if (!saw_theme) print "gtk-theme-name=" t
                if (!saw_dark)  print "gtk-application-prefer-dark-theme=" d
                in_settings=0
            }
            print
            next
        }
        in_settings && /^[[:space:]]*gtk-theme-name[[:space:]]*=/ {
            print "gtk-theme-name=" t
            saw_theme=1
            next
        }
        in_settings && /^[[:space:]]*gtk-application-prefer-dark-theme[[:space:]]*=/ {
            print "gtk-application-prefer-dark-theme=" d
            saw_dark=1
            next
        }
        { print }
        END {
            if (in_settings) {
                if (!saw_theme) print "gtk-theme-name=" t
                if (!saw_dark)  print "gtk-application-prefer-dark-theme=" d
            }
        }
    ' "${ini}" > "${ini}.tmp" && mv "${ini}.tmp" "${ini}"

    _log "updated ${ini}"
}

_apply() {
    local mode="$1"   # dark or light
    local theme prefer cs

    if [ "$mode" = "dark" ]; then
        theme="${ZEN_GTK_DARK}"
        prefer=1
        cs="prefer-dark"
    else
        theme="${ZEN_GTK_LIGHT}"
        prefer=0
        cs="default"
    fi

    _log "applying ${mode} (theme=${theme} prefer-dark=${prefer})"

    # 1. + 2. gsettings — non-fatal if gsettings unavailable
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme "${cs}" \
            >>"${ZEN_LOG}" 2>&1 || _log "gsettings color-scheme failed (non-fatal)"
        gsettings set org.gnome.desktop.interface gtk-theme "${theme}" \
            >>"${ZEN_LOG}" 2>&1 || _log "gsettings gtk-theme failed (non-fatal)"
    else
        _log "gsettings not available — skipping gsettings sync"
    fi

    # 3. + 4. settings.ini fallbacks
    _update_gtk_ini "gtk-3.0" "${theme}" "${prefer}"
    _update_gtk_ini "gtk-4.0" "${theme}" "${prefer}"

    # Persist state
    echo "${mode}" > "${ZEN_STATE_FILE}"
    _log "state persisted to ${ZEN_STATE_FILE}"
}

# ─────────────────────────────────────────────────────────────────
# Entry
# ─────────────────────────────────────────────────────────────────
ACTION="${1:-state}"

case "${ACTION}" in
    dark)
        _apply dark
        echo "dark"
        ;;
    light)
        _apply light
        echo "light"
        ;;
    toggle)
        cur=$(_read_state)
        if [ "$cur" = "dark" ]; then
            _apply light
            echo "light"
        else
            _apply dark
            echo "dark"
        fi
        ;;
    state)
        _read_state
        ;;
    *)
        echo "Usage: $0 {dark|light|toggle|state}" >&2
        exit 2
        ;;
esac
