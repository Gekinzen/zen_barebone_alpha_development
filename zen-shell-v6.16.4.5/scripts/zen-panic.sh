#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-panic.sh v6.16.4 — Escape hatch / unjam everything
# ────────────────────────────────────────────────────────────────
# The "I'd rather force-power-off" problem this solves:
#
#   Scenario A: hyprlock is running but frozen. Screen shows the
#   lock but keyboard input doesn't reach the password field. No
#   way to get to TTY. Previously → force power off.
#
#   Scenario B: Wake from suspend black-screen. System is alive
#   (SSH still works) but display shows nothing. hyprctl is stuck.
#   Previously → force power off.
#
#   Scenario C: Quickshell / swww zombied. Bar gone, wallpaper
#   gone, input handler has old bindings. Window manager works
#   but visually everything is broken.
#
# All three are recoverable IF you can fire a script. This script
# does every recovery step known to work, in sequence, with
# timeouts, logging everything it tries.
#
# HOW TO TRIGGER (in order of preference):
#   1. Keybind: SUPER+SHIFT+CTRL+Escape (Hyprland bindl — survives lock)
#   2. SSH from another device: ~/.local/bin/zen-panic.sh
#   3. TTY (Ctrl+Alt+F2): loginctl unlock-session && run this script
#
# ────────────────────────────────────────────────────────────────
# Design principle: be BRUTALLY thorough. Every step is
# try-and-continue. One failure doesn't block the next step.
# We'd rather over-recover than leave the user stuck.
# ════════════════════════════════════════════════════════════════

set -u

LOG_FILE="$HOME/.cache/zen-shell/panic.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log() {
    local ts msg
    ts=$(date +'%Y-%m-%d %H:%M:%S')
    msg="[$ts] $*"
    echo "$msg" | tee -a "$LOG_FILE" 2>/dev/null
    if [ -f "$LOG_FILE" ] && [ "$(wc -l <"$LOG_FILE" 2>/dev/null || echo 0)" -gt 400 ]; then
        tail -300 "$LOG_FILE" >"$LOG_FILE.tmp" 2>/dev/null && \
            mv "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
    fi
}

log "══════════════════════════════════════════════════"
log "PANIC RECOVERY invoked — pre-state snapshot:"
log "  hyprlock running:  $(pgrep -x hyprlock >/dev/null && echo yes || echo no)"
log "  hypridle running:  $(pgrep -x hypridle >/dev/null && echo yes || echo no)"
log "  quickshell running: $(pgrep -f 'quickshell.*zen-shell' >/dev/null && echo yes || echo no)"
log "  swww-daemon running: $(pgrep -f swww-daemon >/dev/null && echo yes || echo no)"
log "  hyprctl reachable: $(timeout 1 hyprctl version >/dev/null 2>&1 && echo yes || echo no)"

# ════════════════════════════════════════════════════════════════
# Step 1: Kill frozen hyprlock if it's stuck
# ────────────────────────────────────────────────────────────────
# "Stuck" detection: if hyprlock is alive but the user pressed
# panic, odds are high it's the problem. SIGKILL rather than
# SIGTERM because SIGTERM-unresponsive is WHY we're here.
#
# Consequence: user's password prompt disappears. That's the
# desired outcome — we'll re-lock cleanly below.
# ════════════════════════════════════════════════════════════════
if pgrep -x hyprlock >/dev/null 2>&1; then
    log "step 1: SIGKILL hyprlock (forcing clean relock)"
    pkill -9 -x hyprlock 2>/dev/null
    sleep 0.2
else
    log "step 1: hyprlock not running — skipping"
fi

# ════════════════════════════════════════════════════════════════
# Step 2: Wait for hyprctl to be reachable (up to 3s)
# ────────────────────────────────────────────────────────────────
WAITED=0
while ! timeout 1 hyprctl monitors >/dev/null 2>&1; do
    sleep 0.2
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 15 ]; then
        log "step 2: hyprctl unreachable after 3s — continuing anyway"
        break
    fi
done
[ "$WAITED" -lt 15 ] && log "step 2: hyprctl reachable after $((WAITED*200))ms"

# ════════════════════════════════════════════════════════════════
# Step 3: Aggressive DPMS kick
# ────────────────────────────────────────────────────────────────
# Double off→on cycle. Some AMDGPU setups need TWO cycles before
# the KMS state fully re-syncs. Sleep between them so the driver
# actually processes each.
# ════════════════════════════════════════════════════════════════
log "step 3: DPMS aggressive kick (2x cycles)"
hyprctl dispatch dpms off >/dev/null 2>&1 || true
sleep 0.3
hyprctl dispatch dpms on  >/dev/null 2>&1 || true
sleep 0.3
hyprctl dispatch dpms off >/dev/null 2>&1 || true
sleep 0.2
hyprctl dispatch dpms on  >/dev/null 2>&1 || true

# ════════════════════════════════════════════════════════════════
# Step 4: Monitor re-sync (NO reload — preserves runtime config)
# ────────────────────────────────────────────────────────────────
# v6.16.4.1 fix: previously called `hyprctl reload` which WIPED
# the user's runtime monitor= keywords set by DisplaysPage →
# monitors reverted to hyprland.conf defaults on every panic.
# That's a worse bug than the one we were trying to solve.
#
# Replacement: `hyprctl dispatch forcerendererreload` forces
# monitor re-enumeration at the KMS level WITHOUT re-reading
# hyprland.conf or clearing runtime keywords. Safe. Available
# since Hyprland 0.50+ (Paul's on 0.54+).
#
# Per-monitor preferred mode is also kept as belt-and-suspenders
# — sets runtime keyword for each detected monitor, which is a
# no-op if the monitor already has a user-set mode applied.
# ════════════════════════════════════════════════════════════════
log "step 4: force renderer reload (preserves runtime config)"
hyprctl dispatch forcerendererreload >/dev/null 2>&1 || true
sleep 0.2

# v6.16.4.1: the per-monitor "${mon},preferred,auto,1" loop was
# removed. Reason: it OVERRIDES user custom resolution / scale
# set via DisplaysPage (e.g., "eDP-1,2880x1800@90,auto,1.5" →
# reverted to preferred,auto,1 = 1.0x scale, native mode). The
# forcerendererreload above already handles the KMS-level
# re-enum we actually need. If a specific monitor is still
# wrong after recovery, user can use DisplaysPage to fix it —
# that's better than automatic clobbering.

# ════════════════════════════════════════════════════════════════
# Step 5: Revive swww-daemon if zombied
# ────────────────────────────────────────────────────────────────
if command -v swww >/dev/null 2>&1; then
    if ! timeout 1 swww query >/dev/null 2>&1; then
        log "step 5: swww-daemon zombied — restarting"
        pkill -9 -f 'swww-daemon' 2>/dev/null
        sleep 0.2
        if command -v swww-daemon >/dev/null 2>&1; then
            setsid -f swww-daemon </dev/null >/dev/null 2>&1 &
        else
            setsid -f swww init </dev/null >/dev/null 2>&1 &
        fi
        sleep 0.3

        WP_FILE="$HOME/.config/quickshell/zen-shell/wallpaper-v5.json"
        if [ -f "$WP_FILE" ] && command -v jq >/dev/null 2>&1; then
            CUR_WP=$(jq -r '.currentWallpaper // empty' "$WP_FILE" 2>/dev/null)
            if [ -n "$CUR_WP" ] && [ -f "$CUR_WP" ]; then
                swww img "$CUR_WP" --transition-type none >/dev/null 2>&1 &
                log "  re-applied wallpaper"
            fi
        fi
    else
        log "step 5: swww-daemon responsive — skipping restart"
    fi
fi

# ════════════════════════════════════════════════════════════════
# Step 6: Quickshell — double-press only
# ────────────────────────────────────────────────────────────────
# v6.16.4.1 FIX: v6.16.4 sent SIGUSR2 to Quickshell on every
# panic press thinking it was a no-op. It's not — unhandled
# SIGUSR2 = process termination under default Linux signal rules.
# Result: every single panic press killed Quickshell, the user
# got widget ghosting / music marquee replaying on respawn /
# MusicService re-subscribing and double-firing metadata.
#
# New policy: SINGLE press never touches Quickshell. Only
# double-press (within 10s) escalates to full Quickshell
# restart via zs-restart.sh — that script already handles state
# preservation properly.
#
# Single press = DPMS + forcerendererreload + hyprlock re-lock.
# Quickshell keeps running untouched → bar stays, widgets stay,
# music marquee stays where it was, drag positions preserved.
# ════════════════════════════════════════════════════════════════
PANIC_FLAG="$HOME/.cache/zen-shell/panic-last"
NOW=$(date +%s)
DOUBLE_PRESS=0
if [ -f "$PANIC_FLAG" ]; then
    LAST=$(cat "$PANIC_FLAG" 2>/dev/null || echo 0)
    AGE=$((NOW - LAST))
    if [ "$AGE" -lt 10 ] && [ "$AGE" -ge 0 ]; then
        DOUBLE_PRESS=1
    fi
fi
echo "$NOW" >"$PANIC_FLAG" 2>/dev/null

if [ "$DOUBLE_PRESS" = "1" ]; then
    log "step 6: DOUBLE-PRESS detected — full Quickshell restart"
    if [ -x "$HOME/.local/bin/zs-restart.sh" ]; then
        "$HOME/.local/bin/zs-restart.sh" >/dev/null 2>&1 &
    else
        pkill -f 'quickshell.*zen-shell' 2>/dev/null
        sleep 0.3
        setsid -f qs -c zen-shell </dev/null >/dev/null 2>&1 &
    fi
elif pgrep -f 'quickshell.*zen-shell' >/dev/null 2>&1; then
    log "step 6: quickshell running — leaving untouched (press again within 10s to force restart)"
else
    log "step 6: quickshell not running — launching fresh"
    setsid -f qs -c zen-shell </dev/null >/dev/null 2>&1 &
fi

# ════════════════════════════════════════════════════════════════
# Step 7: Re-lock cleanly (if user was locked before panic)
# ────────────────────────────────────────────────────────────────
# If we killed a stuck hyprlock in step 1, the session is now
# "unlocked" from hyprlock's perspective but the user didn't
# actually unlock. Re-lock so we're safe — if user wants to
# actually unlock, they type their password on the fresh lock.
# ════════════════════════════════════════════════════════════════
if [ -x "$HOME/.local/bin/zen-lock.sh" ]; then
    # Only re-lock if we killed hyprlock in step 1 (tracked via
    # a simple heuristic: panic was invoked and hyprlock was up
    # when panic started — see pre-state snapshot above).
    PREV_LOCK=$(grep "^\[.*\]   hyprlock running:  yes" "$LOG_FILE" 2>/dev/null | tail -1)
    if [ -n "$PREV_LOCK" ] && ! pgrep -x hyprlock >/dev/null 2>&1; then
        log "step 7: re-locking (session was locked before panic)"
        setsid -f "$HOME/.local/bin/zen-lock.sh" </dev/null >/dev/null 2>&1 &
    else
        log "step 7: not re-locking (session wasn't locked, or hyprlock is back)"
    fi
fi

# ════════════════════════════════════════════════════════════════
# Step 8: Workspace bounce — REMOVED in v6.16.4.1
# ────────────────────────────────────────────────────────────────
# v6.16.4's step 8 dispatched `workspace OTHER` then `workspace CUR`
# to force a paint pass. Side effect: windows + widgets re-triggered
# their enter/appear animations. For the music widget specifically,
# the marquee animation looped back to start every panic press →
# "pabalik-balik yung music layer" bug.
#
# Decision: skip the bounce entirely. If recovery step 3 (double
# DPMS cycle) and step 4 (forcerendererreload) didn't fix the paint,
# a workspace bounce wouldn't either — it's a "maybe helps" nice-to-
# have, and the side effects are real and user-visible.
# ════════════════════════════════════════════════════════════════
log "step 8: workspace bounce SKIPPED in 4.1 (was causing animation replay bug)"

log "══════════════════════════════════════════════════"
log "PANIC RECOVERY complete. Check log: $LOG_FILE"

# Notify user if notify-send is up
if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal -t 5000 \
        "Zen Panic Recovery" \
        "Recovery sequence complete. Check ~/.cache/zen-shell/panic.log if issues persist." \
        >/dev/null 2>&1 &
fi

exit 0
