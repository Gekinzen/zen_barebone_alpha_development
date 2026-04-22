#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-lid-handler.sh v6.16.0
# ────────────────────────────────────────────────────────────────
# Handle laptop lid open/close events based on the user's setting
# in SettingsStateV2.system.lidCloseBehavior.
# ────────────────────────────────────────────────────────────────
# Hyprland calls this via bindl rules in lid-behavior.conf:
#   bindl = , switch:on:Lid,  exec, ~/.local/bin/zen-lid-handler.sh close
#   bindl = , switch:off:Lid, exec, ~/.local/bin/zen-lid-handler.sh open
#
# Behaviors (matching SettingsStateV2.lidCloseBehavior):
#   mirror → disable eDP-1 when lid closes IF an external monitor
#            is connected; external keeps rendering uninterrupted.
#            When an external IS NOT connected, suspend instead
#            (no point leaving the laptop running blind).
#   keep   → do nothing on close (keep internal display on even
#            with lid shut — useful kapag naka-dock yung laptop
#            and gusto mong tuloy rendering sa internal panel).
#   off    → disable eDP-1 always on close (classic Hyprland behavior).
# On lid open, always re-enable eDP-1.
#
# This fixes the bug Paul reported:
#   "kapag sa laptop or desktop kapag close kasi yun lid ng monitor
#    kapag on ko wala na lumalabas sa screen"
# → Root cause: default hyprctl behavior only turns off eDP-1 but
#   doesn't update the layout tree, so external monitors that were
#   positioned relative to eDP-1 end up at wrong coordinates.
# → Fix: explicit `hyprctl keyword monitor eDP-1,disable` on close
#   + forced workspace reassignment to the remaining monitor.
# ════════════════════════════════════════════════════════════════

set -u

ACTION="${1:-}"
CONFIG="$HOME/.config/quickshell/zen-shell/settings-state-v2.json"

# Read behavior preference (default: mirror)
BEHAVIOR="mirror"
if command -v jq >/dev/null 2>&1 && [ -f "$CONFIG" ]; then
    SAVED=$(jq -r '.system.lidCloseBehavior // empty' "$CONFIG" 2>/dev/null)
    case "$SAVED" in
        mirror|keep|off) BEHAVIOR="$SAVED" ;;
    esac
fi

# Detect the internal display name. Most laptops report eDP-1;
# some older / niche hardware uses LVDS-1 or DSI-1. We grab the
# first monitor whose name starts with one of those prefixes.
detect_internal() {
    hyprctl -j monitors 2>/dev/null | \
        jq -r '.[] | .name' 2>/dev/null | \
        grep -E '^(eDP|LVDS|DSI)' | head -1
}

# Count connected external monitors (everything that isn't the internal one)
count_externals() {
    local internal="$1"
    hyprctl -j monitors 2>/dev/null | \
        jq -r '.[] | .name' 2>/dev/null | \
        grep -Ev "^${internal}\$" | wc -l
}

INTERNAL=$(detect_internal)

# ─────────────────────────────────────────────────────────────
# No internal display detected — nothing to do. This covers
# desktops (in case the user accidentally binds the script) and
# systems with unusual panel naming.
# ─────────────────────────────────────────────────────────────
if [ -z "$INTERNAL" ]; then
    exit 0
fi

case "$ACTION" in
    close)
        EXT_COUNT=$(count_externals "$INTERNAL")

        case "$BEHAVIOR" in
            keep)
                # Do nothing — internal stays on
                exit 0
                ;;
            mirror|off)
                if [ "$BEHAVIOR" = "mirror" ] && [ "$EXT_COUNT" -eq 0 ]; then
                    # No external → no point keeping the machine running
                    # with the lid closed. Suspend instead.
                    if command -v systemctl >/dev/null 2>&1; then
                        systemctl suspend
                    fi
                    exit 0
                fi
                # Disable the internal display
                hyprctl keyword monitor "${INTERNAL},disable" >/dev/null 2>&1
                # Force a reload so workspaces reshuffle to remaining monitors
                hyprctl reload >/dev/null 2>&1 || true
                ;;
        esac
        ;;
    open)
        # Re-enable the internal display. We use "preferred,auto,1" —
        # Hyprland picks the panel's preferred mode and auto-positions
        # it. If the user has a custom monitor config in hyprland.conf
        # it'll be applied on the reload below.
        hyprctl keyword monitor "${INTERNAL},preferred,auto,1" >/dev/null 2>&1
        hyprctl reload >/dev/null 2>&1 || true
        ;;
    *)
        echo "zen-lid-handler.sh v6.16.0" >&2
        echo "Usage: $0 {close|open}" >&2
        exit 1
        ;;
esac
