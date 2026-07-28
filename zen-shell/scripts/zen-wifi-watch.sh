#!/usr/bin/env bash
# zen-wifi-watch — sit and wait for the wifi to drop, and record exactly what
#                  happened at the moment it happened.
#   v8.0.0-alpha-hf189 · Karui (軽い)
#
# WHY THIS EXISTS
# ───────────────
# Every diagnosis so far has been a reconstruction: the link goes down, and
# some time later we look at a journal and try to work backwards. That has
# been wrong at least once, because the reason a reconnect FAILS is not the
# same as the reason the link DROPPED, and they are easy to confuse when both
# are in the same scrollback.
#
# This watches live. Leave it running, go and do something else, and when the
# drop happens it writes down the state before, the transition itself, and
# what NetworkManager and the supplicant said in that exact window.
#
# Read-only. It runs no command that changes anything.
#
# USAGE
#   ./zen-wifi-watch.sh          # then just leave it. Ctrl-C when it has caught one.
#
# Everything lands in ~/zen-wifi-watch.log — send that file.

set -uo pipefail

LOG="${HOME:-/tmp}/zen-wifi-watch.log"
# If HOME is missing or unwritable, fall back rather than spraying a tee error
# on every single line — a diagnostic that floods its own output is useless.
mkdir -p "$(dirname "$LOG")" 2>/dev/null
if ! : > "$LOG" 2>/dev/null; then
    LOG="/tmp/zen-wifi-watch.log"
    : > "$LOG" 2>/dev/null || { echo "cannot write a log anywhere — aborting"; exit 1; }
    echo "note: writing to $LOG"
fi

say()  { printf '%s\n' "$*" | tee -a "$LOG"; }
stamp(){ date '+%H:%M:%S'; }

trap 'say ""; say "── stopped at $(stamp) ─────────────────────────────"; say "  Log saved: $LOG"; say "  Send that file."; exit 0' INT TERM

say "zen-wifi-watch · $(date -Iseconds)"
say "Leave this running. Ctrl-C once the wifi has dropped at least once."
say ""

WDEV="$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')"
if [ -z "$WDEV" ]; then say "!! no wifi device found — nothing to watch"; exit 1; fi

# ── Snapshot before anything moves ──────────────────────────────────────────
say "── SNAPSHOT ───────────────────────────────────"
say "  device      : $WDEV"
say "  driver      : $(basename "$(readlink -f /sys/class/net/$WDEV/device/driver 2>/dev/null)" 2>/dev/null)"
say "  power_save  : $(iw dev "$WDEV" get power_save 2>/dev/null | sed 's/.*: //')"
say "  power prof  : $(powerprofilesctl get 2>/dev/null || echo n/a)"
say "  regdom      : $(iw reg get 2>/dev/null | grep -m1 '^country' || echo unknown)"

PROF="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | grep -E ':(802-11-wireless|wifi)$' | sed -E 's/:(802-11-wireless|wifi)$//' | head -1)"
if [ -n "$PROF" ]; then
    say "  profile     : $PROF"
    for K in 802-11-wireless-security.key-mgmt 802-11-wireless-security.psk-flags \
             802-11-wireless-security.proto 802-11-wireless-security.pairwise \
             connection.autoconnect connection.autoconnect-retries \
             802-11-wireless.powersave 802-11-wireless.bssid \
             802-11-wireless.cloned-mac-address ipv4.route-metric; do
        V="$(nmcli -t -f "$K" connection show "$PROF" 2>/dev/null | cut -d: -f2-)"
        say "    $(printf '%-42s' "$K") ${V:-<unset>}"
    done
else
    say "  profile     : NONE SAVED"
fi
say ""
say "── WATCHING (transitions only) ────────────────"

# ── Live journal, filtered, in the background ───────────────────────────────
# --since now so we never replay old noise and mistake it for a fresh event.
( journalctl -f --since now -u NetworkManager -u wpa_supplicant --no-pager -o short-iso 2>/dev/null \
  | grep --line-buffered -iE "$WDEV|deauth|disassoc|4way|handshake|supplicant|secrets|psk|autoconnect|link is not ready|activation|state change" \
  | sed -u 's/^/  [journal] /' | tee -a "$LOG" ) &
JPID=$!
trap 'kill $JPID 2>/dev/null; say ""; say "── stopped at $(stamp) ────────────"; say "  Log saved: $LOG"; say "  Send that file."; exit 0' INT TERM

# ── Poll the device, log only on change ─────────────────────────────────────
# Initialised up front: under `set -u` an unbound variable is FATAL, and the
# only place these are read is the drop branch — so the watcher would die at
# exactly the moment it exists to record.
LAST=""
LASTSSID=""
BSSLAST=""
SIGLAST=""
DROPS=0
while true; do
    STATE="$(nmcli -t -f GENERAL.STATE device show "$WDEV" 2>/dev/null | cut -d: -f2-)"
    SSID="$(iw dev "$WDEV" link 2>/dev/null | grep -E '^\s*SSID:' | sed 's/.*SSID:[[:space:]]*//')"
    SIG="$(iw dev "$WDEV" link 2>/dev/null | grep -E '^\s*signal:' | sed 's/.*signal:[[:space:]]*//')"
    BSS="$(iw dev "$WDEV" link 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)"

    CUR="$STATE|$SSID|$BSS"
    if [ "$CUR" != "$LAST" ]; then
        if [ -n "$LAST" ] && [ -n "$LASTSSID" ] && [ -z "$SSID" ]; then
            DROPS=$((DROPS + 1))
            say ""
            say "  ██ $(stamp)  DROPPED  (#$DROPS)  was on '$LASTSSID' ${BSSLAST:-}"
            say "     last signal before the drop: ${SIGLAST:-unknown}"
            say "     device state now: ${STATE:-unknown}"
            say "     route now: $(ip route show default 2>/dev/null | head -1)"
        elif [ -n "$SSID" ] && [ -z "$LASTSSID" ]; then
            say "  ✓  $(stamp)  connected to '$SSID'  $BSS  $SIG"
        else
            say "  ·  $(stamp)  state='${STATE:-?}' ssid='${SSID:-none}' bssid='${BSS:-none}' $SIG"
        fi
        LAST="$CUR"
        LASTSSID="$SSID"
        BSSLAST="$BSS"
    fi
    [ -n "$SIG" ] && SIGLAST="$SIG"
    sleep 3
done
