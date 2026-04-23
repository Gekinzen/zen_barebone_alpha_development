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

# ── v6.16.4: Wait for compositor with aggressive retries ──
# After a deep suspend on some AMD/Intel hardware, hyprctl IPC
# can take up to 5s to come back. Old code aborted at 2s which
# left the user on a black screen. New: retry up to 5s, and if
# STILL unreachable, attempt a kernel-level DRM kick as a last
# resort before giving up.
WAITED=0
while ! hyprctl monitors >/dev/null 2>&1; do
    sleep 0.1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 50 ]; then
        log "  hyprctl unreachable after 5s — last-resort DRM kick"
        # Blind DRM power cycle via sysfs. Works even when
        # Hyprland's IPC is dead. Only fires if we can find
        # drm card nodes (i.e. we're running on a KMS-enabled GPU).
        for card in /sys/class/drm/card*/card*-*/enabled; do
            [ -w "$card" ] || continue
            echo "disabled" >"$card" 2>/dev/null
            sleep 0.1
            echo "enabled"  >"$card" 2>/dev/null
        done
        log "  DRM sysfs kick attempted; continuing recovery steps"
        break
    fi
done
[ "$WAITED" -lt 50 ] && log "  hyprctl reachable after ${WAITED}00ms"

# ── v6.16.4.1 Step 1: Monitor re-sync WITHOUT wiping runtime config ──
# Previously called `hyprctl reload` which wipes runtime monitor
# keywords set via Settings → Displays. After wake, monitors
# reverted to hyprland.conf defaults → user's custom resolution
# /scale/refresh-rate gone.
#
# Fix: use forcerendererreload (KMS re-enum only, preserves
# runtime config). Same recovery benefit, zero config clobbering.
hyprctl dispatch forcerendererreload >/dev/null 2>&1 || true
sleep 0.2

# Per-monitor preferred mode force — REMOVED in 4.1.
# Reason: overrides user custom resolution/scale. The
# forcerendererreload above handles the re-enum we need.
# Leaving this as an explicit comment so future-me doesn't
# re-add it thinking it's a defensive measure.

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

    # v6.16.4: detect zombie hyprlock. If it's running but the
    # compositor can't see its surface anymore, we're in the
    # "black screen + frozen lock" trap. Check by querying layers.
    sleep 0.5
    LAYER_COUNT=$(hyprctl layers -j 2>/dev/null \
        | jq -r '[..|.namespace? // empty | select(contains("hyprlock") or contains("session-lock"))] | length' 2>/dev/null \
        || echo 0)
    if [ "$LAYER_COUNT" = "0" ] && pgrep -x hyprlock >/dev/null 2>&1; then
        log "  hyprlock is zombie (process up, no layer surface) — SIGKILL + relock"
        pkill -9 -x hyprlock 2>/dev/null
        sleep 0.2
        if [ -x "$HOME/.local/bin/zen-lock.sh" ]; then
            setsid -f "$HOME/.local/bin/zen-lock.sh" </dev/null >/dev/null 2>&1 &
            log "  relaunched via zen-lock.sh"
        fi
    fi
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

# ── v6.16.4.1: Step 7 workspace bounce REMOVED ──
# Was dispatching workspace switch to force a paint pass. Side
# effect: music widget marquee animation replayed every wake,
# window fade-in animations double-fired. DPMS cycle + forcerenderer
# already handle the paint need — bounce was redundant insurance
# with unwanted animation side effects.

# ── v6.16.4 Step 8: Input subsystem kick ──
# Occasionally after wake from deep sleep, keyboard input doesn't
# reach Wayland clients (scenario: hyprlock shows, keystrokes
# don't register in password field). The cause is libinput
# thinking the device is still sleeping. A cheap fix: poke the
# device node's power/wakeup to bounce it.
#
# This is a best-effort step — it silently skips devices we can't
# write to. Worst case, no change.
for dev in /sys/class/input/input*/device/power/control; do
    [ -w "$dev" ] || continue
    cur=$(cat "$dev" 2>/dev/null)
    if [ "$cur" = "auto" ]; then
        echo "on"   >"$dev" 2>/dev/null
        sleep 0.05
        echo "auto" >"$dev" 2>/dev/null
    fi
done
log "  input subsystem power-cycle poke complete"

# ── v6.16.4 Step 9: Hyprctl responsiveness validation ──
# Final sanity check. If hyprctl is still not responding to simple
# commands, something's deeply wrong. Log it loudly so post-mortem
# via resume.log is clear — the user can see "recovery tried but
# hyprland is still wedged" and knows to hit the panic keybind.
if ! timeout 2 hyprctl dispatch focuscurrentorlast >/dev/null 2>&1; then
    log "  ⚠ WARNING: hyprctl still unresponsive after recovery."
    log "  ⚠ Try panic keybind: SUPER+SHIFT+CTRL+Escape"
    log "  ⚠ Or from SSH: ~/.local/bin/zen-panic.sh"
fi

log "resume: pipeline complete"
exit 0
