#!/usr/bin/env bash
# zen-quickprompt.sh — v6.16.4.12.6.17 (Hikari)
#
# Lightweight terminal popup that drops down from the top of the screen.
# Like a TF2-style quake console, optimized for one-shot commands.
#
# Triggered by Super+Shift+T (configured in hypr-config/keybinds-update.conf).
#
# Behavior:
#   - First invocation: spawns alacritty as a floating window pinned to
#     the top-center of the focused monitor (1000x350 by default).
#   - Subsequent invocations: focuses the existing window, OR if the user
#     dismissed it, spawns a new one.
#   - Pressing Escape inside the prompt closes it (alacritty config).
#
# Why a script and not a direct hyprland exec rule:
#   We need (a) Hyprland window-rules to position correctly, (b) a focus
#   re-target if the window already exists. A script handles both cleanly.
#
# Wala tayo babawasan: this is a NEW addition. Existing Super+T → kitty
# binding is untouched. Super+Shift+T is a separate keybind layer.

set -euo pipefail

WIN_TITLE="zen-quickprompt"
WIN_CLASS="zen-quickprompt"

# Check if a quickprompt is already open — focus it instead of spawning new
if command -v hyprctl >/dev/null 2>&1; then
    EXISTING=$(hyprctl clients -j 2>/dev/null \
               | jq -r --arg c "$WIN_CLASS" '.[] | select(.class == $c) | .address' \
               | head -1)
    if [ -n "$EXISTING" ]; then
        # Toggle: if it's already focused, close it; else focus it
        ACTIVE=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // ""')
        if [ "$ACTIVE" = "$EXISTING" ]; then
            # Currently focused → close it
            hyprctl dispatch closewindow "address:$EXISTING" >/dev/null 2>&1 || true
            exit 0
        else
            # Exists but not focused → focus it
            hyprctl dispatch focuswindow "address:$EXISTING" >/dev/null 2>&1 || true
            exit 0
        fi
    fi
fi

# Pick a shell to run inside the prompt — prefer fish > zsh > bash
SHELL_CMD="${SHELL:-/bin/bash}"

# Spawn the floating terminal. Window rules in hyprland-layer-rules.conf
# match `class: zen-quickprompt` to give it the floating + top-anchored
# treatment automatically, so we don't need exec-once dispatch tricks.
if command -v alacritty >/dev/null 2>&1; then
    alacritty \
        --class "$WIN_CLASS,$WIN_CLASS" \
        --title "$WIN_TITLE" \
        --option 'window.opacity = 0.96' \
        --option 'window.padding = { x = 18, y = 14 }' \
        --option 'font.size = 13' \
        -e "$SHELL_CMD" &
elif command -v kitty >/dev/null 2>&1; then
    kitty \
        --class "$WIN_CLASS" \
        --title "$WIN_TITLE" \
        --override 'background_opacity=0.96' \
        --override 'window_padding_width=14' \
        -e "$SHELL_CMD" &
elif command -v foot >/dev/null 2>&1; then
    foot \
        --app-id="$WIN_CLASS" \
        --title="$WIN_TITLE" \
        "$SHELL_CMD" &
else
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "Zen Quickprompt" \
            "No supported terminal found (alacritty / kitty / foot)"
    fi
    echo "[zen-quickprompt] no terminal binary found" >&2
    exit 1
fi
