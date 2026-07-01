#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-sddm-install.sh v7.0.0-beta.1-hf95.10
# ────────────────────────────────────────────────────────────────
# Installs the Zen Tokyo SDDM greeter system-wide and wires up the
# live-wallpaper/font sync hook. This is SEPARATE from the per-user
# Zen Shell install (install.sh) because SDDM is system-level and
# needs root. Opt-in: only run this if you want the matching login
# screen ("if sddm enabled").
#
# Run:   sudo ./zen-sddm-install.sh            (install + activate)
#        sudo ./zen-sddm-install.sh --uninstall
#
# What it does:
#   1. Copies sddm/zen-tokyo → /usr/share/sddm/themes/zen-tokyo
#   2. Writes /etc/sddm.conf.d/10-zen-tokyo.conf  (Current=zen-tokyo,
#      CursorTheme so the greeter shows a cursor)
#   3. Installs zen-sddm-sync.sh → /usr/local/bin and a logout hook so
#      the greeter background follows your live wallpaper
#   4. Runs a first sync for the invoking user
#
# Wala tayong babawasan — backs up any existing sddm.conf.d entry.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_THEME="$SCRIPT_DIR/zen-tokyo"
SRC_SYNC="$SCRIPT_DIR/scripts/zen-sddm-sync.sh"
DEST_THEME="/usr/share/sddm/themes/zen-tokyo"
SDDM_CONF="/etc/sddm.conf.d/10-zen-tokyo.conf"
SYNC_BIN="/usr/local/bin/zen-sddm-sync.sh"
CURSOR_THEME="${ZEN_CURSOR_THEME:-Adwaita}"

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must run as root:  sudo $0 ${*:-}" >&2
    exit 1
fi

# The human user (for the first sync + cursor theme), even under sudo.
REAL_USER="${SUDO_USER:-${USER:-root}}"

uninstall() {
    echo "Removing Zen Tokyo SDDM theme…"
    [ -f "$SDDM_CONF" ] && { mv -f "$SDDM_CONF" "$SDDM_CONF.removed-$(date +%s)"; echo "  • disabled $SDDM_CONF"; }
    [ -d "$DEST_THEME" ] && { rm -rf "$DEST_THEME"; echo "  • removed $DEST_THEME"; }
    [ -f "$SYNC_BIN" ] && { rm -f "$SYNC_BIN"; echo "  • removed $SYNC_BIN"; }
    [ -f "/etc/profile.d/zen-sddm-sync.sh" ] && rm -f "/etc/profile.d/zen-sddm-sync.sh"
    echo "Done. Your previous SDDM theme is active again (set Current= in /etc/sddm.conf.d as needed)."
    exit 0
}
[ "${1:-}" = "--uninstall" ] && uninstall

[ -d "$SRC_THEME" ] || { echo "Theme source missing: $SRC_THEME" >&2; exit 1; }
command -v sddm >/dev/null 2>&1 || echo "  ⚠️  sddm not found on PATH — installing the theme anyway."

# v7.0.0-beta.1-hf95.13: detect the currently-active display manager so
# the Settings toggle can restore it when SDDM is disabled. The active DM
# is whatever display-manager.service points at.
DM_STATE_DIR="/var/lib/zen-shell"
mkdir -p "$DM_STATE_DIR" 2>/dev/null
PREV_DM=""
if [ -L /etc/systemd/system/display-manager.service ]; then
    PREV_DM="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
fi
# Don't record sddm as the "previous" DM (we'd have nothing to go back to).
case "$PREV_DM" in sddm.service|"") : ;; *)
    echo "$PREV_DM" > "$DM_STATE_DIR/previous-dm"
    echo "  • recorded current display manager for restore: $PREV_DM"
    ;;
esac

echo "[1/4] Installing theme → $DEST_THEME"
rm -rf "$DEST_THEME"
mkdir -p "$DEST_THEME"
cp -a "$SRC_THEME/." "$DEST_THEME/"
chmod -R a+rX "$DEST_THEME"

echo "[2/4] Writing $SDDM_CONF"
mkdir -p /etc/sddm.conf.d
[ -f "$SDDM_CONF" ] && cp -f "$SDDM_CONF" "$SDDM_CONF.bak-$(date +%s)"
cat > "$SDDM_CONF" <<CONF
# Managed by zen-sddm-install.sh — Zen Tokyo greeter
[Theme]
Current=zen-tokyo
CursorTheme=$CURSOR_THEME

[General]
# Show the mouse cursor on the greeter (the lock screen hides it;
# a login greeter should show it).
CursorTheme=$CURSOR_THEME
CONF

echo "[3/4] Installing sync hook → $SYNC_BIN"
install -m 0755 "$SRC_SYNC" "$SYNC_BIN"
# hf95.13: install the DM switch helper too.
DM_SWITCH_BIN="/usr/local/bin/zen-dm-switch.sh"
if [ -f "$SCRIPT_DIR/scripts/zen-dm-switch.sh" ]; then
    install -m 0755 "$SCRIPT_DIR/scripts/zen-dm-switch.sh" "$DM_SWITCH_BIN"
fi
# Logout/login profile hook: refresh the greeter wallpaper from the
# user's live wallpaper when they log in (so next greeter matches).
cat > /etc/profile.d/zen-sddm-sync.sh <<'HOOK'
# Zen Tokyo SDDM: refresh greeter wallpaper from the live desktop.
# Runs in the background, non-fatal, only for interactive shells.
if [ -x /usr/local/bin/zen-sddm-sync.sh ] && [ -n "${USER:-}" ]; then
    ( pkexec /usr/local/bin/zen-sddm-sync.sh "--user=$USER" >/dev/null 2>&1 & ) 2>/dev/null || true
fi
HOOK
chmod 0644 /etc/profile.d/zen-sddm-sync.sh

# A polkit rule so the sync can write the theme dir without a password
# prompt (it only ever writes /usr/share/sddm/themes/zen-tokyo).
RULE="/etc/polkit-1/rules.d/49-zen-sddm-sync.rules"
if [ -d /etc/polkit-1/rules.d ]; then
cat > "$RULE" <<RULES
// Allow members of 'wheel' to run the Zen SDDM wallpaper sync and the DM
// switch helper without a password. The sync script only writes the
// greeter theme directory; the switch helper only toggles which display
// manager is enabled (never stops the running session).
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        (action.lookup("program") == "$SYNC_BIN" ||
         action.lookup("program") == "$DM_SWITCH_BIN") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
RULES
chmod 0644 "$RULE"
fi

echo "[4/4] First wallpaper/font sync for user: $REAL_USER"
ZEN_SDDM_FORCE=1 ZEN_SDDM_THEME_DIR="$DEST_THEME" "$SYNC_BIN" "--user=$REAL_USER" || \
    echo "  ⚠️  First sync had no wallpaper yet — it'll populate on next logout/wallpaper change."

echo ""
echo "✓ Zen Tokyo SDDM theme installed and activated."
echo "  Preview:   sddm-greeter --test-mode --theme $DEST_THEME   (Qt6: sddm-greeter-qt6)"
echo "  Fonts:     match your bar font automatically on each sync."
echo "  Wallpaper: copied from your live desktop; re-synced at login."
echo "  Uninstall: sudo $0 --uninstall"
