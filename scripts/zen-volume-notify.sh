#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-volume-notify.sh v6.16.0
# ────────────────────────────────────────────────────────────────
# Change volume / brightness / mute and emit a swaync notification
# with a progress bar. Replaces the bare `wpctl`/`brightnessctl`
# calls in keybinds-update.conf so the user gets visual feedback
# on every XF86 key press.
#
# Usage:
#   zen-volume-notify.sh vol-up       # +5%
#   zen-volume-notify.sh vol-down     # -5%
#   zen-volume-notify.sh vol-mute     # toggle mute
#   zen-volume-notify.sh bright-up    # +5%
#   zen-volume-notify.sh bright-down  # -5%
#
# Notifications use the SAME tag+replaces_id (via -h string:synchronous:...)
# pattern so swaync collapses repeated volume changes into a single
# updating notification instead of spamming the history. This is the
# standard pattern used by dunst/mako/swaync — called "synchronous"
# or "transient" notifications.
# ════════════════════════════════════════════════════════════════

set -u

ACTION="${1:-}"
STEP="${2:-5}"

# ──────────────────────────────────────────────────────────────
# Early exit: if notify-send isn't available, still perform the
# action but skip the notification. This keeps the script useful
# on minimal systems.
# ──────────────────────────────────────────────────────────────
HAS_NOTIFY=0
command -v notify-send >/dev/null 2>&1 && HAS_NOTIFY=1

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────
progress_bar() {
    # Draw a 20-char progress bar for the given percentage.
    local pct="$1"
    local filled=$((pct / 5))
    [ "$filled" -gt 20 ] && filled=20
    [ "$filled" -lt 0 ] && filled=0
    local empty=$((20 - filled))
    printf '['
    printf '%0.s■' $(seq 1 "$filled" 2>/dev/null)
    printf '%0.s□' $(seq 1 "$empty" 2>/dev/null)
    printf ']'
}

notify() {
    local title="$1" body="$2" icon="$3" pct="$4" tag="$5"
    [ "$HAS_NOTIFY" = "0" ] && return 0
    # -h string:x-canonical-private-synchronous:<tag>  → collapses
    #   repeated notifs with the same tag into one updating entry.
    # -t 1800 → auto-dismiss after 1.8 seconds.
    # -h int:value:<pct> → some notification daemons (dunst, swaync
    #   with progress bar support) render a real progress bar from this.
    if [ -n "$pct" ]; then
        notify-send \
            -a "Zen Shell" \
            -i "$icon" \
            -t 1800 \
            -h "string:x-canonical-private-synchronous:$tag" \
            -h "int:value:$pct" \
            "$title" "$body"
    else
        notify-send \
            -a "Zen Shell" \
            -i "$icon" \
            -t 1800 \
            -h "string:x-canonical-private-synchronous:$tag" \
            "$title" "$body"
    fi
}

# ──────────────────────────────────────────────────────────────
# v7.0.0-beta.1-hf18: Sound effect helper.
#
# Reads the zen-shell sound-effects.json config and plays the
# freedesktop "audio-volume-change" tick if BOTH the master toggle
# AND the volume sub-toggle are enabled.
#
# Why bash and not QML? XF86 keys hit wpctl directly; our QML poll
# is 3s, so going via SoundEffectsService.play() would have a
# ~3-second delay before the tick. Calling canberra-gtk-play right
# here makes the tick instant (~5ms after keypress).
#
# Single source of truth: same JSON config the QML side reads.
# Toggle off in Settings → no script-side sounds either.
# ──────────────────────────────────────────────────────────────
SOUND_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/zen-shell/sound-effects.json"

play_volume_tick() {
    # Bail if canberra not installed (no error spam)
    command -v canberra-gtk-play >/dev/null 2>&1 || return 0

    # Read config; default ON if file missing or unreadable
    local enabled=true volEnabled=true vol="0.6"
    if [ -f "$SOUND_CONFIG" ] && command -v python3 >/dev/null 2>&1; then
        local parsed
        parsed=$(python3 -c "
import json
try:
    with open('$SOUND_CONFIG') as f: d = json.load(f)
    print(str(d.get('enabled', True)).lower())
    print(str(d.get('playVolumeSounds', True)).lower())
    print(d.get('volume', 0.6))
except Exception: pass
" 2>/dev/null)
        if [ -n "$parsed" ]; then
            enabled=$(echo "$parsed"    | sed -n '1p')
            volEnabled=$(echo "$parsed" | sed -n '2p')
            vol=$(echo "$parsed"        | sed -n '3p')
        fi
    fi

    [ "$enabled"    = "true" ] || return 0
    [ "$volEnabled" = "true" ] || return 0

    canberra-gtk-play \
        -i audio-volume-change \
        --property=canberra.volume="$vol" \
        2>/dev/null &
}

# ──────────────────────────────────────────────────────────────
# Volume helpers (wpctl — PipeWire)
# ──────────────────────────────────────────────────────────────
get_volume() {
    # Output format: "Volume: 0.55 [MUTED]"
    local line
    line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    local vol
    vol=$(echo "$line" | awk '{print $2}')
    # Convert 0.55 → 55
    if [ -n "$vol" ]; then
        awk -v v="$vol" 'BEGIN { printf "%d", v * 100 }'
    else
        echo "0"
    fi
}

is_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q 'MUTED'
}

# ──────────────────────────────────────────────────────────────
# Brightness helpers (brightnessctl)
# ──────────────────────────────────────────────────────────────
get_brightness() {
    if ! command -v brightnessctl >/dev/null 2>&1; then
        echo "0"; return
    fi
    local cur max
    cur=$(brightnessctl g 2>/dev/null || echo 0)
    max=$(brightnessctl m 2>/dev/null || echo 1)
    [ "$max" -eq 0 ] && max=1
    awk -v c="$cur" -v m="$max" 'BEGIN { printf "%d", c * 100 / m }'
}

# ──────────────────────────────────────────────────────────────
# Actions
# ──────────────────────────────────────────────────────────────
case "$ACTION" in
    vol-up)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${STEP}%+" 2>/dev/null
        play_volume_tick
        pct=$(get_volume)
        bar=$(progress_bar "$pct")
        icon="audio-volume-high"
        [ "$pct" -lt 67 ] && icon="audio-volume-medium"
        [ "$pct" -lt 34 ] && icon="audio-volume-low"
        notify "Volume" "${pct}%  ${bar}" "$icon" "$pct" "zen-volume"
        ;;
    vol-down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}%-" 2>/dev/null
        play_volume_tick
        pct=$(get_volume)
        bar=$(progress_bar "$pct")
        icon="audio-volume-high"
        [ "$pct" -lt 67 ] && icon="audio-volume-medium"
        [ "$pct" -lt 34 ] && icon="audio-volume-low"
        [ "$pct" -eq 0 ]   && icon="audio-volume-muted"
        notify "Volume" "${pct}%  ${bar}" "$icon" "$pct" "zen-volume"
        ;;
    vol-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null
        play_volume_tick
        if is_muted; then
            notify "Volume" "Muted" "audio-volume-muted" "" "zen-volume"
        else
            pct=$(get_volume)
            bar=$(progress_bar "$pct")
            notify "Volume" "Unmuted · ${pct}%  ${bar}" "audio-volume-high" "$pct" "zen-volume"
        fi
        ;;
    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; then
            notify "Microphone" "Muted" "microphone-sensitivity-muted" "" "zen-mic"
        else
            notify "Microphone" "Unmuted" "microphone-sensitivity-high" "" "zen-mic"
        fi
        ;;
    bright-up)
        brightnessctl set "+${STEP}%" >/dev/null 2>&1
        pct=$(get_brightness)
        bar=$(progress_bar "$pct")
        notify "Brightness" "${pct}%  ${bar}" "display-brightness" "$pct" "zen-bright"
        ;;
    bright-down)
        brightnessctl set "${STEP}%-" >/dev/null 2>&1
        pct=$(get_brightness)
        bar=$(progress_bar "$pct")
        notify "Brightness" "${pct}%  ${bar}" "display-brightness" "$pct" "zen-bright"
        ;;
    *)
        echo "zen-volume-notify.sh v6.16.0" >&2
        echo "Usage: $0 {vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down} [step]" >&2
        exit 1
        ;;
esac
