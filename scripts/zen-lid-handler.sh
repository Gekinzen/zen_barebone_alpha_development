#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-lid-handler.sh v6.16.3.2 — Smart Mode
# ────────────────────────────────────────────────────────────────
# Handle laptop lid open/close events with full AC/battery,
# external-monitor, and post-action awareness.
# ────────────────────────────────────────────────────────────────
# Hyprland calls this via bindl rules in lid-behavior.conf:
#   bindl = , switch:on:Lid,  exec, ~/.local/bin/zen-lid-handler.sh close
#   bindl = , switch:off:Lid, exec, ~/.local/bin/zen-lid-handler.sh open
#
# Behaviors (read from SettingsStateV2.system.lidCloseBehavior):
#
#   smart  — NEW DEFAULT in v6.16.3.2. Decides per-context:
#            ┌──────────────┬─────────────┬─────────────────────────┐
#            │ External?    │ AC plugged? │ Action                  │
#            ├──────────────┼─────────────┼─────────────────────────┤
#            │ Yes          │ —           │ Clamshell (disable eDP, │
#            │              │             │   externals keep going) │
#            │ No           │ Yes         │ Lock + DPMS off (no     │
#            │              │             │   suspend; quick wake   │
#            │              │             │   for always-on flow)   │
#            │ No           │ No          │ Lock + Suspend          │
#            └──────────────┴─────────────┴─────────────────────────┘
#
#   mirror — Legacy v6.16.0 behavior. Disable eDP if external present,
#            else suspend. Kept for users who saved this option.
#
#   keep   — Do nothing on close (for docked stand workflows).
#
#   off    — Always disable eDP on close (classic hyprctl behavior).
#
# On lid OPEN (any mode), the handler runs the FULL recovery
# pipeline:
#   1. Re-enable internal display with preferred mode
#   2. hyprctl reload (re-applies user monitor config from
#      hyprland.conf and re-enumerates monitors)
#   3. Wait 250ms for monitor settle
#   4. Force DPMS on for ALL outputs (kicks black-screen-on-wake)
#   5. Restart swww-daemon if it's been zombied by the suspend
#      (swww doesn't always survive systemd suspend cleanly)
#   6. Kick hyprlock with SIGUSR1 if it's running but unresponsive
#      (zombie hyprlock is a common stuck-behind-lock symptom)
#   7. Hop to workspace 1 then back, forcing a render pass
# ────────────────────────────────────────────────────────────────
# v6.16.3.2 changes vs v6.16.0:
#   + Added "smart" mode (now the new default)
#   + AC/battery awareness via /sys/class/power_supply
#   + Full recovery pipeline on open (was: just `hyprctl reload`)
#   + DRM kick via DPMS off→on cycle on every open
#   + swww-daemon resurrection on open
#   + hyprlock SIGUSR1 kick on open (fixes zombie lock)
#   + Logging to ~/.cache/zen-shell/lid.log for debugging
#   + State file at ~/.cache/zen-shell/lid-state for tracking
#     pre-close state (which monitors were enabled, etc.)
# Wala tayong binawasan — mirror/keep/off all still work exactly
# as in v6.16.0. Only the DEFAULT changed (when no setting is
# saved, smart is now used instead of mirror).
# ════════════════════════════════════════════════════════════════

set -u

ACTION="${1:-}"
CONFIG="$HOME/.config/quickshell/zen-shell/settings-state-v2.json"
STATE_DIR="$HOME/.cache/zen-shell"
STATE_FILE="$STATE_DIR/lid-state"
LOG_FILE="$STATE_DIR/lid.log"

mkdir -p "$STATE_DIR" 2>/dev/null

# ── Tiny logger ──
# Bounded log: keep last ~200 lines so it doesn't grow forever.
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

# ── Read user behavior preference ──
# Default in v6.16.3.2 is "smart" (new). If the user hasn't
# explicitly saved a value (or jq isn't around), use smart.
BEHAVIOR="smart"
if command -v jq >/dev/null 2>&1 && [ -f "$CONFIG" ]; then
    SAVED=$(jq -r '.system.lidCloseBehavior // empty' "$CONFIG" 2>/dev/null)
    case "$SAVED" in
        smart|mirror|keep|off) BEHAVIOR="$SAVED" ;;
    esac
fi

# ── v6.16.3.8: Read system action preference ──
# This is SEPARATE from BEHAVIOR above (which controls MONITOR
# handling on close — mirror/keep/off). LID_ACTION controls what
# the SYSTEM does on close:
#   suspend — lock + systemctl suspend (wake to lock screen)
#   lock    — lock screen only, stay powered
#   ignore  — no system action, only monitor handling fires
#
# When LID_ACTION = "suspend" or "lock", it OVERRIDES the per-branch
# lock/suspend logic in the smart/mirror cases below. When "ignore",
# the original monitor-only behavior is preserved.
#
# Read from PanelState (not SettingsStateV2) because this is a
# user preference tracked alongside idleLockSeconds.
PANEL_STATE="$HOME/.local/share/quickshell/zen-shell/panel-state.json"
LID_ACTION="suspend"
if command -v jq >/dev/null 2>&1 && [ -f "$PANEL_STATE" ]; then
    SAVED_ACTION=$(jq -r '.lidCloseAction // empty' "$PANEL_STATE" 2>/dev/null)
    case "$SAVED_ACTION" in
        suspend|lock|ignore) LID_ACTION="$SAVED_ACTION" ;;
    esac
fi

# ── Detect internal display name ──
# Most laptops report eDP-1; some older / niche hardware uses
# LVDS-1 or DSI-1. Grab the first monitor whose name matches.
detect_internal() {
    hyprctl -j monitors 2>/dev/null | \
        jq -r '.[] | .name' 2>/dev/null | \
        grep -E '^(eDP|LVDS|DSI)' | head -1
}

# ── Count externals (everything that isn't the internal one) ──
count_externals() {
    local internal="$1"
    hyprctl -j monitors 2>/dev/null | \
        jq -r '.[] | .name' 2>/dev/null | \
        grep -Ev "^${internal}\$" | wc -l
}

# ── AC adapter check ──
# Walks /sys/class/power_supply for any AC-class adapter that's
# online. Returns 0 if any AC is plugged in, 1 if not, 1 if no
# AC adapter exists at all (desktop / weird hardware).
on_ac() {
    local online=0
    for ac in /sys/class/power_supply/A{C,DP}*/online \
              /sys/class/power_supply/AC/online \
              /sys/class/power_supply/ACAD/online; do
        [ -f "$ac" ] || continue
        if [ "$(cat "$ac" 2>/dev/null)" = "1" ]; then
            online=1
            break
        fi
    done
    [ "$online" = "1" ]
}

# ── Lock screen launcher (graceful fallback chain) ──
# v6.16.4 hardening:
#   - Prefer zen-lock.sh wrapper when available (does wallpaper
#     sync + font sync + lock-message gen; stronger guarantee
#     that user lands on a fully-rendered lock screen).
#   - SIGKILL existing hyprlock if it's running but stuck (no
#     layer surface in hyprctl's view → zombie → kill + relaunch).
#   - Final fallback chain: hyprlock → swaylock → plain DPMS off.
lock_screen() {
    # Zombie detection — hyprlock running but hidden/frozen.
    if pgrep -x hyprlock >/dev/null 2>&1; then
        local layers
        layers=$(timeout 1 hyprctl layers -j 2>/dev/null \
            | jq -r '[..|.namespace? // empty | select(contains("hyprlock") or contains("session-lock"))] | length' 2>/dev/null \
            || echo 0)
        if [ "$layers" = "0" ]; then
            log "  lock_screen: zombie hyprlock detected — SIGKILL + relaunch"
            pkill -9 -x hyprlock 2>/dev/null
            sleep 0.2
        else
            log "  lock_screen: hyprlock already running with visible surface — skip"
            return 0
        fi
    fi

    if [ -x "$HOME/.local/bin/zen-lock.sh" ]; then
        setsid -f "$HOME/.local/bin/zen-lock.sh" </dev/null >/dev/null 2>&1 &
        log "  lock_screen: via zen-lock.sh wrapper"
    elif command -v hyprlock >/dev/null 2>&1; then
        setsid -f hyprlock >/dev/null 2>&1 &
        log "  lock_screen: via direct hyprlock"
    elif command -v swaylock >/dev/null 2>&1; then
        setsid -f swaylock -f >/dev/null 2>&1 &
        log "  lock_screen: via swaylock fallback"
    else
        log "  lock_screen: no lock binary found — DPMS off only"
        hyprctl dispatch dpms off >/dev/null 2>&1 || true
    fi
}

# ── v6.16.4: Pre-suspend health validation ──
# Run before any systemctl suspend call. Returns 0 (suspend OK) if
# everything looks healthy, non-zero if we should skip suspend and
# log a warning. The idea: never suspend a broken session, because
# waking from suspend when the session is already broken is the
# exact recipe for "force-power-off required".
#
# Checks:
#   1. hyprctl is responding to basic queries (compositor alive)
#   2. hyprlock is either running cleanly OR not running at all
#      (no zombie hyprlock — those cause the frozen-lock-on-wake
#      failure mode)
#
# If the check fails, caller should skip suspend and run recovery
# instead. But we don't force that — sometimes the user REALLY
# wants to suspend even from a broken state (e.g. going to sleep
# and planning to reboot after). Just logs a warning.
pre_suspend_healthcheck() {
    local healthy=0

    if ! timeout 1 hyprctl monitors >/dev/null 2>&1; then
        log "  pre-suspend: hyprctl unreachable — will suspend anyway"
        healthy=1
    fi

    if pgrep -x hyprlock >/dev/null 2>&1; then
        local layers
        layers=$(timeout 1 hyprctl layers -j 2>/dev/null \
            | jq -r '[..|.namespace? // empty | select(contains("hyprlock") or contains("session-lock"))] | length' 2>/dev/null \
            || echo 0)
        if [ "$layers" = "0" ]; then
            log "  pre-suspend: ⚠ zombie hyprlock detected before suspend — killing first"
            pkill -9 -x hyprlock 2>/dev/null
            sleep 0.2
        fi
    fi

    return $healthy
}

INTERNAL=$(detect_internal)

# Desktop / unknown hardware → no-op (safety net)
if [ -z "$INTERNAL" ]; then
    log "no internal display detected — exit"
    exit 0
fi

case "$ACTION" in
# ─────────────────────────────────────────────────────────────
# CLOSE
# ─────────────────────────────────────────────────────────────
close)
    EXT_COUNT=$(count_externals "$INTERNAL")

    # Save pre-close state for OPEN to compare against
    {
        echo "internal=$INTERNAL"
        echo "ext_count=$EXT_COUNT"
        echo "behavior=$BEHAVIOR"
        echo "on_ac=$(on_ac && echo 1 || echo 0)"
        echo "closed_at=$(date +%s)"
    } >"$STATE_FILE" 2>/dev/null

    log "close: behavior=$BEHAVIOR lid_action=$LID_ACTION ext=$EXT_COUNT internal=$INTERNAL"

    # v6.16.3.8: LID_ACTION early-dispatch.
    # When the user set lidCloseAction = "suspend" or "lock" in
    # Settings → Power, that ALWAYS wins — we fire lock/suspend
    # regardless of whether they're clamshelling with externals.
    # This matches the expectation "close lid → system goes to
    # sleep, on wake → lock screen" without any edge-case surprises.
    # BEHAVIOR (mirror/keep/off) still runs after, to handle the
    # monitor side, but for "suspend" it's moot since the system
    # is going to sleep anyway.
    if [ "$LID_ACTION" = "suspend" ]; then
        log "  → lid_action=suspend: lock + systemctl suspend"
        lock_screen
        sleep 0.3
        pre_suspend_healthcheck; command -v systemctl >/dev/null 2>&1 && systemctl suspend
        exit 0
    elif [ "$LID_ACTION" = "lock" ]; then
        log "  → lid_action=lock: lock only, no suspend"
        lock_screen
        # Continue to BEHAVIOR case for monitor handling (clamshell
        # still useful here — lock screen on internal is redundant
        # when you've got an external)
    fi
    # lid_action = "ignore" falls through to BEHAVIOR-only handling

    case "$BEHAVIOR" in
    keep)
        log "  → keep mode: no-op"
        exit 0
        ;;

    off)
        # Classic: always disable internal
        hyprctl keyword monitor "${INTERNAL},disable" >/dev/null 2>&1
        hyprctl reload >/dev/null 2>&1 || true
        log "  → off mode: disabled $INTERNAL"
        ;;

    mirror)
        # Legacy v6.16.0 behavior: disable internal if external,
        # else suspend.
        if [ "$EXT_COUNT" -eq 0 ]; then
            log "  → mirror + no external: suspend"
            pre_suspend_healthcheck; command -v systemctl >/dev/null 2>&1 && systemctl suspend
            exit 0
        fi
        hyprctl keyword monitor "${INTERNAL},disable" >/dev/null 2>&1
        hyprctl reload >/dev/null 2>&1 || true
        log "  → mirror + external: disabled $INTERNAL"
        ;;

    smart|*)
        # v6.16.3.2 NEW. Decide per context.
        if [ "$EXT_COUNT" -gt 0 ]; then
            # Clamshell mode — externals keep rendering
            hyprctl keyword monitor "${INTERNAL},disable" >/dev/null 2>&1
            hyprctl reload >/dev/null 2>&1 || true
            log "  → smart + external ($EXT_COUNT): clamshell, disabled $INTERNAL"
        elif on_ac; then
            # On AC, no external — lock + DPMS off, no suspend.
            # User wants quick wake when they reopen the lid for
            # an always-on workflow (e.g., long-running build).
            log "  → smart + no external + on AC: lock + dpms off"
            lock_screen
            sleep 0.3
            hyprctl dispatch dpms off >/dev/null 2>&1 || true
        else
            # On battery, no external — no point staying awake.
            # Lock first so on resume the user lands on lockscreen
            # (consistent UX with desktop suspend behavior).
            log "  → smart + no external + on battery: lock + suspend"
            lock_screen
            sleep 0.3
            pre_suspend_healthcheck; command -v systemctl >/dev/null 2>&1 && systemctl suspend
        fi
        ;;
    esac
    ;;

# ─────────────────────────────────────────────────────────────
# OPEN
# ─────────────────────────────────────────────────────────────
open)
    log "open: starting recovery pipeline"

    # Step 1 — Re-enable internal display with preferred mode.
    # If user's hyprland.conf has a custom monitor= line for
    # eDP-1, the reload below will reapply it.
    hyprctl keyword monitor "${INTERNAL},preferred,auto,1" >/dev/null 2>&1

    # Step 2 — Reload Hyprland config. Forces full monitor
    # re-enumeration which catches any externals that were
    # plugged/unplugged while the lid was closed (dock changes).
    hyprctl reload >/dev/null 2>&1 || true

    # Step 3 — Wait for the compositor to settle. 250ms covers
    # ~90% of hardware; AMD APUs sometimes need a touch longer.
    sleep 0.25

    # Step 4 — DRM kick via DPMS off→on cycle. This is THE fix
    # for "black screen on wake" — forces the GPU's display
    # engine to fully re-init each output, recovering from the
    # half-resumed state that Wayland compositors sometimes get
    # stuck in after a systemd suspend.
    hyprctl dispatch dpms off >/dev/null 2>&1 || true
    sleep 0.15
    hyprctl dispatch dpms on  >/dev/null 2>&1 || true

    # Step 5 — Resurrect swww-daemon. swww doesn't always survive
    # suspend; a stale daemon causes the wallpaper to never
    # repaint after wake. Cheap test: query — if it errors,
    # restart cleanly.
    if command -v swww >/dev/null 2>&1; then
        if ! swww query >/dev/null 2>&1; then
            log "  → swww-daemon stale, restarting"
            pkill -f 'swww-daemon' 2>/dev/null
            sleep 0.1
            if command -v swww-daemon >/dev/null 2>&1; then
                setsid -f swww-daemon </dev/null >/dev/null 2>&1 &
            else
                setsid -f swww init </dev/null >/dev/null 2>&1 &
            fi
            sleep 0.2
        fi
    fi

    # Step 6 — Kick hyprlock if it's running. Some hyprlock
    # versions zombie after suspend (process alive, surface not
    # repainting). SIGUSR1 = redraw signal in hyprlock 0.5+.
    # Older versions ignore it harmlessly.
    if pgrep -x hyprlock >/dev/null 2>&1; then
        log "  → hyprlock running, sending SIGUSR1"
        pkill -SIGUSR1 -x hyprlock 2>/dev/null || true
    fi

    # Step 7 — Force a render pass by hopping workspaces. This
    # is the belt-and-suspenders move that catches anything the
    # DPMS cycle missed.
    CUR_WS=$(hyprctl -j activeworkspace 2>/dev/null | \
        jq -r '.id' 2>/dev/null)
    if [ -n "$CUR_WS" ] && [ "$CUR_WS" != "null" ]; then
        # Bounce through ws 1 only if we're not already there
        if [ "$CUR_WS" != "1" ]; then
            hyprctl dispatch workspace 1     >/dev/null 2>&1 || true
            sleep 0.05
            hyprctl dispatch workspace "$CUR_WS" >/dev/null 2>&1 || true
        else
            hyprctl dispatch workspace 2     >/dev/null 2>&1 || true
            sleep 0.05
            hyprctl dispatch workspace 1     >/dev/null 2>&1 || true
        fi
    fi

    # Cleanup state file (close → open round trip complete)
    rm -f "$STATE_FILE" 2>/dev/null

    log "open: recovery complete"
    ;;

*)
    cat >&2 <<EOF
zen-lid-handler.sh v6.16.3.2

Usage: $0 {close|open}

Behavior is read from:
  ~/.config/quickshell/zen-shell/settings-state-v2.json
  → .system.lidCloseBehavior (smart|mirror|keep|off)

Default is "smart" if unset.

Logs to: ~/.cache/zen-shell/lid.log
State:   ~/.cache/zen-shell/lid-state
EOF
    exit 1
    ;;
esac
