#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-power-profile-restore.sh v6.16.0
# ────────────────────────────────────────────────────────────────
# Re-applies the user's chosen power profile after login/reboot.
# ────────────────────────────────────────────────────────────────
# Reads SettingsStateV2 JSON:
#   ~/.config/quickshell/zen-shell/settings-state-v2.json
#   → .system.powerProfile
# and calls: powerprofilesctl set <profile>
#
# Runs from autostart.conf via exec-once. Silent no-op if:
#   - powerprofilesctl isn't installed
#   - settings-state-v2.json doesn't exist yet (fresh install)
#   - .system.powerProfile is missing
#
# Sleeps 3s first so power-profiles-daemon.service has time to
# come up under systemd (typically ~1.5s on Arch/CachyOS).
# ════════════════════════════════════════════════════════════════

set -u

CONFIG="$HOME/.config/quickshell/zen-shell/settings-state-v2.json"

# Prereqs
command -v powerprofilesctl >/dev/null 2>&1 || exit 0
command -v jq              >/dev/null 2>&1 || exit 0
[ -f "$CONFIG" ] || exit 0

# Wait for power-profiles-daemon to be ready
sleep 3

# Extract saved profile
PROFILE=$(jq -r '.system.powerProfile // empty' "$CONFIG" 2>/dev/null)

case "$PROFILE" in
    power-saver|balanced|performance)
        powerprofilesctl set "$PROFILE" >/dev/null 2>&1 || true
        # Optional: emit a quiet confirmation (only if the profile
        # actually changed from the daemon default). Use low urgency
        # so it doesn't pop over whatever the user is doing.
        if command -v notify-send >/dev/null 2>&1; then
            CURRENT=$(powerprofilesctl get 2>/dev/null)
            if [ "$CURRENT" = "$PROFILE" ]; then
                notify-send -a "Zen Shell" -u low \
                    -i battery \
                    "Power Profile" \
                    "Restored: ${PROFILE}" \
                    -t 2000 || true
            fi
        fi
        ;;
    *)
        exit 0
        ;;
esac
