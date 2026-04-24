#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-hypridle-sync.sh v6.16.3.8
# ────────────────────────────────────────────────────────────────
# Bridges PanelState.idleLockSeconds / idleSleepSeconds / (derived
# DPMS-off timeout) → hypridle.conf listener blocks.
#
# Flow:
#   1. Read integers from ~/.local/share/quickshell/zen-shell/panel-state.json
#   2. Normalize: 0 / missing → sentinel 99999999 (effectively never)
#   3. DPMS = LOCK + 60 (so display stays on briefly after lock)
#   4. sed-rewrite the three "timeout = X    # ZEN_IDLE_*" lines
#      in ~/.config/hypr/hypridle.conf, leaving everything else
#      (user customizations, extra listener blocks) untouched
#   5. Restart hypridle so new timeouts take effect immediately
#
# Invoked by:
#   - Settings → Power → Idle Behavior comboboxes (onActivated)
#   - install.sh phase B (ensures defaults are correct on first run)
#   - shell.qml on startup (defensive — catches case where user
#     edited panel-state.json manually with hypridle already running)
#
# Idempotent. Safe to call repeatedly. Only modifies marker lines.
# ════════════════════════════════════════════════════════════════

set -u

PANEL_STATE="$HOME/.local/share/quickshell/zen-shell/panel-state.json"
HYPRIDLE_CONF="$HOME/.config/hypr/hypridle.conf"
LOG_FILE="$HOME/.cache/zen-shell/hypridle-sync.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log() {
    local ts="$(date +'%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" >>"$LOG_FILE" 2>/dev/null
    if [ -f "$LOG_FILE" ] && [ "$(wc -l <"$LOG_FILE" 2>/dev/null || echo 0)" -gt 100 ]; then
        tail -80 "$LOG_FILE" >"$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
    fi
}

# ── Preflight ──
if [ ! -f "$HYPRIDLE_CONF" ]; then
    log "error: $HYPRIDLE_CONF not found — install.sh not run?"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log "error: jq missing — cannot parse panel-state.json"
    exit 1
fi

# ── Read values from PanelState (defensive defaults) ──
LOCK_SEC=300
SLEEP_SEC=0
if [ -f "$PANEL_STATE" ]; then
    # jq returns "null" string on missing keys; coerce via // fallback
    LOCK_SEC=$(jq -r '.idleLockSeconds // 300' "$PANEL_STATE" 2>/dev/null)
    SLEEP_SEC=$(jq -r '.idleSleepSeconds // 0' "$PANEL_STATE" 2>/dev/null)
    # Guard against non-integer values
    case "$LOCK_SEC"  in ''|*[!0-9]*) LOCK_SEC=300 ;;  esac
    case "$SLEEP_SEC" in ''|*[!0-9]*) SLEEP_SEC=0 ;;   esac
fi

# ── Normalize zero → sentinel ──
# hypridle requires listener blocks to have valid timeouts. 0 isn't
# accepted, so we use a very large number that's effectively never.
LOCK_TIMEOUT=$LOCK_SEC
[ "$LOCK_TIMEOUT" -eq 0 ] && LOCK_TIMEOUT=99999999

SLEEP_TIMEOUT=$SLEEP_SEC
[ "$SLEEP_TIMEOUT" -eq 0 ] && SLEEP_TIMEOUT=99999999

# ── Derive DPMS off (lock + 60s, or sentinel if lock is never) ──
if [ "$LOCK_SEC" -eq 0 ]; then
    DPMS_TIMEOUT=99999999
else
    DPMS_TIMEOUT=$((LOCK_TIMEOUT + 60))
fi

log "syncing: lock=${LOCK_TIMEOUT}  dpms=${DPMS_TIMEOUT}  sleep=${SLEEP_TIMEOUT}"

# ── sed-rewrite the marker lines ──
# Regex breakdown:
#   ^(\s*timeout\s*=\s*)   — captures the "timeout      = " prefix,
#                            preserving user's whitespace
#   [0-9]+                 — the current integer to replace
#   (\s*#\s*ZEN_IDLE_LOCK.*)$ — captures the marker trailer
#
# Result: just the number changes; everything else stays byte-identical.
sed -i -E \
    -e "s|^(\s*timeout\s*=\s*)[0-9]+(\s*#\s*ZEN_IDLE_LOCK.*)$|\1${LOCK_TIMEOUT}\2|" \
    -e "s|^(\s*timeout\s*=\s*)[0-9]+(\s*#\s*ZEN_IDLE_DPMS.*)$|\1${DPMS_TIMEOUT}\2|" \
    -e "s|^(\s*timeout\s*=\s*)[0-9]+(\s*#\s*ZEN_IDLE_SLEEP.*)$|\1${SLEEP_TIMEOUT}\2|" \
    "$HYPRIDLE_CONF"

if [ $? -ne 0 ]; then
    log "error: sed failed on $HYPRIDLE_CONF"
    exit 1
fi

# ── Restart hypridle so changes apply immediately ──
# hypridle doesn't support SIGHUP for config reload — we kill + relaunch.
# Run the new instance detached so this script can exit cleanly.
if command -v hypridle >/dev/null 2>&1; then
    if pgrep -x hypridle >/dev/null 2>&1; then
        pkill -x hypridle 2>/dev/null
        sleep 0.2
    fi
    setsid -f hypridle >/dev/null 2>&1 &
    log "hypridle restarted with new timeouts"
else
    log "warning: hypridle binary not found — config updated but daemon not running"
fi

exit 0
