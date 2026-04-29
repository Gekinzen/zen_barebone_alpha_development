#!/usr/bin/env bash
# zen-plugin-bootstrap.sh — Zen Shell plugin bootstrap (Tsubasa)
set -u
LOG=/tmp/zen-plugin-bootstrap.log
echo "[$(date)] Starting Zen Shell plugin bootstrap" > "$LOG"

# Wait for Hyprland IPC ready
for i in 1 2 3 4 5; do
    if hyprctl version >/dev/null 2>&1; then
        echo "[bootstrap] Hyprland ready (attempt $i)" >> "$LOG"
        break
    fi
    sleep 1
done

# hyprpm reload — loads all enabled plugins per hyprpm state
echo "[bootstrap] hyprpm reload..." >> "$LOG"
hyprpm reload -n 2>&1 >> "$LOG"

# Brief wait for plugins to register their keyword handlers
sleep 1

# SECOND config reload so plugin-registered keywords (buttons, binds)
# get parsed AFTER plugins are loaded.
echo "[bootstrap] hyprctl reload (post-plugin-load)..." >> "$LOG"
hyprctl reload 2>&1 >> "$LOG"

# Verify
echo "[bootstrap] Loaded plugins:" >> "$LOG"
hyprctl plugin list 2>&1 >> "$LOG"

echo "[$(date)] Bootstrap done." >> "$LOG"
