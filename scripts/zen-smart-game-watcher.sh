#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-smart-game-watcher.sh v6.16.4.12.7 (Tachiagari)
# ────────────────────────────────────────────────────────────────
# Smart Gaming Detection daemon. Watches the process table for
# known game / launcher / runtime processes and fires Quickshell
# IPC calls to PowerProfileService.setGamingBoost(true/false) so
# the rest of the shell (PowerBadge in the bar, ControlPanel
# toggle, SettingsStateV2 persistence) all stays in sync.
#
# Spawned by SettingsStateV2 when `smartGamingDetect` flips true,
# killed when it flips false. The QML flag drives the lifecycle —
# this script just runs the detection loop and routes events.
#
# RELATIONSHIP TO zen-game-watcher.sh:
#   • zen-game-watcher.sh: tied to gpuMode = "auto-gaming". Calls
#     powerprofilesctl + hyprctl DIRECTLY. Bypasses QML state.
#   • zen-smart-game-watcher.sh (this one): independent of gpuMode.
#     Calls QML via IPC so the bar badge + saved state agree with
#     reality. Either can be active; both running together is wasteful
#     but not actively harmful (the second invocation will just emit
#     redundant boost-on calls, which the QML setGamingBoost handles
#     idempotently because it gates on `gamingBoostActive`).
#
# v6.16.4.12.7 (Tachiagari): introduced as part of decoupling the
# "smart auto-FPS" UX from the GPU mode picker. Mirrors the original
# zen-game-watcher.sh pgrep policy almost verbatim — we extend the
# game-pattern list slightly to cover modern launchers (Heroic, Bottles,
# RetroArch, PrismLauncher, ATLauncher, RPCS3, Yuzu/Citra forks).
# ════════════════════════════════════════════════════════════════

set -u

STATE_FILE="$HOME/.cache/zen-smart-game-watcher.state"
PID_FILE="$HOME/.cache/zen-smart-game-watcher.pid"
LOG_FILE="$HOME/.cache/zen-smart-game-watcher.log"

# Patterns matched via pgrep -f (full command line). Trailing space
# in some entries narrows matches that would otherwise hit unrelated
# processes (e.g. "wine " avoids matching "wineserver" in unrelated
# tools that may legitimately leave one running between sessions).
GAMING_PATTERNS=(
    "steam "
    "steamwebhelper"
    "Lutris"
    "lutris-wrapper"
    "heroic"
    "bottles"
    "minecraft"
    "PrismLauncher"
    "ATLauncher"
    "dolphin-emu"
    "cemu"
    "rpcs3"
    "yuzu"
    "ryujinx"
    "Ryujinx"
    "citra"
    "PCSX2"
    "duckstation"
    "ppsspp"
    "retroarch"
    "gamescope"
    "wine "
    "proton"
    "gamemoderun"
    "mangohud"
    "DXVK_HUD"   # DXVK env-var passthroughs from Steam/Lutris
)

# ── Helpers ──
log() {
    # Append to log file with timestamp; never block on log failure
    if [ -n "${LOG_FILE:-}" ]; then
        printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

is_gaming() {
    local pattern
    for pattern in "${GAMING_PATTERNS[@]}"; do
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Locate quickshell binary. We prefer `qs -c zen-shell` (matches the
# user's shell config invocation). Fall back to plain `quickshell`
# with -p ~/.config/quickshell/zen-shell if `qs` is unavailable.
qs_call() {
    local fn="$1"
    if command -v qs >/dev/null 2>&1; then
        qs -c zen-shell ipc call zen "$fn" >/dev/null 2>&1
    elif command -v quickshell >/dev/null 2>&1; then
        quickshell -p "$HOME/.config/quickshell/zen-shell" \
            ipc call zen "$fn" >/dev/null 2>&1
    else
        log "WARN: neither 'qs' nor 'quickshell' on PATH — IPC skipped"
        return 1
    fi
}

enable_boost() {
    log "Game detected — calling gameBoostOn"
    qs_call gameBoostOn
    echo "boost" > "$STATE_FILE"
}

disable_boost() {
    log "Games gone — calling gameBoostOff"
    qs_call gameBoostOff
    echo "idle" > "$STATE_FILE"
}

# ── Single-instance guard ──
# Avoids racing with a prior run that didn't shut down cleanly. We
# write our PID, check if the previous PID file (if any) belongs
# to a still-living watcher instance, and exit if it does.
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        log "Another watcher is already running (PID $OLD_PID) — exiting"
        exit 0
    fi
fi
echo "$$" > "$PID_FILE"

# Cleanup on any exit signal — also flips boost off so we don't
# leave the system stuck in performance mode if the daemon is
# killed mid-game.
cleanup() {
    log "Watcher exiting — flushing boost OFF if currently boosted"
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "boost" ]; then
        disable_boost
    fi
    rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

# ── Main loop ──
log "Smart Gaming Detection started (PID $$)"
echo "idle" > "$STATE_FILE"
PREV_STATE="idle"

while true; do
    if is_gaming; then
        CURRENT="boost"
    else
        CURRENT="idle"
    fi

    if [ "$CURRENT" = "boost" ] && [ "$PREV_STATE" != "boost" ]; then
        enable_boost
    elif [ "$CURRENT" = "idle" ] && [ "$PREV_STATE" = "boost" ]; then
        disable_boost
    fi

    PREV_STATE="$CURRENT"
    sleep 3
done
