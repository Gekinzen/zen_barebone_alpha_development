#!/usr/bin/env bash
# patch-swaync-position.sh — Patch SwayNC notification position
#
# Usage: patch-swaync-position.sh <positionX> <positionY>
# Example: patch-swaync-position.sh right bottom
#
# Reads ~/.config/swaync/config.json, patches positionX/positionY,
# writes it back, regens theme CSS, restarts swaync daemon.
#
# Called by Zen Shell NotificationPage.qml on position change.
#
# v6.13.1 fixes:
#   - Verify config write succeeded before restarting
#   - Use SIGTERM first, SIGKILL as fallback (clean Wayland teardown)
#   - Skip --reload-config (position requires full restart anyway)
#   - Longer sleep for daemon startup before test notification
#   - Regen CSS BEFORE patching config (so regen can't overwrite position)

set -u

PX="${1:-right}"
PY="${2:-top}"

SWAYNC_CONFIG="$HOME/.config/swaync/config.json"
REGEN_SCRIPT="$HOME/.local/bin/regen-swaync-theme.sh"
LOG="/tmp/zen-swaync-position.log"

echo "═══════════════════════════════════════════════" > "$LOG"
echo "[patch-position] $(date -Iseconds)" | tee -a "$LOG"
echo "[patch-position] Setting positionX=$PX positionY=$PY" | tee -a "$LOG"

# ── Step 1: Regen swaync theme CSS FIRST ──
# This only writes style.css, not config.json. But running it first
# ensures any future regen changes can't accidentally clobber our
# position patch.
if [ -x "$REGEN_SCRIPT" ]; then
    echo "[patch-position] Running regen-swaync-theme.sh..." | tee -a "$LOG"
    "$REGEN_SCRIPT" >> "$LOG" 2>&1
fi

# ── Step 2: Patch config.json ──
if [ ! -f "$SWAYNC_CONFIG" ]; then
    echo "[patch-position] ERROR: $SWAYNC_CONFIG not found" | tee -a "$LOG"
    # Create a minimal config so we have something to work with
    mkdir -p "$(dirname "$SWAYNC_CONFIG")"
    echo '{}' > "$SWAYNC_CONFIG"
    echo "[patch-position] Created minimal config.json" | tee -a "$LOG"
fi

echo "[patch-position] Config BEFORE patch:" | tee -a "$LOG"
grep -E "positionX|positionY" "$SWAYNC_CONFIG" 2>/dev/null | tee -a "$LOG"

python3 - "$SWAYNC_CONFIG" "$PX" "$PY" << 'PYEOF'
import json, sys

cfg_path = sys.argv[1]
px = sys.argv[2]
py = sys.argv[3]

try:
    with open(cfg_path, 'r') as f:
        config = json.load(f)

    config['positionX'] = px
    config['positionY'] = py

    with open(cfg_path, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')

    print(f"[patch-position] Patched: positionX={config['positionX']} positionY={config['positionY']}")
except Exception as e:
    print(f"[patch-position] Python ERROR: {e}")
    sys.exit(1)
PYEOF

PATCH_RC=$?

if [ $PATCH_RC -ne 0 ]; then
    echo "[patch-position] Python patch failed (rc=$PATCH_RC), trying sed fallback" | tee -a "$LOG"
    # sed fallback: update existing keys or append if missing
    if grep -q '"positionX"' "$SWAYNC_CONFIG"; then
        sed -i "s/\"positionX\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"positionX\": \"$PX\"/" "$SWAYNC_CONFIG"
    fi
    if grep -q '"positionY"' "$SWAYNC_CONFIG"; then
        sed -i "s/\"positionY\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"positionY\": \"$PY\"/" "$SWAYNC_CONFIG"
    fi
fi

# ── Step 3: Verify the config was actually written ──
echo "[patch-position] Config AFTER patch:" | tee -a "$LOG"
grep -E "positionX|positionY" "$SWAYNC_CONFIG" 2>/dev/null | tee -a "$LOG"

# Verify values match what we intended
ACTUAL_PX=$(python3 -c "import json; c=json.load(open('$SWAYNC_CONFIG')); print(c.get('positionX','MISSING'))" 2>/dev/null)
ACTUAL_PY=$(python3 -c "import json; c=json.load(open('$SWAYNC_CONFIG')); print(c.get('positionY','MISSING'))" 2>/dev/null)

if [ "$ACTUAL_PX" != "$PX" ] || [ "$ACTUAL_PY" != "$PY" ]; then
    echo "[patch-position] WARNING: Verification failed! Expected $PX/$PY but got $ACTUAL_PX/$ACTUAL_PY" | tee -a "$LOG"
fi

# ── Step 4: Full restart swaync ──
# Position changes require a full daemon restart (--reload-config doesn't
# apply position). Use SIGTERM first for clean Wayland surface teardown,
# SIGKILL as fallback.
echo "[patch-position] Stopping swaync..." | tee -a "$LOG"

pkill -TERM swaync 2>/dev/null
sleep 1

# If still alive, force kill
if pgrep -x swaync >/dev/null 2>&1; then
    echo "[patch-position] swaync still running, sending SIGKILL" | tee -a "$LOG"
    pkill -9 swaync 2>/dev/null
    sleep 0.5
fi

# Verify it's dead
if pgrep -x swaync >/dev/null 2>&1; then
    echo "[patch-position] WARNING: swaync still running after SIGKILL" | tee -a "$LOG"
fi

# Start detached
echo "[patch-position] Starting swaync..." | tee -a "$LOG"
setsid swaync </dev/null >/dev/null 2>&1 &
disown 2>/dev/null

# Wait for daemon to fully initialize (needs time to read config + connect to Wayland)
sleep 2

# Verify daemon is running
if pgrep -x swaync >/dev/null 2>&1; then
    echo "[patch-position] swaync running (pid=$(pgrep -x swaync))" | tee -a "$LOG"
else
    echo "[patch-position] ERROR: swaync failed to start!" | tee -a "$LOG"
    # Try once more
    setsid swaync </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null
    sleep 2
fi

# Send test notification
notify-send -t 3000 "Position: $PY-$PX" "Notifications now appear $PY-$PX" 2>/dev/null

echo "[patch-position] Done" | tee -a "$LOG"
exit 0
