#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-sleep-hook.sh v6.16.3.2 — systemd-sleep hook
# ────────────────────────────────────────────────────────────────
# This file MUST be installed at:
#   /usr/lib/systemd/system-sleep/zen-sleep-hook
#
# (a symlink is fine, but the parent directory must be readable
#  by systemd and the file must be executable + owned by root.)
#
# Installation is handled by install-v6.16.3.2-overlay.sh —
# do not run this script manually.
# ────────────────────────────────────────────────────────────────
# How systemd-sleep hooks work:
#   - Every executable in /usr/lib/systemd/system-sleep/ is
#     invoked on suspend / hibernate / hybrid-sleep events.
#   - $1 is "pre" or "post"
#   - $2 is "suspend" | "hibernate" | "hybrid-sleep" | "suspend-then-hibernate"
#   - Run as root, with NO user environment.
#
# Our job here:
#   - On `pre suspend`  : nothing (graceful state save handled
#                         by Hyprland / lid handler before this fires)
#   - On `post suspend` : invoke zen-resume-handler.sh as the
#                         active graphical user, with their full
#                         Wayland / Hyprland / DBus env so the
#                         user-side hyprctl calls work.
# ────────────────────────────────────────────────────────────────
# Environment translation:
#   We use loginctl to find the active graphical session, get the
#   user, then sudo -u that user with WAYLAND_DISPLAY and
#   HYPRLAND_INSTANCE_SIGNATURE pulled from /run/user/$UID.
# ════════════════════════════════════════════════════════════════

set -u

PHASE="${1:-}"
EVENT="${2:-}"

# Only act on post-{suspend,hibernate,hybrid-sleep}. pre is no-op.
case "$PHASE/$EVENT" in
    post/suspend|post/hibernate|post/hybrid-sleep|post/suspend-then-hibernate)
        ;;
    *)
        exit 0
        ;;
esac

# ── Find the active graphical session user ──
# loginctl list-sessions includes the seat & user. We want the
# session that's currently `Active = yes` AND `Type = wayland`
# (or x11, but Hyprland sessions report as wayland).
ACTIVE_USER=""
ACTIVE_UID=""

if command -v loginctl >/dev/null 2>&1; then
    while IFS= read -r line; do
        sid=$(echo "$line" | awk '{print $1}')
        [ -z "$sid" ] && continue
        # show-session is more reliable than parsing list-sessions
        eval "$(loginctl show-session "$sid" -p Active -p Type -p Name -p User 2>/dev/null)"
        if [ "${Active:-no}" = "yes" ] && [ "${Type:-}" = "wayland" ]; then
            ACTIVE_USER="${Name:-}"
            ACTIVE_UID="${User:-}"
            break
        fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
fi

# Fallback: walk /run/user/<uid> for any uid that has a wayland-* socket
if [ -z "$ACTIVE_UID" ]; then
    for d in /run/user/*; do
        [ -d "$d" ] || continue
        uid=$(basename "$d")
        # Numeric uid only
        case "$uid" in (*[!0-9]*) continue ;; esac
        if ls "$d"/wayland-* >/dev/null 2>&1; then
            ACTIVE_UID="$uid"
            ACTIVE_USER=$(getent passwd "$uid" | cut -d: -f1)
            [ -n "$ACTIVE_USER" ] && break
        fi
    done
fi

if [ -z "$ACTIVE_USER" ] || [ -z "$ACTIVE_UID" ]; then
    # No active graphical session — nothing for us to do
    echo "zen-sleep-hook: no active wayland session, skipping" >&2
    exit 0
fi

USER_HOME=$(getent passwd "$ACTIVE_USER" | cut -d: -f6)
RESUME_SCRIPT="$USER_HOME/.local/bin/zen-resume-handler.sh"

if [ ! -x "$RESUME_SCRIPT" ]; then
    echo "zen-sleep-hook: $RESUME_SCRIPT not executable, skipping" >&2
    exit 0
fi

# ── Find Hyprland instance signature ──
# Hyprland writes its IPC socket dir at /run/user/<uid>/hypr/<HIS>/
HIS=""
HYPR_DIR="/run/user/$ACTIVE_UID/hypr"
if [ -d "$HYPR_DIR" ]; then
    # Pick the most-recent instance dir (in case of leftovers)
    HIS=$(ls -t "$HYPR_DIR" 2>/dev/null | head -1)
fi

# Find wayland display
WAYLAND_DISPLAY=$(ls /run/user/"$ACTIVE_UID"/wayland-* 2>/dev/null | \
    head -1 | xargs -r basename 2>/dev/null)
[ -z "$WAYLAND_DISPLAY" ] && WAYLAND_DISPLAY="wayland-1"

# ── Run the user-side recovery as the user ──
# Background it with `&` so we don't hold up the rest of the
# system-sleep hook chain (other scripts in /usr/lib/systemd/
# system-sleep/ also need to run).
sudo -u "$ACTIVE_USER" \
    XDG_RUNTIME_DIR="/run/user/$ACTIVE_UID" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    HYPRLAND_INSTANCE_SIGNATURE="$HIS" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTIVE_UID/bus" \
    HOME="$USER_HOME" \
    "$RESUME_SCRIPT" >/dev/null 2>&1 &

exit 0
