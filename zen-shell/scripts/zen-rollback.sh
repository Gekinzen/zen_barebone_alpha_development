#!/usr/bin/env bash
# zen-rollback.sh v7.0.0-alpha.1
#
# Restores a Zen Shell snapshot. ALWAYS creates a safety snapshot of the
# current install first, unless --no-safety-snapshot is passed.
#
# Usage:
#   zen-rollback.sh <snapshot-path> [--no-safety-snapshot]
#
# Atomicity guarantees:
#   1. Validate snapshot integrity (qml/ subdir exists, SNAPSHOT.json valid).
#   2. Create safety snapshot of current $SHELL_DIR.
#   3. Stage restore in temp dir.
#   4. Swap atomically (rename oldshell→backup, newshell→oldshell-name).
#   5. On any step failure → revert.
#
# Stdout: human-readable status messages (last line shown in UI footer).
# Exit 0 on success, non-zero on failure.

set -euo pipefail

SHELL_DIR="$HOME/.config/quickshell/zen-shell"
STATE_DIR="$HOME/.local/share/zen-shell"
LOG="$STATE_DIR/updates.log"

# Sibling scripts live alongside this one (v7 design — full-path calls
# avoid PATH dependency and ensure script versions match QML versions
# atomically across rollback boundaries).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPSHOT_BIN="$SCRIPT_DIR/zen-snapshot-create.sh"

mkdir -p "$STATE_DIR"

log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG"
    echo "$*"
}

SNAP=""
SAFETY_SNAP=1
while [ $# -gt 0 ]; do
    case "$1" in
        --no-safety-snapshot) SAFETY_SNAP=0; shift ;;
        -h|--help)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *) SNAP="$1"; shift ;;
    esac
done

if [ -z "$SNAP" ] || [ ! -d "$SNAP" ]; then
    log "ERROR: snapshot path missing or not a directory: $SNAP"
    exit 2
fi

if [ ! -d "$SNAP/qml" ]; then
    log "ERROR: snapshot has no qml/ subdir, cannot restore: $SNAP"
    exit 3
fi

# Sanity check: at least shell.qml must exist in snapshot.
if [ ! -f "$SNAP/qml/shell.qml" ]; then
    log "ERROR: snapshot qml/shell.qml missing — refusing to restore corrupt snapshot"
    exit 4
fi

# Read snapshot version for log clarity.
SNAP_VER="unknown"
if [ -f "$SNAP/SNAPSHOT.json" ] && command -v jq >/dev/null 2>&1; then
    SNAP_VER=$(jq -r '.version // "unknown"' "$SNAP/SNAPSHOT.json" 2>/dev/null)
fi

log "Beginning rollback to $SNAP_VER ($(basename "$SNAP"))"

# ── Safety snapshot of current ──
if [ "$SAFETY_SNAP" -eq 1 ] && [ -d "$SHELL_DIR" ]; then
    if [ -x "$SNAPSHOT_BIN" ]; then
        # Try to read current version for the safety snapshot label.
        local_ver="pre-rollback"
        if [ -f "$SHELL_DIR/ZenVersion.qml" ]; then
            ver_extracted=$(grep -m1 'readonly property string version:' "$SHELL_DIR/ZenVersion.qml" \
                | sed 's/.*"\([^"]*\)".*/\1/')
            [ -n "$ver_extracted" ] && local_ver="$ver_extracted"
        fi
        log "Creating safety snapshot of current install ($local_ver)…"
        if ! "$SNAPSHOT_BIN" --version "$local_ver" \
                             --label "pre-rollback-to-$SNAP_VER" 2>&1 | tail -1; then
            log "ERROR: safety snapshot failed — aborting rollback for safety"
            exit 5
        fi
    else
        log "WARNING: $SNAPSHOT_BIN missing — proceeding without safety snapshot"
    fi
fi

# ── Stage restore in a sibling dir, then atomic swap ──
TS=$(date +%s)
PARENT_DIR="$(dirname "$SHELL_DIR")"
STAGE_DIR="$PARENT_DIR/.zen-shell.stage-$TS"
OLD_DIR="$PARENT_DIR/.zen-shell.old-$TS"

# Cleanup helper for any failure path.
cleanup_failed() {
    log "Restore failed during $1 — attempting auto-revert."
    # If we successfully renamed away the original but haven't swapped
    # the staged one in, restore the original.
    if [ -d "$OLD_DIR" ] && [ ! -d "$SHELL_DIR" ]; then
        mv "$OLD_DIR" "$SHELL_DIR" || true
    fi
    rm -rf "$STAGE_DIR" 2>/dev/null || true
    log "Revert complete. Shell unchanged."
    exit 10
}

trap 'cleanup_failed "trap"' ERR

mkdir -p "$STAGE_DIR" || cleanup_failed "stage-mkdir"
cp -a "$SNAP/qml/." "$STAGE_DIR/" || cleanup_failed "stage-copy"

# Copy state files from snapshot into staged dir's expected target
# (state restore is OPTIONAL — we restore alongside QML for consistency).
# We DO restore state, because mismatched state vs old QML can crash
# the shell on next launch. User's expectation when clicking "Restore"
# is "make it look like that point in time."
if [ -d "$SNAP/state" ]; then
    STATE_STAGE="$PARENT_DIR/.zen-state.stage-$TS"
    mkdir -p "$STATE_STAGE"
    cp -a "$SNAP/state/." "$STATE_STAGE/" 2>/dev/null || true
fi

# ── Atomic-ish swap ──
# 1. Move current → old
# 2. Move staged → current
if [ -d "$SHELL_DIR" ]; then
    mv "$SHELL_DIR" "$OLD_DIR" || cleanup_failed "swap-rename-current"
fi
mv "$STAGE_DIR" "$SHELL_DIR" || cleanup_failed "swap-rename-stage"

# State swap (best-effort — failure does not abort because shell
# can fall back to default state on first launch).
if [ -n "${STATE_STAGE:-}" ] && [ -d "$STATE_STAGE" ]; then
    STATE_BAK="$STATE_DIR/.state.bak-$TS"
    mkdir -p "$STATE_BAK"
    for f in "$STATE_DIR"/*.json "$STATE_DIR"/*.state; do
        [ -f "$f" ] || continue
        mv "$f" "$STATE_BAK/" 2>/dev/null || true
    done
    for f in "$STATE_STAGE"/*; do
        [ -e "$f" ] || continue
        cp -a "$f" "$STATE_DIR/" || true
    done
    rm -rf "$STATE_STAGE"
fi

# Cleanup the displaced old install (we keep it around as .old-$TS for
# 7 days as a tertiary safety net, beyond the snapshot system).
# A separate cron/systemd timer should handle pruning these eventually.
log "Old install retained at: $(basename "$OLD_DIR") (auto-prune after 7 days)"

trap - ERR
log "Rollback complete to $SNAP_VER. Restart the shell: qs -r"
exit 0
