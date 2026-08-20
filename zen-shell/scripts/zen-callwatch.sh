#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# zen-callwatch v2 — v8.1.0-alpha-hf197
#
# Closes ORPHANED call popups (Zoom / Teams / Lark / Workvivo floating
# windows that stay on screen after a call and stop answering clicks).
#
# ── WHY A v2 ──────────────────────────────────────────────────────────
# The hf196 daemon closed a call window on ANY title transition. That
# also fired when you:
#   - clicked End Call            → the post-call prompt (rating, "leave
#                                    meeting?" confirm) got closewindow'd
#                                    before you could click anything
#   - opened video/audio settings → some clients retitle the window
#                                    mid-call → closewindow'd DURING a call
#
# v2 rules — a window is only closed when ALL of these hold:
#   1. Its class matches a known call app (CALL_CLASSES below)
#   2. Its title matched an ENDED pattern (call over), not just "changed"
#   3. A grace period (default 25s) has fully elapsed since the match
#   4. The window was NOT focused at any point during the grace period
#      (focus = the user is interacting — post-call prompt, settings, etc.)
#   5. The window still exists and its title STILL matches ended/blank
#
# Manual escape hatch: `zen-callwatch.sh close` (bound to SUPER+SHIFT+C)
# closes any matching call popup that is not currently focused — instant,
# no grace. That's for the genuinely frozen ones.
#
# `hyprctl dispatch closewindow` is still the close mechanism: it's
# handled by the app's MAIN process, so it reaches a window whose render
# process has frozen (the hf196 key insight — that part was right).
#
# Wala tayong babawasan — the hf196 feature survives, it just stopped
# eating your post-call prompts.
# ═══════════════════════════════════════════════════════════════════════

set -u

# ── Tunables (env-overridable) ────────────────────────────────────────
GRACE_SECS="${ZEN_CALLWATCH_GRACE:-25}"
# Window classes that host call popups. Regex, case-insensitive.
CALL_CLASSES="${ZEN_CALLWATCH_CLASSES:-zoom|Zoom|us.zoom|teams|Teams|teams-for-linux|Lark|lark|bytedance|Workvivo|workvivo}"
# Title patterns that mean "the call is OVER" — only these arm the timer.
# A title merely CHANGING (settings opened, participant joined) does not.
ENDED_TITLES="${ZEN_CALLWATCH_ENDED:-meeting ended|call ended|left the meeting|you left|has ended|通話終了|会議は終了}"

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"
SOCK="$RUNTIME/hypr/$SIG/.socket2.sock"

log() { echo "[zen-callwatch] $*" >&2; }

# ── helpers ───────────────────────────────────────────────────────────
win_json()      { hyprctl clients -j 2>/dev/null; }
focused_addr()  { hyprctl activewindow -j 2>/dev/null | grep -o '"address": *"[^"]*"' | head -1 | sed 's/.*"0x/0x/;s/"//'; }

# address → class,title (empty if gone)
win_info() {
    local addr="$1"
    win_json | python3 -c "
import json,sys
addr='$addr'
try:
    for w in json.load(sys.stdin):
        if w.get('address')==addr:
            print(w.get('class','')+'\t'+w.get('title',''))
            break
except Exception:
    pass
"
}

close_win() {
    local addr="$1"
    log "closewindow $addr"
    hyprctl dispatch closewindow "address:$addr" >/dev/null 2>&1
}

# ── MODE: close — manual SUPER+SHIFT+C ───────────────────────────────
# Closes every UNFOCUSED window whose class matches CALL_CLASSES and
# that is floating (popups float; the main meeting window is tiled or
# fullscreen — and even if floating, the focused one is never touched).
if [ "${1:-}" = "close" ]; then
    foc="$(focused_addr)"
    win_json | python3 -c "
import json,sys,re
foc='$foc'
cls=re.compile(r'$CALL_CLASSES', re.I)
try:
    for w in json.load(sys.stdin):
        if not cls.search(w.get('class','') or ''): continue
        if w.get('address')==foc: continue          # never the focused window
        if not w.get('floating', False): continue    # popups float
        print(w.get('address'))
except Exception:
    pass
" | while read -r a; do
        [ -n "$a" ] && close_win "$a"
    done
    exit 0
fi

# ── MODE: daemon (default) ────────────────────────────────────────────
if [ -z "$SIG" ] || [ ! -S "$SOCK" ]; then
    log "no Hyprland socket2 ($SOCK) — daemon exiting"
    exit 1
fi

command -v socat >/dev/null 2>&1 || { log "socat missing — install socat"; exit 1; }

# armed[addr]=deadline_epoch — windows whose title hit an ENDED pattern
declare -A armed

log "daemon up · grace=${GRACE_SECS}s · classes=/$CALL_CLASSES/"

# Reaper loop: every 5s, check armed windows whose grace elapsed.
reap() {
    local now foc
    now=$(date +%s)
    foc="$(focused_addr)"
    for addr in "${!armed[@]}"; do
        local deadline="${armed[$addr]}"
        [ "$now" -lt "$deadline" ] && continue
        # Rule 4 — focused right now? user is interacting: DISARM, don't defer.
        if [ "$addr" = "$foc" ]; then
            log "$addr focused at deadline — disarmed (user interacting)"
            unset "armed[$addr]"
            continue
        fi
        # Rule 5 — still exists, and title still reads ended/blank?
        local info cls title
        info="$(win_info "$addr")"
        if [ -z "$info" ]; then
            unset "armed[$addr]"        # already gone — nothing to do
            continue
        fi
        cls="${info%%$'\t'*}"; title="${info#*$'\t'}"
        if [ -n "$title" ] && ! echo "$title" | grep -qiE "$ENDED_TITLES"; then
            log "$addr title recovered ('$title') — disarmed"
            unset "armed[$addr]"
            continue
        fi
        close_win "$addr"
        unset "armed[$addr]"
    done
}

# Event loop. socket2 lines:
#   windowtitlev2>>ADDR,TITLE
#   activewindowv2>>ADDR
#   closewindow>>ADDR
socat -u "UNIX-CONNECT:$SOCK" - | while IFS= read -r line; do
    ev="${line%%>>*}"
    data="${line#*>>}"
    case "$ev" in
        windowtitlev2)
            addr="0x${data%%,*}"; addr="${addr/0x0x/0x}"
            title="${data#*,}"
            if echo "$title" | grep -qiE "$ENDED_TITLES"; then
                # Class gate — only arm windows belonging to call apps
                info="$(win_info "$addr")"
                cls="${info%%$'\t'*}"
                if echo "$cls" | grep -qiE "$CALL_CLASSES"; then
                    armed[$addr]=$(( $(date +%s) + GRACE_SECS ))
                    log "armed $addr ($cls) — '$title' · closes in ${GRACE_SECS}s unless you use it"
                fi
            fi
            ;;
        activewindowv2)
            addr="0x${data}"; addr="${addr/0x0x/0x}"
            # Rule 4 — focusing an armed window disarms it: the user is
            # clicking the post-call prompt / settings. This is THE fix.
            if [ -n "${armed[$addr]:-}" ]; then
                log "$addr gained focus — disarmed"
                unset "armed[$addr]"
            fi
            ;;
        closewindow)
            addr="0x${data}"; addr="${addr/0x0x/0x}"
            unset "armed[$addr]" 2>/dev/null || true
            ;;
    esac
    reap
done
