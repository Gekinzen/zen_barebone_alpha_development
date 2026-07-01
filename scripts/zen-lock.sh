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

# ── Step 3.5: Sync accent colors from active theme (hf98c) ──
#
# Makes the lock screen's power buttons follow the live theme. We read
# the active palette from current-theme.json (the same file ThemeService
# writes) and rewrite every hyprlock.conf color line tagged with a
#   # ZEN_COLOR_OVERRIDE:<key>:<alpha>
# marker to rgba(<themehex><alpha>). hyprlock accepts 8-digit hex colors
# (RRGGBBAA), so we just splice the theme hex + the alpha byte from the
# marker. Lines without the marker (clock, weather, input field) are left
# exactly as-is — design unchanged, only the tagged accents re-theme.
#
# Requires gawk (the 3-arg match() with capture groups). Arch/CachyOS
# ship gawk as `awk` by default. If absent, this step no-ops and the
# fallback colors baked into hyprlock.conf are used.
THEME_JSON="$HOME/.config/hypr-control-center/current-theme.json"
if [ -f "$THEME_JSON" ] && [ -f "$HYPRLOCK_CONF" ] && command -v jq >/dev/null 2>&1; then
    COLOR_KV=$(jq -r '.colors | to_entries[] | "\(.key)=\(.value)"' "$THEME_JSON" 2>/dev/null \
               | tr -d '#' | paste -sd';' -)
    if [ -n "$COLOR_KV" ]; then
        awk -v kv="$COLOR_KV" '
            BEGIN {
                n = split(kv, a, ";")
                for (i = 1; i <= n; i++) { split(a[i], b, "="); col[b[1]] = b[2] }
            }
            {
                p = index($0, "# ZEN_COLOR_OVERRIDE:")
                if (p > 0) {
                    nf = split(substr($0, p), parts, ":")   # [# ZEN_COLOR_OVERRIDE][key][alpha...]
                    if (nf >= 3) {
                        key   = parts[2]
                        alpha = substr(parts[3], 1, 2)
                        hex   = col[key]
                        eq = index($0, "=")
                        hp = index($0, "#")
                        if (hex != "" && eq > 0 && hp > eq) {
                            $0 = substr($0, 1, eq) " rgba(" hex alpha ")  " substr($0, hp)
                        }
                    }
                }
                print
            }
        ' "$HYPRLOCK_CONF" > "$HYPRLOCK_CONF.ztmp" 2>/dev/null \
            && mv "$HYPRLOCK_CONF.ztmp" "$HYPRLOCK_CONF" \
            && log "theme colors synced from $(basename "$THEME_JSON")"
    fi
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
