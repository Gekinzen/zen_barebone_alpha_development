#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-quickterm.sh v7.0.0-beta.1-hf95.14 — centered quick terminal
# ────────────────────────────────────────────────────────────────
# Toggles a top-center pop-up Alacritty. Bound to Super+Shift+T.
#
# Design:
#   - Uses a DEDICATED Alacritty instance with --class zen-quickterm and
#     a SEPARATE config (~/.config/alacritty-quick/alacritty.toml), so it
#     does NOT touch or inherit your normal Alacritty setup.
#   - Lives on a Hyprland special workspace (special:quickterm). Toggling
#     the special workspace is what gives the instant show/hide; window
#     rules (in hyprland-layer-rules.conf) pin it to the top, size it,
#     and animate the slide.
#   - First invocation spawns it; later invocations just toggle.
#
# Wala tayong babawasan — your normal `alacritty` is untouched.
# ════════════════════════════════════════════════════════════════
set -u

CLASS="zen-quickterm"
QUICK_CFG="$HOME/.config/alacritty-quick/alacritty.toml"

# v7.0.0-beta.1-hf95.17: special-workspace windows are auto-centered by
# Hyprland and IGNORE a `move` windowrule, which is why the terminal kept
# appearing dead-center instead of top-center. So we reposition it
# explicitly here, computed against the CURRENT monitor (multi-monitor
# safe), to: horizontally centered, ~40px from the top.
_reposition_quickterm() {
    command -v jq >/dev/null 2>&1 || return 0
    # Window size (matches the size windowrule fallback).
    local W=1100 H=600 TOP=40
    # Active monitor geometry + position.
    local mon_x mon_y mon_w
    mon_x=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .x' | head -1)
    mon_y=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .y' | head -1)
    mon_w=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .width' | head -1)
    [ -z "$mon_x" ] && return 0
    # Account for monitor scale so pixel coords land correctly.
    local scale
    scale=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .scale' | head -1)
    [ -z "$scale" ] && scale=1
    # Logical width = physical width / scale.
    local logical_w
    logical_w=$(awk -v w="$mon_w" -v s="$scale" 'BEGIN{printf "%d", w / s}')
    local x y
    x=$(awk -v mx="$mon_x" -v lw="$logical_w" -v ww="$W" 'BEGIN{printf "%d", mx + (lw - ww)/2}')
    y=$(awk -v my="$mon_y" -v top="$TOP" 'BEGIN{printf "%d", my + top}')
    # Move the window by class to the exact spot.
    hyprctl dispatch movewindowpixel "exact $x $y,class:$CLASS" >/dev/null 2>&1
    hyprctl dispatch resizewindowpixel "exact $W $H,class:$CLASS" >/dev/null 2>&1
}

# Is the quick terminal already running?
if hyprctl clients -j 2>/dev/null | grep -q "\"class\": \"$CLASS\""; then
    # Already exists → just toggle the special workspace (show/hide).
    hyprctl dispatch togglespecialworkspace quickterm >/dev/null 2>&1
    _reposition_quickterm
else
    # Not running → spawn it directly onto the special workspace, then
    # reveal it. `[workspace special:quickterm silent]` places it without
    # yanking focus to the special ws before rules apply.
    if command -v alacritty >/dev/null 2>&1; then
        cfg_arg=""
        [ -f "$QUICK_CFG" ] && cfg_arg="--config-file $QUICK_CFG"
        hyprctl dispatch exec "[workspace special:quickterm silent] alacritty --class $CLASS $cfg_arg" >/dev/null 2>&1
        # Give it a moment to map, then show the special workspace.
        sleep 0.15
        hyprctl dispatch togglespecialworkspace quickterm >/dev/null 2>&1
        sleep 0.10
        _reposition_quickterm
    else
        notify-send "Quick Terminal" "alacritty is not installed" 2>/dev/null || true
    fi
fi
