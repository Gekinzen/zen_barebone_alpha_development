#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-lock.sh v6.16.3.2.1 — Lock launcher with live wallpaper sync
# ────────────────────────────────────────────────────────────────
# Bridges the gap between Zen Shell's wallpaper picker
# (WallpaperServiceV5 → ~/.config/quickshell/zen-shell/wallpaper-v5.json)
# and hyprlock's static `path =` background field.
#
# Flow:
#   1. Read .currentWallpaper from wallpaper-v5.json
#   2. Symlink that file to ~/.cache/zen-shell/lock-wallpaper.png
#   3. hyprlock.conf reads path = $HOME/.cache/zen-shell/lock-wallpaper.png
#      → background == current desktop wallpaper, every lock
#
# Fallbacks (in order):
#   - wallpaper-v5.json missing / empty → keep existing symlink
#   - existing symlink also missing → grim screenshot fallback
#   - grim missing → no background (hyprlock falls back to flat color)
#
# Used by:
#   - hypridle.conf            → lock_cmd = ~/.local/bin/zen-lock.sh
#   - zen-lid-handler.sh       → lock_screen() (smart mode close)
#   - StartMenuPanel.qml lock  → see PowerConfirmDialog command param
#
# Idempotent:
#   - If hyprlock is already running, returns 0 immediately (don't
#     stack lock screens).
#   - Symlink update is unconditional but cheap.
# ════════════════════════════════════════════════════════════════

set -u

CACHE_DIR="$HOME/.cache/zen-shell"
LOCK_BG="$CACHE_DIR/lock-wallpaper.png"
WP_STATE="$HOME/.config/quickshell/zen-shell/wallpaper-v5.json"
LOG_FILE="$CACHE_DIR/lock.log"

mkdir -p "$CACHE_DIR" 2>/dev/null

log() {
    local ts="$(date +'%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" >>"$LOG_FILE" 2>/dev/null
    if [ -f "$LOG_FILE" ] && [ "$(wc -l <"$LOG_FILE" 2>/dev/null || echo 0)" -gt 100 ]; then
        tail -80 "$LOG_FILE" >"$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
    fi
}

# ── Step 1: Determine current wallpaper ──
CURRENT_WP=""
if command -v jq >/dev/null 2>&1 && [ -f "$WP_STATE" ]; then
    CURRENT_WP=$(jq -r '.currentWallpaper // empty' "$WP_STATE" 2>/dev/null)
fi

# ── Step 2: Update lock background symlink ──
if [ -n "$CURRENT_WP" ] && [ -f "$CURRENT_WP" ]; then
    # Resolve to absolute path so the symlink survives $HOME resolution
    case "$CURRENT_WP" in
        /*) ABS_WP="$CURRENT_WP" ;;
        *)  ABS_WP="$(cd "$(dirname "$CURRENT_WP")" 2>/dev/null && pwd)/$(basename "$CURRENT_WP")" ;;
    esac
    ln -sfn "$ABS_WP" "$LOCK_BG" 2>/dev/null
    log "wallpaper synced: $ABS_WP"
elif [ ! -e "$LOCK_BG" ]; then
    # No saved wallpaper AND no existing symlink — fall back to a
    # screenshot so hyprlock has SOMETHING to render.
    if command -v grim >/dev/null 2>&1; then
        grim "$LOCK_BG" 2>/dev/null && log "fallback: grim screenshot → $LOCK_BG"
    else
        log "no wallpaper / no grim — hyprlock will use flat color"
    fi
else
    log "wallpaper unchanged (using existing $LOCK_BG)"
fi

# ── Step 3: Sync clock font from PanelState (v6.16.3.6) ──
#
# The lock screen's big centered clock uses whatever font the user
# picked in Settings → Bar Modules → Font family. We read the
# fontFamilyId from panel-state.json and rewrite the font_family
# line on hyprlock.conf labels tagged with  # ZEN_FONT_OVERRIDE.
#
# If the user wants to hand-pick a lock font (outside Zen Shell's
# font library), they just remove the  # ZEN_FONT_OVERRIDE  comment
# trailer from the relevant line and zen-lock.sh leaves it alone.
PANEL_STATE="$HOME/.local/share/quickshell/zen-shell/panel-state.json"
HYPRLOCK_CONF="$HOME/.config/hypr/hyprlock.conf"

if [ -f "$PANEL_STATE" ] && [ -f "$HYPRLOCK_CONF" ] && command -v jq >/dev/null 2>&1; then
    FONT_ID=$(jq -r '.fontFamilyId // "adwaita"' "$PANEL_STATE" 2>/dev/null)
    # v6.16.3.6.1: CLOCK_FONT now uses Black/Heavy/Bold weight variants
    # to match the desktop ZenWidget clock (which renders Adwaita Sans
    # with Font.Black / weight 900). Previously mapped to "Adwaita
    # Sans Light" which gave a thin elegant look but didn't match the
    # chunky widget clock Paul references as the system baseline.
    #
    # Weight variant picked per font:
    #   - Sans/proportional → Black or ExtraBold (where available)
    #   - Mono Nerd fonts    → Bold (most mono fonts don't ship Black)
    case "$FONT_ID" in
        adwaita)   CLOCK_FONT="Adwaita Sans Black";            MSG_FONT="Adwaita Sans" ;;
        jetbrains) CLOCK_FONT="JetBrainsMono Nerd Font Bold";  MSG_FONT="JetBrainsMono Nerd Font Propo" ;;
        geist)     CLOCK_FONT="GeistMono Nerd Font Mono Bold"; MSG_FONT="GeistMono Nerd Font Mono" ;;
        firacode)  CLOCK_FONT="FiraCode Nerd Font Bold";       MSG_FONT="FiraCode Nerd Font" ;;
        caskaydia) CLOCK_FONT="CaskaydiaCove Nerd Font Bold";  MSG_FONT="CaskaydiaCove Nerd Font" ;;
        iosevka)   CLOCK_FONT="Iosevka Nerd Font Heavy";       MSG_FONT="Iosevka Nerd Font" ;;
        hack)      CLOCK_FONT="Hack Nerd Font Bold";           MSG_FONT="Hack Nerd Font" ;;
        ubuntu)    CLOCK_FONT="UbuntuMono Nerd Font Bold";     MSG_FONT="UbuntuMono Nerd Font" ;;
        sfpro)     CLOCK_FONT="SF Pro Display Black";          MSG_FONT="SF Pro Text" ;;
        inter)     CLOCK_FONT="Inter Black";                   MSG_FONT="Inter" ;;
        *)         CLOCK_FONT="Adwaita Sans Black";            MSG_FONT="Adwaita Sans" ;;
    esac

    # sed replaces the value on lines tagged with the override marker
    # only. User's unmarked font_family lines stay untouched.
    sed -i -E "s|^(\s*font_family\s*=\s*)[^#]*(\s*# ZEN_FONT_OVERRIDE_CLOCK.*)$|\1${CLOCK_FONT}    \2|" "$HYPRLOCK_CONF" 2>/dev/null
    sed -i -E "s|^(\s*font_family\s*=\s*)[^#]*(\s*# ZEN_FONT_OVERRIDE_MSG.*)$|\1${MSG_FONT}    \2|" "$HYPRLOCK_CONF" 2>/dev/null
    log "fonts synced: clock=${CLOCK_FONT}  msg=${MSG_FONT}  (fontFamilyId=${FONT_ID})"
fi

# ── Step 4: Launch hyprlock (idempotent) ──
if pgrep -x hyprlock >/dev/null 2>&1; then
    log "hyprlock already running — exit 0"
    exit 0
fi

if ! command -v hyprlock >/dev/null 2>&1; then
    # Last-ditch fallback: try swaylock, then DPMS off
    if command -v swaylock >/dev/null 2>&1; then
        log "hyprlock missing, falling back to swaylock"
        exec swaylock -f -i "$LOCK_BG"
    fi
    log "no lock binary available — DPMS off only"
    hyprctl dispatch dpms off >/dev/null 2>&1
    exit 0
fi

log "launching hyprlock"
exec hyprlock
