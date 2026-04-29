#!/usr/bin/env bash
# zen-monitor-watcher.sh — v6.16.4.12.6.11 (Hikari)
#
# Smart per-topology monitor manager for Hyprland. Solves three things:
#
#   1. AUTO-RECOVERY: nung naka-disable yun internal display (laptop) tapos
#      tinanggal mo yun external monitor, walang display kasi disabled pa
#      yun internal — black screen panic. Watcher detects "0 monitors
#      enabled" and force-enables the configured MAIN monitor, with a
#      notify-send warning.
#
#   2. PER-TOPOLOGY MEMORY: nung gagamitin mo ulit yun extended setup
#      (laptop + external), automatically i-restore yun saved config —
#      including the "eDP-1=disabled" preference if that's how you
#      configured it the last time. Each unique combination of connected
#      monitors gets its own remembered state file. Lab + Tibay setup sa
#      bahay = 2 different states, awtomatik silang nag-aapply pag-konek.
#
#   3. SAFETY GUARD (desktop + laptop): hindi pwedeng ma-disable LAHAT ng
#      monitors at any point. Kung subukang gawin (whether intentionally
#      via nwg-displays / hyprctl, or by an applied saved state going
#      stale), mag-force-enable yun MAIN. Atleast isa always alive.
#
# Mental model:
#   topology = sorted set of CONNECTED monitor names ("eDP-1+HDMI-A-1")
#   state    = per-monitor config (enabled/disabled + resolution+pos+scale)
#   memory   = $STATE_DIR/topology-<key>.json per unique topology
#   reconcile = on event, apply saved state if any, then enforce safety
#   snapshot = 10s after stability, capture current state to memory
#
# Usage:
#   zen-monitor-watcher.sh              # daemon mode (default, used by systemd)
#   zen-monitor-watcher.sh status       # show current topology + saved state
#   zen-monitor-watcher.sh snapshot     # save current state RIGHT NOW
#   zen-monitor-watcher.sh list         # list all saved topologies
#   zen-monitor-watcher.sh clear KEY    # forget a specific saved topology
#
# Configuration via env (override in ~/.config/hypr/zen-monitor-watcher.env):
#
#   ZEN_MONITOR_MAIN              - the "always-on" fallback monitor.
#                                   For laptops: eDP-1 (default).
#                                   For desktops: pick your primary display
#                                                 (e.g. "DP-1" or "HDMI-A-1").
#   ZEN_MONITOR_INTERNAL          - alias for ZEN_MONITOR_MAIN (back-compat
#                                   with v6.16.4.12.6.10).
#   ZEN_MONITOR_FALLBACK_MODE     - mode used when force-enabling MAIN
#                                   (default: preferred,auto,1)
#   ZEN_MONITOR_STATE_DIR         - where state files live (default:
#                                   ~/.config/hypr/zen-monitor-states/)
#   ZEN_MONITOR_LOG               - log file (default: /tmp/zen-monitor-watcher.log)
#   ZEN_MONITOR_SNAPSHOT_DELAY    - debounce seconds before auto-snapshot
#                                   (default: 10)
#   ZEN_MONITOR_NOTIFY            - notify-send on safety override (default: 1)
#
# Wala tayo babawasan: never edits hyprland.conf. Only issues live
# `hyprctl keyword monitor` commands. Reboot returns to your config's
# baseline; the watcher then reconciles from saved state.

set -euo pipefail

# ── load optional env file ─────────────────────────────────────────────
ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/zen-monitor-watcher.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    . "$ENV_FILE"
fi

MAIN_MONITOR="${ZEN_MONITOR_MAIN:-${ZEN_MONITOR_INTERNAL:-eDP-1}}"
FALLBACK_MODE="${ZEN_MONITOR_FALLBACK_MODE:-${ZEN_MONITOR_INTERNAL_MODE:-preferred,auto,1}}"
STATE_DIR="${ZEN_MONITOR_STATE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/zen-monitor-states}"
LOG="${ZEN_MONITOR_LOG:-/tmp/zen-monitor-watcher.log}"
SNAPSHOT_DELAY="${ZEN_MONITOR_SNAPSHOT_DELAY:-10}"
NOTIFY="${ZEN_MONITOR_NOTIFY:-1}"

# In-process state
SNAPSHOT_PID=""

# ── logging ────────────────────────────────────────────────────────────
log() {
    local ts; ts=$(date +'%H:%M:%S')
    printf '[%s] %s\n' "$ts" "$*" | tee -a "$LOG" >&2
}

notify_user() {
    [ "$NOTIFY" = "1" ] || return 0
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -u normal -i video-display "Zen Monitor Watcher" "$*" 2>/dev/null || true
}

# ── topology + state primitives ────────────────────────────────────────

# Sorted comma-separated list of CONNECTED monitor names (enabled OR disabled
# but physically present). Used as the canonical topology fingerprint.
current_topology() {
    hyprctl monitors all -j 2>/dev/null \
        | jq -r '.[].name' 2>/dev/null \
        | sort | paste -sd ',' || echo ""
}

# Filesystem-safe key derived from topology string (lowercase, only [a-z0-9-])
topology_key() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

state_file_for() {
    local key; key=$(topology_key "$1")
    echo "$STATE_DIR/topology-${key}.json"
}

# Capture current full monitor state as JSON.
# Returns: { name: { enabled, width, height, refresh, x, y, scale, transform }, ... }
# A monitor is "enabled" iff it appears in `hyprctl monitors` (active list).
# Disabled monitors only appear in `hyprctl monitors all`.
current_state_json() {
    local all active
    all=$(hyprctl monitors all -j 2>/dev/null) || return 1
    active=$(hyprctl monitors -j 2>/dev/null) || return 1
    jq -n --argjson all "$all" --argjson active "$active" '
        ($active | map({(.name): true}) | add // {}) as $on
        | $all | map({
            key: .name,
            value: {
                enabled: ($on[.name] // false),
                width:   .width,
                height:  .height,
                refresh: .refreshRate,
                x:       .x,
                y:       .y,
                scale:   .scale,
                transform: (.transform // 0)
            }
        }) | from_entries
    '
}

count_enabled() {
    hyprctl monitors -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0
}

monitor_is_connected() {
    local name="$1"
    hyprctl monitors all -j 2>/dev/null \
        | jq -e --arg n "$name" '.[] | select(.name == $n)' >/dev/null 2>&1
}

# Effective MAIN: configured value if connected, else fallback to the first
# connected monitor by lexical sort. Returns empty if literally nothing is
# connected.
effective_main() {
    if [ -n "$MAIN_MONITOR" ] && monitor_is_connected "$MAIN_MONITOR"; then
        echo "$MAIN_MONITOR"; return
    fi
    hyprctl monitors all -j 2>/dev/null | jq -r '.[].name' | sort | head -n1
}

# ── safety: never permit 0 enabled monitors ────────────────────────────
safety_check() {
    local enabled; enabled=$(count_enabled)
    if [ "$enabled" -ge 1 ]; then
        return 0
    fi
    local main; main=$(effective_main)
    if [ -z "$main" ]; then
        log "[safety] CRITICAL: 0 enabled and no candidate monitor"
        notify_user "No monitors detected — cannot recover automatically"
        return 1
    fi
    log "[safety] 0 enabled — force-enabling '$main' with mode '$FALLBACK_MODE'"
    hyprctl keyword monitor "$main,$FALLBACK_MODE" >>"$LOG" 2>&1 || true
    notify_user "Re-enabled '$main' (at least one display must remain on)"
}

# ── apply: restore a saved state for the current topology ──────────────
# Validates that at least one CONNECTED monitor will be enabled before
# applying — otherwise skips and lets safety_check handle recovery.
apply_state() {
    local state_json="$1"
    local connected_arr
    connected_arr=$(hyprctl monitors all -j | jq -c '[.[].name]')

    # Count how many monitors in saved state are: (a) flagged enabled AND
    # (b) currently physically connected.
    local n_will_be_on
    n_will_be_on=$(echo "$state_json" | jq --argjson c "$connected_arr" '
        [ to_entries[]
          | select(.value.enabled == true)
          | select(.key as $n | $c | index($n) != null) ]
        | length
    ')

    if [ "$n_will_be_on" -lt 1 ]; then
        log "[apply] saved state would leave 0 enabled — refusing (safety_check will recover)"
        return 1
    fi

    log "[apply] restoring state — $n_will_be_on monitor(s) will be enabled"

    # Iterate entries safely (use a temp file to avoid subshell scoping)
    local tmp; tmp=$(mktemp)
    echo "$state_json" | jq -c 'to_entries[]' >"$tmp"
    while IFS= read -r entry; do
        local name enabled
        name=$(echo "$entry" | jq -r '.key')
        enabled=$(echo "$entry" | jq -r '.value.enabled')

        if ! monitor_is_connected "$name"; then
            log "  skip $name (not currently connected)"
            continue
        fi

        if [ "$enabled" = "false" ]; then
            log "  → $name disable"
            hyprctl keyword monitor "$name,disable" >>"$LOG" 2>&1 || true
        else
            local w h r x y s
            w=$(echo "$entry" | jq -r '.value.width')
            h=$(echo "$entry" | jq -r '.value.height')
            r=$(echo "$entry" | jq -r '.value.refresh' \
                | awk '{ if ($1+0 > 0) printf "%.3f", $1; else printf "60.000" }')
            x=$(echo "$entry" | jq -r '.value.x')
            y=$(echo "$entry" | jq -r '.value.y')
            s=$(echo "$entry" | jq -r '.value.scale')
            log "  → $name ${w}x${h}@${r} pos=${x}x${y} scale=${s}"
            hyprctl keyword monitor "$name,${w}x${h}@${r},${x}x${y},${s}" >>"$LOG" 2>&1 || true
        fi
    done <"$tmp"
    rm -f "$tmp"
}

# ── reconcile: load saved state for current topology, apply, then safety
reconcile() {
    local trigger="${1:-manual}"
    local topo; topo=$(current_topology)
    log "[reconcile] trigger=$trigger topology='$topo'"

    if [ -z "$topo" ]; then
        log "[reconcile] empty topology — nothing to do"
        return
    fi

    local file; file=$(state_file_for "$topo")
    if [ -f "$file" ]; then
        log "[reconcile] saved state found: $(basename "$file")"
        local state; state=$(cat "$file")
        if echo "$state" | jq empty 2>/dev/null; then
            apply_state "$state" || true
        else
            log "[reconcile] saved state malformed — ignoring (run 'snapshot' to overwrite)"
        fi
    else
        log "[reconcile] no saved state for this topology yet"
    fi

    # ALWAYS run safety check, regardless of whether apply succeeded.
    safety_check
}

# ── snapshot: capture current state, debounced ─────────────────────────
snapshot_now() {
    local topo; topo=$(current_topology)
    if [ -z "$topo" ]; then
        log "[snapshot] empty topology — skip"
        return
    fi
    mkdir -p "$STATE_DIR"
    local file; file=$(state_file_for "$topo")
    local current; current=$(current_state_json)

    if [ -z "$current" ]; then
        log "[snapshot] failed to read current state"
        return
    fi

    # Skip write if state matches what's already saved (avoid noise + spurious
    # mtime updates that confuse log-watchers)
    if [ -f "$file" ]; then
        if diff -q <(echo "$current" | jq -S .) <(jq -S . <"$file") >/dev/null 2>&1; then
            log "[snapshot] no change for '$topo' — skip write"
            return
        fi
        log "[snapshot] updating saved state for '$topo'"
    else
        log "[snapshot] FIRST capture for topology '$topo'"
        notify_user "Captured monitor preference for current setup"
    fi

    echo "$current" | jq . >"$file"
    log "[snapshot] saved: $file"
}

schedule_snapshot() {
    if [ -n "$SNAPSHOT_PID" ] && kill -0 "$SNAPSHOT_PID" 2>/dev/null; then
        kill "$SNAPSHOT_PID" 2>/dev/null || true
        log "  cancelled pending snapshot pid=$SNAPSHOT_PID"
    fi
    (
        sleep "$SNAPSHOT_DELAY"
        snapshot_now
    ) &
    SNAPSHOT_PID=$!
    log "  snapshot scheduled in ${SNAPSHOT_DELAY}s pid=$SNAPSHOT_PID"
}

# ── CLI subcommands ────────────────────────────────────────────────────

cmd_snapshot() {
    log "[manual] snapshot requested via CLI"
    snapshot_now
}

cmd_status() {
    local topo; topo=$(current_topology)
    echo "── Zen Monitor Watcher status ──"
    echo "Current topology    : ${topo:-<none>}"
    echo "Topology key        : $(topology_key "$topo")"
    echo "Configured MAIN     : $MAIN_MONITOR"
    echo "Effective MAIN      : $(effective_main)"
    echo "Enabled count       : $(count_enabled)"
    echo "State directory     : $STATE_DIR"
    echo "Log file            : $LOG"
    echo ""
    local file; file=$(state_file_for "$topo")
    if [ -f "$file" ]; then
        echo "── Saved state for current topology ──"
        echo "File: $file"
        echo ""
        cat "$file"
    else
        echo "(no saved state for this topology yet)"
    fi
}

cmd_list() {
    if [ ! -d "$STATE_DIR" ] || [ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
        echo "No saved topologies yet."
        echo "(They get auto-captured ${SNAPSHOT_DELAY}s after each plug/unplug event.)"
        return
    fi
    echo "── Saved monitor topologies ──"
    local current_key; current_key=$(topology_key "$(current_topology)")
    for f in "$STATE_DIR"/topology-*.json; do
        [ -f "$f" ] || continue
        local key; key=$(basename "$f" .json | sed 's/^topology-//')
        local marker=""
        [ "$key" = "$current_key" ] && marker=" ← current"
        echo "  $key$marker"
    done
    echo ""
    echo "Use:  zen-monitor-watcher.sh clear KEY  — to forget a topology"
}

cmd_clear() {
    local key="${1:-}"
    if [ -z "$key" ]; then
        echo "Usage: $0 clear <topology-key>"
        echo "Run '$0 list' to see saved topologies."
        exit 1
    fi
    local file="$STATE_DIR/topology-${key}.json"
    if [ -f "$file" ]; then
        rm "$file"
        echo "Removed: $file"
    else
        echo "Not found: $file"
        exit 1
    fi
}

# ── daemon mode ────────────────────────────────────────────────────────
cmd_daemon() {
    for cmd in hyprctl jq socat; do
        command -v "$cmd" >/dev/null 2>&1 || {
            echo "[zen-monitor-watcher] missing required: $cmd" >&2
            exit 1
        }
    done

    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        echo "[zen-monitor-watcher] HYPRLAND_INSTANCE_SIGNATURE not set — exiting" >&2
        exit 1
    fi

    local sock="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
    if [ ! -S "$sock" ]; then
        echo "[zen-monitor-watcher] socket2.sock not found at $sock" >&2
        exit 1
    fi

    : > "$LOG"
    log "═══ zen-monitor-watcher v6.16.4.12.6.11 starting ═══"
    log "MAIN_MONITOR=$MAIN_MONITOR  FALLBACK_MODE=$FALLBACK_MODE"
    log "STATE_DIR=$STATE_DIR"
    log "SNAPSHOT_DELAY=${SNAPSHOT_DELAY}s  NOTIFY=$NOTIFY"
    log "Socket: $sock"

    # Initial reconcile — handles the "rebooted in laptop-only mode after
    # docking session that disabled internal" recovery scenario.
    reconcile "startup"
    # Don't auto-snapshot at startup — let the user configure first.

    # Cleanup on exit
    trap 'if [ -n "$SNAPSHOT_PID" ]; then kill "$SNAPSHOT_PID" 2>/dev/null || true; fi' EXIT

    log "subscribing to socket2 events..."
    while IFS= read -r line; do
        local event payload name
        event="${line%%>>*}"
        payload="${line#*>>}"
        case "$event" in
            monitoradded|monitorremoved)
                name="$payload"
                ;;
            monitoraddedv2|monitorremovedv2)
                # v2 format: ID,NAME,DESCRIPTION
                name="${payload#*,}"; name="${name%%,*}"
                ;;
            *)
                continue
                ;;
        esac
        log ""
        log "── event: $event '$name' ──"
        # Brief settle so hyprland's internal monitor list is up-to-date
        sleep 0.2
        reconcile "$event:$name"
        schedule_snapshot
    done < <(socat -U - "UNIX-CONNECT:$sock" 2>>"$LOG")
}

# ── entry point ────────────────────────────────────────────────────────
case "${1:-daemon}" in
    snapshot|--snapshot)         cmd_snapshot ;;
    status|--status)             cmd_status ;;
    list|--list|ls)              cmd_list ;;
    clear|--clear|forget)        cmd_clear "${2:-}" ;;
    daemon|--daemon|"")          cmd_daemon ;;
    -h|--help|help)
        cat <<EOF
zen-monitor-watcher.sh — smart Hyprland monitor manager

USAGE:
  zen-monitor-watcher.sh                      run as daemon (used by systemd)
  zen-monitor-watcher.sh snapshot             save current state for current topology
  zen-monitor-watcher.sh status               show topology + saved state
  zen-monitor-watcher.sh list                 list saved topologies
  zen-monitor-watcher.sh clear KEY            forget a topology

CONFIG (env, set in ~/.config/hypr/zen-monitor-watcher.env):
  ZEN_MONITOR_MAIN=eDP-1                      always-on fallback monitor
  ZEN_MONITOR_FALLBACK_MODE=preferred,auto,1  mode for force-enable
  ZEN_MONITOR_STATE_DIR=~/.config/hypr/zen-monitor-states
  ZEN_MONITOR_SNAPSHOT_DELAY=10               auto-snapshot debounce (s)
  ZEN_MONITOR_NOTIFY=1                        notify-send on safety override

LOG:
  $LOG
EOF
        ;;
    *)
        echo "Unknown command: $1 (try --help)" >&2
        exit 1
        ;;
esac
