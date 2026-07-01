#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-dm-switch.sh v7.0.0-beta.1-hf95.13
# ────────────────────────────────────────────────────────────────
# Switches the ACTIVE display manager between SDDM (for the Zen Tokyo
# greeter) and whatever you used before. Called by the Settings →
# Login Screen toggle via pkexec.
#
#   zen-dm-switch.sh enable    → enable sddm, disable the previous DM
#   zen-dm-switch.sh restore   → re-enable the previous DM, disable sddm
#   zen-dm-switch.sh status    → print the current DM
#
# SAFETY:
#   - Never disables a DM without first enabling the replacement, so you
#     can't end up with NO login screen.
#   - Only acts on real, installed .service units.
#   - The change takes effect at the NEXT reboot/logout (we never stop
#     the running DM out from under your session).
#   - The previous DM is read from /var/lib/zen-shell/previous-dm, written
#     by zen-sddm-install.sh at install time.
#
# Must run as root (the toggle calls it via pkexec; a polkit rule allows
# wheel members without a password). Wala tayong babawasan.
# ════════════════════════════════════════════════════════════════
set -u

STATE_DIR="/var/lib/zen-shell"
PREV_FILE="$STATE_DIR/previous-dm"
LOG="/var/log/zen-sddm-sync.log"
log() { echo "[$(date '+%F %T')] dm-switch: $*" >>"$LOG" 2>/dev/null || true; }

if [ "$(id -u)" -ne 0 ]; then
    echo "Must run as root (via pkexec)." >&2
    exit 1
fi

unit_exists() { systemctl list-unit-files "$1" >/dev/null 2>&1 && \
                systemctl cat "$1" >/dev/null 2>&1; }

active_dm() {
    if [ -L /etc/systemd/system/display-manager.service ]; then
        basename "$(readlink -f /etc/systemd/system/display-manager.service)"
    fi
}

case "${1:-status}" in
    enable)
        if ! unit_exists sddm.service; then
            echo "sddm.service not installed. Install sddm first: sudo pacman -S sddm" >&2
            exit 2
        fi
        # Record the current DM as previous (if it isn't sddm already and
        # we don't already have one stored).
        cur="$(active_dm)"
        case "$cur" in
            sddm.service|"") : ;;
            *) [ -s "$PREV_FILE" ] || { mkdir -p "$STATE_DIR"; echo "$cur" > "$PREV_FILE"; } ;;
        esac
        # Enable sddm FIRST (this re-points display-manager.service), then
        # disable the old one — never leaves you with no DM.
        systemctl enable sddm.service >/dev/null 2>&1
        if [ -s "$PREV_FILE" ]; then
            prev="$(cat "$PREV_FILE")"
            case "$prev" in
                sddm.service) : ;;
                *) unit_exists "$prev" && systemctl disable "$prev" >/dev/null 2>&1 ;;
            esac
        fi
        log "enabled sddm (was: ${cur:-unknown}); effective next reboot"
        echo "SDDM enabled. It becomes your login screen on next reboot/logout."
        ;;

    restore)
        prev=""
        [ -s "$PREV_FILE" ] && prev="$(cat "$PREV_FILE")"
        if [ -z "$prev" ] || ! unit_exists "$prev"; then
            echo "No restorable previous display manager recorded — leaving things as-is." >&2
            echo "(SDDM stays enabled. Enable your preferred DM manually if needed.)" >&2
            log "restore requested but no valid previous DM (prev='$prev')"
            exit 0
        fi
        # Enable the previous DM FIRST, then disable sddm.
        systemctl enable "$prev" >/dev/null 2>&1
        unit_exists sddm.service && systemctl disable sddm.service >/dev/null 2>&1
        log "restored $prev, disabled sddm; effective next reboot"
        echo "Restored $prev. It becomes your login screen on next reboot/logout."
        ;;

    status)
        echo "Active display manager: $(active_dm || echo 'none/unknown')"
        [ -s "$PREV_FILE" ] && echo "Recorded previous DM: $(cat "$PREV_FILE")"
        ;;

    *)
        echo "Usage: $0 {enable|restore|status}" >&2
        exit 1
        ;;
esac
