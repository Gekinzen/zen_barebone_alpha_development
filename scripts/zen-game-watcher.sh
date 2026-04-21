#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-game-watcher.sh v6.16.1
# ────────────────────────────────────────────────────────────────
# Background daemon that watches for gaming processes and triggers
# Performance profile + dGPU mode when one is detected. Restores
# previous state when all games exit.
#
# Started by GPUSwitcherService.qml when mode is set to "auto-gaming".
# Killed when mode changes to any other value.
#
# Patterns matched via pgrep -f (full command line):
#   steam steamwebhelper Lutris heroic minecraft dolphin-emu cemu
#   rpcs3 gamescope wine proton gamemoderun
#
# State transitions:
#   no-games → game-detected:
#     - powerprofilesctl set performance
#     - hyprctl disable blur + dim_inactive + animations
#     - Emit swaync notification 🎮
#   game-detected → no-games:
#     - Restore profile from ~/.cache/zen-gpu-prev-profile
#     - Restore blur/dim/animations from SettingsStateV2
#     - Emit swaync notification
#
# Check interval: 3 seconds (balance between responsiveness and CPU).
# ════════════════════════════════════════════════════════════════

set -u

STATE_FILE="$HOME/.cache/zen-game-watcher.state"
PREV_PROFILE_FILE="$HOME/.cache/zen-gpu-prev-profile"
SETTINGS_JSON="$HOME/.config/quickshell/zen-shell/settings-state-v2.json"

GAMING_PATTERNS=(
    "steam "
    "steamwebhelper"
    "Lutris"
    "heroic"
    "minecraft"
    "dolphin-emu"
    "cemu"
    "rpcs3"
    "gamescope"
    "wine "
    "proton"
    "gamemoderun"
)

# ── Helpers ──
is_gaming() {
    local pattern
    for pattern in "${GAMING_PATTERNS[@]}"; do
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

get_current_profile() {
    command -v powerprofilesctl >/dev/null 2>&1 || { echo "balanced"; return; }
    powerprofilesctl get 2>/dev/null || echo "balanced"
}

enable_boost() {
    # Save current profile
    get_current_profile > "$PREV_PROFILE_FILE"

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance >/dev/null 2>&1
    fi

    # Disable compositor eye-candy (iterates only if hyprctl exists)
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl --batch "\
keyword decoration:blur:enabled false ;\
keyword decoration:dim_inactive false ;\
keyword animations:enabled 0" >/dev/null 2>&1
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Zen Shell" -i input-gaming -u normal \
            "🎮 Gaming Detected" \
            "Performance + effects off for max FPS" \
            -t 3000
    fi

    echo "boost" > "$STATE_FILE"
}

disable_boost() {
    local prev
    prev=$(cat "$PREV_PROFILE_FILE" 2>/dev/null || echo "balanced")

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set "$prev" >/dev/null 2>&1
    fi

    # Restore compositor settings from settings-state-v2.json
    local blur="true" dim="false"
    if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS_JSON" ]; then
        blur=$(jq -r '.decoration.blurEnabled // true' "$SETTINGS_JSON" 2>/dev/null)
        dim=$(jq  -r '.decoration.dimInactive // false' "$SETTINGS_JSON" 2>/dev/null)
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl --batch "\
keyword decoration:blur:enabled $blur ;\
keyword decoration:dim_inactive $dim ;\
keyword animations:enabled 1" >/dev/null 2>&1
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Zen Shell" -i input-gaming -u low \
            "Gaming Ended" \
            "Restored $prev + effects" \
            -t 3000
    fi

    echo "idle" > "$STATE_FILE"
}

# ── Main loop ──
mkdir -p "$(dirname "$STATE_FILE")"
echo "idle" > "$STATE_FILE"

while true; do
    CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "idle")

    if is_gaming; then
        if [ "$CURRENT_STATE" != "boost" ]; then
            enable_boost
        fi
    else
        if [ "$CURRENT_STATE" = "boost" ]; then
            disable_boost
        fi
    fi

    sleep 3
done
