#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# install-v6.16.3.2-overlay.sh
# ────────────────────────────────────────────────────────────────
# Apply the v6.16.3.2 lid + wake recovery overlay on top of an
# existing Zen Shell installation. Does NOT touch the main
# install.sh — safe to run on any v6.16.x box.
#
# What it does:
#   1. Drops the new + updated QML into ~/.config/quickshell/zen-shell/
#      (PowerConfirmDialog.qml from v6.16.3.1)
#   2. Drops the new + updated hypr-config/ files into ~/.config/hypr/modules/
#      (lid-behavior.conf, autostart.conf, hypridle.conf, hyprlock.conf)
#   3. Symlinks the new scripts into ~/.local/bin/
#      (zen-lid-handler.sh, zen-resume-handler.sh)
#   4. Optionally installs the systemd-sleep hook (requires sudo)
#      (zen-sleep-hook.sh → /usr/lib/systemd/system-sleep/zen-sleep-hook)
#   5. Restarts hypridle / quickshell to pick up the changes
#
# All steps are idempotent. Re-run any time to refresh.
# ════════════════════════════════════════════════════════════════

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARBALL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Sanity: make sure we're being run from inside the v6.16.3.2 tree
if [ ! -f "$TARBALL_ROOT/CHANGELOG-v6.16.3.2.md" ]; then
    echo "ERROR: can't find CHANGELOG-v6.16.3.2.md at $TARBALL_ROOT" >&2
    echo "       run this script from inside the v6.16.3.2 source tree" >&2
    exit 1
fi

QML_SRC="$TARBALL_ROOT/zen-shell-v5"
HYPR_SRC="$TARBALL_ROOT/hypr-config"
SCRIPTS_SRC="$TARBALL_ROOT/scripts"

QML_DST="$HOME/.config/quickshell/zen-shell"
HYPR_DST="$HOME/.config/hypr/modules"
BIN_DST="$HOME/.local/bin"

# ANSI helpers (graceful degradation if no tty)
if [ -t 1 ]; then
    C_OK=$'\033[1;32m'; C_WARN=$'\033[1;33m'; C_ERR=$'\033[1;31m'
    C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
    C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

say() { printf '%s\n' "$*"; }
ok()  { printf '%b\n' "  ${C_OK}✓${C_RESET} $*"; }
warn(){ printf '%b\n' "  ${C_WARN}!${C_RESET} $*"; }
err() { printf '%b\n' "  ${C_ERR}✗${C_RESET} $*" >&2; }
hr()  { printf '%b\n' "${C_DIM}────────────────────────────────────────────────────────${C_RESET}"; }

say ""
printf '%b\n' "${C_BOLD}Zen Shell — v6.16.3.2 lid + wake recovery overlay${C_RESET}"
hr

# ─────────────────────────────────────────────────────────────
# Phase 1: Pre-flight checks
# ─────────────────────────────────────────────────────────────
say ""
say "Phase 1: pre-flight"

if [ ! -d "$QML_DST" ]; then
    err "Zen Shell base install not found at $QML_DST"
    err "Run the main ./install.sh first, then re-run this overlay."
    exit 1
fi
ok "base install detected at $QML_DST"

mkdir -p "$HYPR_DST" "$BIN_DST" 2>/dev/null
ok "target dirs ready"

# Check for optional dependencies (warn, never fail)
for cmd in jq hyprctl swww hypridle hyprlock; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd present"
    else
        warn "$cmd missing — overlay will degrade gracefully but you may want to install it"
    fi
done

# ─────────────────────────────────────────────────────────────
# Phase 2: QML drop-in (PowerConfirmDialog from v6.16.3.1)
# ─────────────────────────────────────────────────────────────
say ""
say "Phase 2: QML overlay"

if [ -f "$QML_SRC/PowerConfirmDialog.qml" ]; then
    cp "$QML_SRC/PowerConfirmDialog.qml" "$QML_DST/PowerConfirmDialog.qml"
    ok "PowerConfirmDialog.qml updated (v6.16.3.1 — Material Design icons)"
else
    err "PowerConfirmDialog.qml not found in $QML_SRC"
fi

# ─────────────────────────────────────────────────────────────
# Phase 3: hypr-config files
# ─────────────────────────────────────────────────────────────
say ""
say "Phase 3: hypr-config overlay"

# Drop the four hypr-config files into ~/.config/hypr/modules/.
# We DON'T copy zen-sleep-hook.sh here — that goes to
# /usr/lib/systemd/system-sleep/ in phase 5.
for f in lid-behavior.conf autostart.conf; do
    if [ -f "$HYPR_SRC/$f" ]; then
        cp "$HYPR_SRC/$f" "$HYPR_DST/$f"
        ok "$f → $HYPR_DST/$f"
    else
        err "$f not found in $HYPR_SRC"
    fi
done

# hypridle.conf and hyprlock.conf go directly under ~/.config/hypr/
# (NOT in modules/) because hypridle and hyprlock look there by
# default. If user wants to override, they can edit in place.
HYPR_USER_DIR="$HOME/.config/hypr"
for f in hypridle.conf hyprlock.conf; do
    if [ -f "$HYPR_SRC/$f" ]; then
        if [ -f "$HYPR_USER_DIR/$f" ]; then
            warn "$f exists at $HYPR_USER_DIR — not overwriting (back up & re-run if you want the new version)"
        else
            cp "$HYPR_SRC/$f" "$HYPR_USER_DIR/$f"
            ok "$f → $HYPR_USER_DIR/$f"
        fi
    fi
done

# ─────────────────────────────────────────────────────────────
# Phase 4: Scripts → ~/.local/bin/
# ─────────────────────────────────────────────────────────────
say ""
say "Phase 4: scripts → $BIN_DST"

for f in zen-lid-handler.sh zen-resume-handler.sh; do
    if [ -f "$SCRIPTS_SRC/$f" ]; then
        cp "$SCRIPTS_SRC/$f" "$BIN_DST/$f"
        chmod +x "$BIN_DST/$f"
        ok "$f → $BIN_DST/$f"
    else
        err "$f not found in $SCRIPTS_SRC"
    fi
done

# ─────────────────────────────────────────────────────────────
# Phase 5: systemd-sleep hook (requires sudo, optional)
# ─────────────────────────────────────────────────────────────
say ""
say "Phase 5: systemd-sleep hook (optional, requires sudo)"
say ""
say "  This is the piece that fixes black-screen-on-wake from"
say "  events that ${C_BOLD}aren't${C_RESET} lid switches (keyboard wake, dock"
say "  unplug, manual systemctl suspend, hypridle auto-suspend)."
say ""
say "  Without it, you'll still get full recovery on lid open"
say "  and via the SUPER+SHIFT+W manual hotkey — but wakes that"
say "  don't fire either of those won't get the recovery pipeline."
say ""

HOOK_SRC="$HYPR_SRC/zen-sleep-hook.sh"
HOOK_DST="/usr/lib/systemd/system-sleep/zen-sleep-hook"

if [ ! -f "$HOOK_SRC" ]; then
    err "zen-sleep-hook.sh not found in $HYPR_SRC — skipping"
else
    printf '  Install systemd-sleep hook? [Y/n] '
    read -r ans
    case "$ans" in
        n|N|no|NO)
            warn "skipped — manual install with: sudo install -m 0755 \"$HOOK_SRC\" \"$HOOK_DST\""
            ;;
        *)
            if command -v sudo >/dev/null 2>&1; then
                if sudo install -m 0755 -o root -g root "$HOOK_SRC" "$HOOK_DST" 2>/dev/null; then
                    ok "installed at $HOOK_DST"
                else
                    err "sudo install failed — try manually: sudo install -m 0755 \"$HOOK_SRC\" \"$HOOK_DST\""
                fi
            else
                err "no sudo available — copy manually as root:"
                err "  install -m 0755 \"$HOOK_SRC\" \"$HOOK_DST\""
            fi
            ;;
    esac
fi

# ─────────────────────────────────────────────────────────────
# Phase 6: Restart hypridle and quickshell
# ─────────────────────────────────────────────────────────────
say ""
say "Phase 6: restart daemons"

# hypridle
if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle 2>/dev/null
    sleep 0.3
fi
if command -v hypridle >/dev/null 2>&1; then
    setsid -f hypridle </dev/null >/dev/null 2>&1 &
    ok "hypridle restarted"
else
    warn "hypridle not installed — skipping (idle/lock cascade disabled)"
fi

# Quickshell — gentle restart so PowerConfirmDialog reloads.
# Borrows the "bulletproof" pattern from install.sh v6.16.2.3.6.
say ""
say "  Restarting Zen Shell so PowerConfirmDialog picks up..."
for attempt in 1 2 3 4 5; do
    PIDS=$(pgrep -f 'quickshell.*zen-shell' 2>/dev/null)
    [ -z "$PIDS" ] && break
    if [ "$attempt" -le 3 ]; then
        kill $PIDS 2>/dev/null
    else
        kill -9 $PIDS 2>/dev/null
    fi
    sleep 0.3
done
setsid -f quickshell -p ~/.config/quickshell/zen-shell </dev/null >/dev/null 2>&1 &
ok "Zen Shell restarted"

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────
say ""
hr
printf '%b\n' "${C_BOLD}v6.16.3.2 overlay applied${C_RESET}"
hr
say ""
say "  Try the lid:"
say "    1. Plug AC, no external → lock + DPMS off (no suspend)"
say "    2. Unplug AC, no external → lock + suspend"
say "    3. Plug external, any AC state → clamshell"
say ""
say "  If wake breaks anyway:"
say "    SUPER+SHIFT+W              # manual recovery"
say "    tail -f ~/.cache/zen-shell/lid.log     # debug lid events"
say "    tail -f ~/.cache/zen-shell/resume.log  # debug wake events"
say ""
