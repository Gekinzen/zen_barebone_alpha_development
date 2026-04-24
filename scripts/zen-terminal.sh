#!/usr/bin/env bash
# zen-terminal.sh — launch user's preferred terminal
#
# Priority order:
#   1. $ZEN_TERMINAL env var — respects user override
#   2. alacritty  (Zen Shell's default install target)
#   3. kitty      (common alternate)
#   4. wezterm
#   5. foot       (Wayland-native fallback)
#   6. ghostty    (newer arrivals)
#   7. x-terminal-emulator  (Debian/Ubuntu meta-pointer)
#
# Exit silently if none are found rather than leaving the user
# wondering why Super+T did nothing.

set -u

LOG="$HOME/.cache/zen-shell/terminal.log"
mkdir -p "$(dirname "$LOG")"
echo "[$(date +%H:%M:%S)] zen-terminal.sh invoked" >> "$LOG"

# User override via env or config
if [ -n "${ZEN_TERMINAL:-}" ] && command -v "$ZEN_TERMINAL" >/dev/null 2>&1; then
    echo "[$(date +%H:%M:%S)] using \$ZEN_TERMINAL=$ZEN_TERMINAL" >> "$LOG"
    exec "$ZEN_TERMINAL" "$@"
fi

# Optional per-user config file (for non-env users)
CONF="$HOME/.config/zen-shell/terminal.conf"
if [ -r "$CONF" ]; then
    PREFERRED=$(grep -v '^#' "$CONF" | head -1 | tr -d '[:space:]')
    if [ -n "$PREFERRED" ] && command -v "$PREFERRED" >/dev/null 2>&1; then
        echo "[$(date +%H:%M:%S)] using $CONF → $PREFERRED" >> "$LOG"
        exec "$PREFERRED" "$@"
    fi
fi

# Auto-detect in priority order
for term in alacritty kitty wezterm foot ghostty x-terminal-emulator; do
    if command -v "$term" >/dev/null 2>&1; then
        echo "[$(date +%H:%M:%S)] auto-detected: $term" >> "$LOG"
        exec "$term" "$@"
    fi
done

# Nothing found — notify the user
echo "[$(date +%H:%M:%S)] NO TERMINAL FOUND" >> "$LOG"
if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Zen Shell: No terminal found" \
        "Install alacritty: paru -S alacritty (or set \$ZEN_TERMINAL)"
fi
exit 1
