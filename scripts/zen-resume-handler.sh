#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-resume-handler.sh v6.16.3.2 — Post-suspend recovery
# ────────────────────────────────────────────────────────────────
# Invoked from /usr/lib/systemd/system-sleep/zen-sleep-hook.sh
# on post-suspend / post-hibernate.
#
# Why this exists separately from zen-lid-handler.sh:
#   - The lid-handler runs ONLY when the lid switch fires.
#   - This runs on EVERY wake, including: lid wake, keyboard wake,
#     `loginctl unlock-session`, `systemctl suspend` from CLI,
#     auto-suspend from hypridle, etc.
#   - Symptoms like black-screen-on-wake are a wake-side issue,
#     not a lid-side issue. Belt-and-suspenders: do recovery in
#     both places, idempotent so doubling up is harmless.
# ────────────────────────────────────────────────────────────────
# How it's wired:
#   /usr/lib/systemd/system-sleep/zen-sleep-hook.sh runs as root
#   on post-suspend. It uses `loginctl` to find the active user
#   sessions and runs THIS script as that user, with their
#   WAYLAND_DISPLAY / HYPRLAND_INSTANCE_SIGNATURE / DBUS env.
#
#   Without that env this script can't talk to hyprctl. The
#   hook handles that translation.
# ════════════════════════════════════════════════════════════════

set -u

LOG_FILE="$HOME/.cache/zen-shell/resume.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log() {
    local ts msg
    ts=$(date +'%Y-%m-%d %H:%M:%S')
    msg="[$ts] $*"
    echo "$msg" >>"$LOG_FILE" 2>/dev/null
    if [ -f "$LOG_FILE" ] && [ "$(wc -l <"$LOG_FILE" 2>/dev/null || echo 0)" -gt 220 ]; then
        tail -200 "$LOG_FILE" >"$LOG_FILE.tmp" 2>/dev/null && \
            mv "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
    fi
}

log "resume: pipeline start (HIS=${HYPRLAND_INSTANCE_SIGNATURE:-unset})"

# ── Wait for compositor to be reachable ──
# After a deep suspend, hyprctl can take a few hundred ms before
# the IPC socket comes back. Retry up to 2s.
WAITED=0
while ! hyprctl monitors >/dev/null 2>&1; do
    sleep 0.1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 20 ]; then
        log "  hyprctl unreachable after 2s — abort recovery"
        exit 0
    fi
done
log "  hyprctl reachable after ${WAITED}00ms"

# ── Step 1: Force monitor re-enumeration ──
# This is critical for dock unplug/replug while suspended.
# hyprctl reload re-reads the config and re-applies monitor= rules.
hyprctl reload >/dev/null 2>&1 || true
sleep 0.2

# ── Step 2: For every detected monitor, force preferred mode ──
# This catches the case where Hyprland thinks a monitor is
# enabled but the actual KMS state is wrong.
MONITORS=$(hyprctl -j monitors 2>/dev/null | \
    jq -r '.[] | .name' 2>/dev/null)
if [ -n "$MONITORS" ]; then
    while IFS= read -r mon; do
        [ -n "$mon" ] || continue
        hyprctl keyword monitor "${mon},preferred,auto,1" >/dev/null 2>&1
        log "  force-applied preferred mode on $mon"
    done <<<"$MONITORS"
fi

# ── Step 3: DRM kick via DPMS off→on ──
# Same as the lid-handler step 4. Black-screen-on-wake fix.
hyprctl dispatch dpms off >/dev/null 2>&1 || true
sleep 0.2
hyprctl dispatch dpms on  >/dev/null 2>&1 || true
log "  DPMS off→on cycle complete"

# ── Step 4: Resurrect swww-daemon if zombied ──
if command -v swww >/dev/null 2>&1; then
    if ! swww query >/dev/null 2>&1; then
        log "  swww-daemon stale, restarting"
        pkill -f 'swww-daemon' 2>/dev/null
        sleep 0.1
        if command -v swww-daemon >/dev/null 2>&1; then
            setsid -f swww-daemon </dev/null >/dev/null 2>&1 &
        else
            setsid -f swww init </dev/null >/dev/null 2>&1 &
        fi
        sleep 0.3
        # Re-apply current wallpaper if Zen Shell saved one
        WP_FILE="$HOME/.config/quickshell/zen-shell/wallpaper-state.json"
        if [ -f "$WP_FILE" ] && command -v jq >/dev/null 2>&1; then
            CUR_WP=$(jq -r '.current // empty' "$WP_FILE" 2>/dev/null)
            if [ -n "$CUR_WP" ] && [ -f "$CUR_WP" ]; then
                swww img "$CUR_WP" --transition-type none >/dev/null 2>&1 &
                log "  re-applied wallpaper $CUR_WP"
            fi
        fi
    fi
fi

# ── Step 5: Kick hyprlock if running ──
# Same logic as lid-handler. SIGUSR1 = redraw on hyprlock 0.5+.
if pgrep -x hyprlock >/dev/null 2>&1; then
    pkill -SIGUSR1 -x hyprlock 2>/dev/null || true
    log "  hyprlock SIGUSR1 sent"
fi

# ── Step 6: Restart Zen Shell bar surfaces ──
# Quickshell layer-shell surfaces sometimes lose their wl_output
# binding across suspend if a monitor was hot-removed. The shell
# auto-recovers on next paint, but force a render hint just in case.
if pgrep -f 'quickshell.*zen-shell' >/dev/null 2>&1; then
    # SIGUSR2 is a custom no-op that wakes the event loop without
    # killing the process. Quickshell ignores unknown signals
    # gracefully so this is safe even on versions that don't
    # specifically handle it.
    pkill -SIGUSR2 -f 'quickshell.*zen-shell' 2>/dev/null || true
    log "  zen-shell event-loop wake hint sent"
fi

# ── Step 7: Workspace bounce to force a render pass ──
CUR_WS=$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id' 2>/dev/null)
if [ -n "$CUR_WS" ] && [ "$CUR_WS" != "null" ]; then
    if [ "$CUR_WS" != "1" ]; then
        hyprctl dispatch workspace 1         >/dev/null 2>&1 || true
        sleep 0.05
        hyprctl dispatch workspace "$CUR_WS" >/dev/null 2>&1 || true
    else
        hyprctl dispatch workspace 2         >/dev/null 2>&1 || true
        sleep 0.05
        hyprctl dispatch workspace 1         >/dev/null 2>&1 || true
    fi
    log "  workspace bounce complete (returned to ws $CUR_WS)"
fi

log "resume: pipeline complete"
exit 0
