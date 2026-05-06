#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Zen Shell — Hyprland Monitor Auto-Enable Watcher · v2 (stateful profiles)
# Path: ~/.local/bin/zen-monitor-watcher.sh
#
# WHAT THIS DOES (v2 stateful design)
#   Tracks unique combinations of connected outputs ("topologies") and saves
#   the per-monitor settings (mode, position, scale, transform, disabled flag)
#   for each one. When the topology changes (cable plugged/unplugged, lid
#   open/close, suspend/resume), the watcher:
#
#     1. Computes the topology key (sorted, joined list of connected outputs)
#     2. Looks up ~/.config/hypr/monitor-profiles/<key>.conf
#     3. If found → applies the profile via `hyprctl keyword monitor` per line
#     4. If not found → debounces 5s then auto-saves CURRENT state as the
#        profile for this topology (so next time you'll get the same layout)
#
#   This means: rotate Lenovo to 270° via nwg-displays, position ultrawide
#   right of it — within 5 seconds, that exact arrangement is saved as the
#   profile for this 2-monitor topology. Plug in laptop next time and a
#   *different* topology key triggers, with its own saved profile.
#
# COMPATIBILITY
#   Drop-in replacement for v1 watcher. Same systemd unit, same env file,
#   same SIGUSR1 hook for suspend/resume. Adds two new env vars:
#     ZEN_MONITOR_PROFILES_DIR  (default ~/.config/hypr/monitor-profiles)
#     ZEN_MONITOR_AUTOSAVE_SEC  (default 5 — autosave after this many seconds
#                                of monitor stability)
#
# THE BUG FIX FROM V1 STILL WORKS
#   Yun "0 externals + internal disabled = re-enable" rescue still fires —
#   but now it's encoded as a profile rule, not a hardcoded heuristic.
#   The profile for "eDP-1" alone topology will have eDP-1 enabled.
# ═══════════════════════════════════════════════════════════════════════════════

set -u

# ── Defaults (override via ~/.config/hypr/zen-monitor-watcher.env) ────────────
ZEN_MONITOR_INTERNAL="${ZEN_MONITOR_INTERNAL:-eDP-1}"
ZEN_MONITOR_INTERNAL_MODE="${ZEN_MONITOR_INTERNAL_MODE:-preferred,auto,1}"
ZEN_MONITOR_DISABLE_INTERNAL_ON_EXTERNAL="${ZEN_MONITOR_DISABLE_INTERNAL_ON_EXTERNAL:-0}"
ZEN_MONITOR_LOG="${ZEN_MONITOR_LOG:-/tmp/zen-monitor-watcher.log}"
ZEN_MONITOR_DEBOUNCE_MS="${ZEN_MONITOR_DEBOUNCE_MS:-200}"
ZEN_MONITOR_PROFILES_DIR="${ZEN_MONITOR_PROFILES_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitor-profiles}"
ZEN_MONITOR_AUTOSAVE_SEC="${ZEN_MONITOR_AUTOSAVE_SEC:-5}"

ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/zen-monitor-watcher.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

INTERNAL="$ZEN_MONITOR_INTERNAL"
LOG="$ZEN_MONITOR_LOG"
PROFILES_DIR="$ZEN_MONITOR_PROFILES_DIR"

mkdir -p "$PROFILES_DIR"

# ── Logger ────────────────────────────────────────────────────────────────────
: > "$LOG"
log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"
}

# ── Hyprland session sanity ───────────────────────────────────────────────────
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    log "FATAL: HYPRLAND_INSTANCE_SIGNATURE not set — not in a Hyprland session"
    exit 1
fi

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SOCK="$RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
[ ! -S "$SOCK" ] && SOCK="/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

if [ ! -S "$SOCK" ]; then
    log "FATAL: socket2 not found"
    exit 1
fi

for cmd in hyprctl jq socat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "FATAL: $cmd not installed"
        exit 1
    fi
done

log "Zen Monitor Watcher v2 (stateful) started"
log "  internal monitor:       $INTERNAL"
log "  internal fallback mode: $ZEN_MONITOR_INTERNAL_MODE"
log "  disable-on-ext:         $ZEN_MONITOR_DISABLE_INTERNAL_ON_EXTERNAL"
log "  profiles dir:           $PROFILES_DIR"
log "  autosave delay:         ${ZEN_MONITOR_AUTOSAVE_SEC}s"
log "  socket2:                $SOCK"

# ─────────────────────────────────────────────────────────────────────────────
# TOPOLOGY HELPERS
# ─────────────────────────────────────────────────────────────────────────────

# Sorted list of currently CONNECTED output names (regardless of enabled state).
# Hyprland's monitors -j only shows enabled ones, so we use `hyprctl monitors all -j`
# (the `all` flag includes disabled-but-connected outputs).
get_all_connected() {
    hyprctl monitors all -j 2>/dev/null | jq -r '.[].name' | sort -u
}

# Topology key: sorted output names joined with '+'.
# Examples:
#   "eDP-1"
#   "DP-2+HDMI-A-1"
#   "DP-2+HDMI-A-1+eDP-1"
get_topology_key() {
    get_all_connected | paste -sd '+' -
}

# Path to the profile file for the current topology
profile_path() {
    local key
    key=$(get_topology_key)
    # Sanitize: replace any chars that aren't safe filename chars with '_'
    # The output names from Hyprland are already filename-safe (DP-1, HDMI-A-1, eDP-1)
    # but we sanitize defensively.
    local safe="${key//[^a-zA-Z0-9+\-]/_}"
    echo "$PROFILES_DIR/${safe:-empty}.conf"
}

# ─────────────────────────────────────────────────────────────────────────────
# PROFILE I/O
# ─────────────────────────────────────────────────────────────────────────────

# Save current monitor state to the profile file for the current topology.
# Format: one `hyprctl keyword monitor <args>` per line, executable as bash.
save_profile() {
    local trigger="${1:-manual}"
    local file
    file=$(profile_path)
    local json
    json=$(hyprctl monitors all -j 2>/dev/null)
    [ -z "$json" ] && { log "  ✗ save_profile: hyprctl returned empty"; return 1; }

    {
        echo "# Auto-saved by zen-monitor-watcher [$trigger] at $(date)"
        echo "# Topology: $(get_topology_key)"
        echo "# Format: hyprctl keyword monitor <NAME>,<MODE>,<POSITION>,<SCALE>[,transform,N]"
        echo "# Disabled outputs: hyprctl keyword monitor <NAME>,disable"
        echo ""

        echo "$json" | jq -r --arg internal "$INTERNAL" '
            .[] |
            if .disabled == true then
                "hyprctl keyword monitor \(.name),disable"
            else
                # Build mode string: WIDTHxHEIGHT@RATEHz
                # If transform != 0, append ",transform,N"
                # Refresh rate from hyprctl is float; format to 2 decimals to match availableModes.
                "hyprctl keyword monitor \(.name),\(.width)x\(.height)@\(.refreshRate | tostring | .[:6])Hz,\(.x)x\(.y),\(.scale)" +
                (if .transform != 0 then ",transform,\(.transform)" else "" end) +
                (if .vrr == true then ",vrr,1" else "" end)
            end
        '
    } > "$file"

    log "  ✓ saved profile → $file"
    log "    contents:"
    sed 's/^/      /' "$file" | head -20 >> "$LOG"
}

# Apply profile for the current topology by sourcing its file.
# Returns 0 if a profile existed and was applied, 1 if no profile existed.
apply_profile() {
    local file
    file=$(profile_path)
    if [ ! -f "$file" ]; then
        log "  ⓘ no profile yet for this topology: $(get_topology_key)"
        return 1
    fi

    log "  → applying profile: $file"
    # Run each non-comment line. They're hyprctl commands, executed in series.
    local lcount=0
    while IFS= read -r line; do
        # Skip blanks and comments
        case "$line" in
            ''|\#*) continue ;;
        esac
        log "    $ $line"
        # shellcheck disable=SC2086
        eval "$line" >> "$LOG" 2>&1
        lcount=$((lcount + 1))
    done < "$file"
    log "  ✓ applied $lcount commands from profile"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# RESCUE FALLBACK (only when no profile + internal would be left disabled)
# ─────────────────────────────────────────────────────────────────────────────

count_externals_active() {
    hyprctl monitors -j 2>/dev/null | \
        jq -r --arg internal "$INTERNAL" \
        '[.[] | select(.name != $internal)] | length'
}

internal_is_active() {
    hyprctl monitors -j 2>/dev/null | \
        jq -r --arg internal "$INTERNAL" \
        '[.[] | select(.name == $internal)] | length' | grep -qx '1'
}

internal_is_connected_but_disabled() {
    # `hyprctl monitors all -j` includes disabled ones; check for entry with
    # name=$INTERNAL where .disabled == true
    hyprctl monitors all -j 2>/dev/null | \
        jq -e --arg internal "$INTERNAL" \
        '[.[] | select(.name == $internal and .disabled == true)] | length == 1' \
        >/dev/null 2>&1
}

rescue_internal_if_needed() {
    # Original v1 fix: if 0 externals AND internal is disabled, force-enable it.
    # We only do this if no profile applied (or profile didn't include eDP-1).
    if [ "$(count_externals_active)" -eq 0 ] && ! internal_is_active; then
        if internal_is_connected_but_disabled; then
            log "  ⚠ RESCUE: 0 externals + internal disabled. Force-enabling $INTERNAL"
            hyprctl keyword monitor "$INTERNAL,$ZEN_MONITOR_INTERNAL_MODE" >> "$LOG" 2>&1
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# RECONCILIATION (the main entry point)
# ─────────────────────────────────────────────────────────────────────────────

reconcile() {
    local trigger="${1:-manual}"
    local key
    key=$(get_topology_key)

    log ""
    log "RECONCILE [$trigger] topology=$key"

    if apply_profile; then
        # Profile existed — yun saved layout has been re-applied. Done.
        :
    else
        # No profile — let Hyprland's own monitorv2 fallback rule (in monitors.conf)
        # handle the layout, then save current state as the new profile after
        # autosave delay below. This is yun "first time at this topology" path.
        log "  → no profile, using monitorv2 fallback; will autosave in ${ZEN_MONITOR_AUTOSAVE_SEC}s"
        schedule_autosave
    fi

    # Always run the rescue check. Even if a profile applied, if it ended up
    # leaving internal disabled while 0 externals are active, the rescue saves us.
    rescue_internal_if_needed
}

# ─────────────────────────────────────────────────────────────────────────────
# AUTOSAVE TIMER
# ─────────────────────────────────────────────────────────────────────────────
# Tracks a "stability timer" — when the topology stabilizes (no events for
# AUTOSAVE_SEC seconds), the current state is auto-saved as the profile for
# the current topology. Implemented via a marker file timestamp + a separate
# wakeup loop checking it every second.

AUTOSAVE_MARKER="/tmp/zen-monitor-watcher.autosave.${HYPRLAND_INSTANCE_SIGNATURE}"

schedule_autosave() {
    # Touch marker to "now + AUTOSAVE_SEC". The autosave_loop checks every
    # second whether the marker is in the past and triggers save when so.
    date +%s | awk -v delay="$ZEN_MONITOR_AUTOSAVE_SEC" '{ print $1 + delay }' > "$AUTOSAVE_MARKER"
}

cancel_autosave() {
    rm -f "$AUTOSAVE_MARKER"
}

autosave_loop() {
    while true; do
        sleep 1
        if [ -f "$AUTOSAVE_MARKER" ]; then
            local target now
            target=$(cat "$AUTOSAVE_MARKER" 2>/dev/null || echo 0)
            now=$(date +%s)
            if [ "$now" -ge "$target" ]; then
                rm -f "$AUTOSAVE_MARKER"
                log "AUTOSAVE timer fired"
                save_profile "autosave"
            fi
        fi
    done
}

# Also: schedule autosave on EVERY reconcile (even when profile applied) so
# manual edits via nwg-displays / Zen Shell Settings get captured. This is
# safe because save_profile() is idempotent — it's just rewriting the file.

# ─────────────────────────────────────────────────────────────────────────────
# MANUAL SIGNAL HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

# SIGUSR1 = post-resume hook (sent by zen-monitor-resume.service)
on_sigusr1() {
    log ""
    log "SIGUSR1 received (post-resume hook)"
    sleep 0.5
    reconcile "post-resume"
}
trap on_sigusr1 USR1

# SIGUSR2 = manual save trigger (you can wire a keybind to:
#   pkill -USR2 -f zen-monitor-watcher.sh
# to force-save the current state right now without waiting for autosave)
on_sigusr2() {
    log ""
    log "SIGUSR2 received (manual save trigger)"
    save_profile "manual-trigger"
}
trap on_sigusr2 USR2

# SIGHUP = clear all profiles + re-reconcile (factory reset for the current
# session). Send via:  pkill -HUP -f zen-monitor-watcher.sh
on_sighup() {
    log ""
    log "SIGHUP received (clearing all profiles)"
    rm -f "$PROFILES_DIR"/*.conf
    reconcile "post-clear"
}
trap on_sighup HUP

# ─────────────────────────────────────────────────────────────────────────────
# STARTUP + AUTOSAVE LOOP IN BACKGROUND
# ─────────────────────────────────────────────────────────────────────────────

# Initial reconcile on startup
reconcile "startup"

# Schedule autosave after startup so first-boot state gets captured
schedule_autosave

# Start autosave loop in background
autosave_loop &
AUTOSAVE_PID=$!
log "autosave loop started as PID $AUTOSAVE_PID"

# Make sure we kill the autosave loop on exit
cleanup() {
    [ -n "${AUTOSAVE_PID:-}" ] && kill "$AUTOSAVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
# MAIN EVENT LOOP — subscribe to Hyprland socket2
# ─────────────────────────────────────────────────────────────────────────────

log ""
log "Subscribing to socket2..."

# Note: not exec'ing this time because we have the autosave loop in bg
socat -U - "UNIX-CONNECT:$SOCK" 2>>"$LOG" | while IFS= read -r line; do
    event="${line%%>>*}"
    payload="${line#*>>}"

    case "$event" in
        monitoradded|monitoraddedv2|monitorremoved|monitorremovedv2)
            case "$event" in
                *v2)
                    name="${payload#*,}"; name="${name%%,*}"
                    ;;
                *)
                    name="$payload"
                    ;;
            esac
            log ""
            log "EVENT: $event for monitor '$name'"

            # Debounce — wait for Hyprland to finish updating internal state
            sleep "$(awk "BEGIN { print $ZEN_MONITOR_DEBOUNCE_MS / 1000 }")"
            reconcile "$event:$name"

            # Always (re)schedule autosave after a topology change so manual
            # adjustments after the auto-applied profile also get saved
            schedule_autosave
            ;;
        *)
            # Ignore workspace/window/keyboard/etc events
            ;;
    esac
done
