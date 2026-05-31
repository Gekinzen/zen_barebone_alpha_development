#!/usr/bin/env bash
# zen-plugin-loader.sh — Instant Hyprland plugin loader
#
# v7.0.0-beta.1-hf82w — Direct .so load via hyprctl, no hyprpm needed
#
# Reads plugin .so paths from cache built at install time, issues
# `hyprctl plugin load /path/to/foo.so` for each. Falls back to
# zen-plugin-bootstrap.sh if cache is missing/stale or any load fails.
#
# Called from zen-plugin-loader.service (systemd --user, oneshot,
# ordered after graphical-session.target).
#
# Log: /tmp/zen-plugin-loader.log (cleared each run)
#
# Cache format (~/.local/share/zen-shell/plugin-cache.json):
#   {
#     "hyprland_version": "0.55.2",
#     "hyprland_commit": "39d7e209c79d451efab1b21151d5938289da838d",
#     "created_at": "2026-05-26T15:43:00Z",
#     "plugins": [
#       { "name": "hyprbars", "path": "/run/user/1000/hyprpm/paul/hyprbars/hyprbars.so" },
#       { "name": "hyprexpo", "path": "/run/user/1000/hyprpm/paul/hyprexpo/hyprexpo.so" }
#     ]
#   }
#
# Cache invalidation: if running Hyprland version != cached version,
# fall back to bootstrap (rebuilds via hyprpm, refreshes cache).

set -u
LOG=/tmp/zen-plugin-loader.log
CACHE="$HOME/.local/share/zen-shell/plugin-cache.json"
BOOTSTRAP="$HOME/.local/bin/zen-plugin-bootstrap.sh"

# Clear log
: > "$LOG"
echo "[$(date)] zen-plugin-loader starting (PID $$)" >> "$LOG"

# ── Helper: fall through to bootstrap ──
fallback() {
    local reason="$1"
    echo "[$(date)] FALLBACK to bootstrap: $reason" >> "$LOG"
    if [ -x "$BOOTSTRAP" ]; then
        exec "$BOOTSTRAP"
    else
        echo "[$(date)] FATAL: $BOOTSTRAP not executable" >> "$LOG"
        exit 1
    fi
}

# ── Sanity: Hyprland IPC reachable? ──
if ! hyprctl version >/dev/null 2>&1; then
    fallback "hyprctl IPC not reachable"
fi

# ── Sanity: cache exists? ──
if [ ! -f "$CACHE" ]; then
    fallback "cache missing at $CACHE"
fi

# ── Sanity: version matches? ──
# Parse 'Tag: v0.55.2' from hyprctl version output
RUNNING_VER=$(hyprctl version 2>/dev/null | grep -oE 'Tag: v?[0-9.]+' | head -1 | sed 's/Tag: v\?//')
CACHED_VER=$(grep -oP '"hyprland_version":\s*"\K[^"]+' "$CACHE" 2>/dev/null | head -1)

echo "[$(date)] running version: $RUNNING_VER, cached version: $CACHED_VER" >> "$LOG"

if [ -z "$RUNNING_VER" ] || [ -z "$CACHED_VER" ]; then
    fallback "could not determine versions (running='$RUNNING_VER' cached='$CACHED_VER')"
fi

if [ "$RUNNING_VER" != "$CACHED_VER" ]; then
    fallback "Hyprland version changed ($CACHED_VER → $RUNNING_VER); rebuild needed"
fi

# ── Load each plugin via direct hyprctl ──
# Parse the plugins array using bash + grep (no jq dep)
# Extract each "path": "..." entry one per line
PLUGIN_PATHS=$(grep -oP '"path":\s*"\K[^"]+' "$CACHE" 2>/dev/null)

if [ -z "$PLUGIN_PATHS" ]; then
    echo "[$(date)] No plugins in cache — nothing to load" >> "$LOG"
    exit 0
fi

LOADED=0
FAILED=0
while IFS= read -r so_path; do
    [ -z "$so_path" ] && continue
    if [ ! -f "$so_path" ]; then
        echo "[$(date)] SKIP: $so_path does not exist" >> "$LOG"
        FAILED=$((FAILED + 1))
        continue
    fi
    # Direct plugin load — fast, no hyprpm reload-everything path
    result=$(hyprctl plugin load "$so_path" 2>&1)
    rc=$?
    if [ $rc -eq 0 ] && [[ "$result" == *"ok"* ]] || [[ "$result" == "" ]]; then
        echo "[$(date)] LOADED: $so_path" >> "$LOG"
        LOADED=$((LOADED + 1))
    else
        echo "[$(date)] FAIL: $so_path → $result" >> "$LOG"
        FAILED=$((FAILED + 1))
    fi
done <<< "$PLUGIN_PATHS"

echo "[$(date)] Result: $LOADED loaded, $FAILED failed" >> "$LOG"

# If ANY plugin failed to load, fall through to bootstrap as recovery
if [ $FAILED -gt 0 ]; then
    fallback "$FAILED plugin(s) failed to load from cache"
fi

# Final reload to register plugin-provided keywords
# (small delay so plugins finish initializing)
sleep 0.3
hyprctl reload >/dev/null 2>&1
echo "[$(date)] Post-load reload complete" >> "$LOG"

exit 0
