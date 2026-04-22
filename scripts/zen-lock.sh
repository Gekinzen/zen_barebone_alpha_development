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

# ── Step 3: Launch hyprlock (idempotent) ──
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
