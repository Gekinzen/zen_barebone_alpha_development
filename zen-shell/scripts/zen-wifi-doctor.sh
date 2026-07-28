#!/usr/bin/env bash
# zen-wifi-doctor — show exactly what Zen Shell's three wifi-detection
#                   sources return on THIS machine.
#   v8.0.0-alpha-hf180 · Karui (軽い)
#
# Zen Shell decides "am I on wifi, and which network" from three independent
# sources, because any one of them can be wrong or missing:
#
#   1. iw dev <dev> link                     — the card itself
#   2. nmcli device show <dev>               — NetworkManager, per device
#   3. nmcli connection show --active        — NetworkManager, per profile
#
# When the panel says "Not connected" while the machine is plainly online,
# one of these three did not answer the way the parser expects. Run this and
# send the output; it says which.
#
# Read-only. Runs no state-changing command.

set -uo pipefail

WHY=0
for a in "$@"; do
    case "$a" in
        --why|-w) WHY=1 ;;
        -h|--help)
            echo "usage: zen-wifi-doctor [--why]"
            echo "  (no args)  which detection source disagrees with reality"
            echo "  --why      the wifi really is down — driver, power save,"
            echo "             profile, NM journal, kernel log, AP analysis"
            exit 0 ;;
    esac
done

hr()  { printf '\n\033[1m── %s ─────────────────────────────────\033[0m\n' "$1"; }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; }
inf() { printf '    %s\n' "$*"; }

echo "zen-wifi-doctor · $(date -Iseconds)"
command -v nmcli >/dev/null 2>&1 || { bad "nmcli not installed — nothing here will work"; exit 1; }
inf "NetworkManager $(nmcli --version 2>/dev/null | grep -oE '[0-9]+\.[0-9.]+' | head -1)"

# ── device ──────────────────────────────────────────────────────────────────
hr "wifi device"
WDEV="$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')"
if [ -n "$WDEV" ]; then ok "found: $WDEV"; else
    bad "no device with TYPE 'wifi' in \`nmcli device status\`"
    inf "raw:"; nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | sed 's/^/      /'
fi

# ── source 1 ────────────────────────────────────────────────────────────────
hr "SOURCE 1 — iw dev link (the card)"
if ! command -v iw >/dev/null 2>&1; then
    bad "\`iw\` is NOT installed  →  sudo pacman -S iw"
    inf "Zen Shell falls back to sources 2 and 3, so this is not fatal."
elif [ -z "$WDEV" ]; then
    bad "skipped — no wifi device name"
else
    OUT="$(iw dev "$WDEV" link 2>&1)"
    if echo "$OUT" | grep -q "Not connected"; then
        bad "card reports NOT connected"
    elif echo "$OUT" | grep -q "^Connected to"; then
        ok "connected"
        inf "BSSID : $(echo "$OUT" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)"
        inf "SSID  : $(echo "$OUT" | grep -E '^\s*SSID:' | sed 's/.*SSID:[[:space:]]*//')"
        inf "signal: $(echo "$OUT" | grep -E '^\s*signal:' | sed 's/.*signal:[[:space:]]*//')"
    else
        bad "unexpected output — the parser will not read this"
        echo "$OUT" | sed 's/^/      /'
    fi
fi

# ── source 2 ────────────────────────────────────────────────────────────────
hr "SOURCE 2 — nmcli device show (per device)"
if [ -z "$WDEV" ]; then bad "skipped — no wifi device name"; else
    CONN="$(nmcli -t -f GENERAL.CONNECTION device show "$WDEV" 2>/dev/null | cut -d: -f2-)"
    STATE="$(nmcli -t -f GENERAL.STATE device show "$WDEV" 2>/dev/null | cut -d: -f2-)"
    inf "GENERAL.CONNECTION : ${CONN:-<empty>}"
    inf "GENERAL.STATE      : ${STATE:-<empty>}"
    if [ -n "$CONN" ] && [ "$CONN" != "--" ] && echo "$STATE" | grep -q "connected"; then
        ok "usable — Zen Shell can read the live profile from here"
    else
        bad "not usable"
    fi
fi

# ── source 3 ────────────────────────────────────────────────────────────────
hr "SOURCE 3 — nmcli connection show --active (per profile)"
RAW="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null)"
if [ -z "$RAW" ]; then bad "no active connections at all"; else
    inf "raw:"; echo "$RAW" | sed 's/^/      /'
    TYPES="$(echo "$RAW" | awk -F: '{print $NF}' | sort -u | tr '\n' ' ')"
    inf "TYPE spellings present: $TYPES"
    if echo "$RAW" | grep -qE ':(802-11-wireless|wifi)$'; then
        ok "a wireless profile is active"
        WHICH="$(echo "$RAW" | grep -E ':(802-11-wireless|wifi)$' | sed -E 's/:(802-11-wireless|wifi)$//')"
        inf "profile name: $WHICH"
        # THE trap hf177 fell into: profile name is not required to equal SSID.
        if [ -n "${WDEV:-}" ] && command -v iw >/dev/null 2>&1; then
            REAL="$(iw dev "$WDEV" link 2>/dev/null | grep -E '^\s*SSID:' | sed 's/.*SSID:[[:space:]]*//')"
            if [ -n "$REAL" ] && [ "$REAL" != "$WHICH" ]; then
                bad "profile name != SSID  ('$WHICH' vs '$REAL')"
                inf "this is what breaks matching when only source 3 answers"
            fi
        fi
    else
        bad "no line ends in 802-11-wireless or wifi"
        inf "→ this is the source that fails silently. Send this block."
    fi
fi

# ── scan cache ──────────────────────────────────────────────────────────────
hr "SCAN CACHE (--rescan no, what the panel lists)"
CACHE="$(nmcli -t -f in-use,bssid,ssid,signal,security device wifi list --rescan no 2>/dev/null)"
if [ -z "$CACHE" ]; then
    bad "cache EMPTY — the list would be blank"
    inf "hf180 keeps the previous list rather than blanking on this."
else
    N="$(echo "$CACHE" | grep -c .)"
    ok "$N rows cached"
    echo "$CACHE" | head -8 | sed 's/^/      /'
    MARK="$(echo "$CACHE" | awk -F: '{print $1}' | sort -u | tr -d '\n' | tr ' ' '_')"
    inf "in-use column values seen: '${MARK}'  (hf177+ accepts yes / * / 1 / true)"
    if [ -n "$WDEV" ] && command -v iw >/dev/null 2>&1; then
        B="$(iw dev "$WDEV" link 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)"
        if [ -n "$B" ]; then
            if echo "$CACHE" | tr 'A-Z' 'a-z' | grep -q "$(echo "$B" | tr 'A-Z' 'a-z' | sed 's/:/\\\\:/g')"; then
                ok "the BSSID you are associated to IS in the cache"
            else
                bad "the BSSID you are associated to is NOT in the cache"
                inf "exactly the hf179 failure: hf178 gated the SSID fallback"
                inf "on this, so nothing matched. hf180 ORs the three sources."
            fi
        fi
    fi
fi

# ── routing, for the "feels like dropping" question ─────────────────────────
hr "ROUTING (why a live link can still feel dead)"
ip route show default 2>/dev/null | sed 's/^/      /'
ACT="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -E ':(802-11-wireless|wifi)$' | sed -E 's/:(802-11-wireless|wifi)$//' | head -1)"
if [ -n "$ACT" ]; then
    M="$(nmcli -t -f ipv4.route-metric connection show "$ACT" 2>/dev/null | cut -d: -f2-)"
    inf "wifi profile '$ACT' ipv4.route-metric = ${M:-<unset>}"
    if [ "${M:-}" = "50" ]; then
        bad "set to 50 by an earlier Zen Shell hotfix — wifi BEATS your cable"
        inf "hand it back to ethernet with:"
        inf "  nmcli connection modify '$ACT' ipv4.route-metric \"\""
    fi
fi

# ════════════════════════════════════════════════════════════════════════════
# --why : the wifi is genuinely down. Find out why it went and why it has not
#         come back. Everything below is read-only.
# ════════════════════════════════════════════════════════════════════════════
if [ "${WHY:-0}" = 1 ]; then

hr "WHY 1 — the adapter"
if [ -n "${WDEV:-}" ]; then
    DRV="$(basename "$(readlink -f /sys/class/net/"$WDEV"/device/driver 2>/dev/null)" 2>/dev/null)"
    inf "device : $WDEV"
    inf "driver : ${DRV:-unknown}"
    MOD="$(cat /sys/class/net/"$WDEV"/device/modalias 2>/dev/null | cut -c1-40)"
    [ -n "$MOD" ] && inf "modalias: $MOD"
    # ── v8.0.0-alpha-hf182 — bus + provenance ──
    # An interface called wlan0 rather than wlpXsY means udev got no usable
    # path for it. In practice that is a USB dongle, or an out-of-tree driver
    # that does not populate the device properly — and both are strongly
    # associated with "connects, drops, never returns".
    DEVPATH="$(readlink -f /sys/class/net/"$WDEV" 2>/dev/null)"
    case "$WDEV" in
        wlan[0-9]*)
            bad "named '$WDEV', not wlpXsY — udev had no stable path for it" ;;
    esac
    case "$DEVPATH" in
        *"/usb"*)
            bad "this adapter is on the USB bus"
            USBDIR="$(dirname "$(dirname "$DEVPATH")")"
            for up in "$USBDIR" "$(dirname "$USBDIR")"; do
                if [ -f "$up/idVendor" ]; then
                    inf "USB ID : $(cat "$up/idVendor" 2>/dev/null):$(cat "$up/idProduct" 2>/dev/null)"
                    inf "product: $(cat "$up/product" 2>/dev/null || echo unknown)"
                    CTRL="$(cat "$up/power/control" 2>/dev/null)"
                    DELAY="$(cat "$up/power/autosuspend_delay_ms" 2>/dev/null)"
                    inf "power/control          : ${CTRL:-unknown}"
                    inf "autosuspend_delay_ms   : ${DELAY:-unknown}"
                    if [ "${CTRL:-}" = "auto" ]; then
                        bad "USB AUTOSUSPEND IS ON for this adapter."
                        inf "The kernel is allowed to power the dongle down while idle."
                        inf "It comes back as a dead link that NM does not always retry."
                        inf "Test right now (reverts on reboot):"
                        inf "  echo on | sudo tee $up/power/control"
                        inf "Then leave it a while and see if the drop stops."
                        inf "Make it stick — /etc/udev/rules.d/50-zen-wifi-nosuspend.rules:"
                        inf "  ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$(cat "$up/idVendor" 2>/dev/null)\", ATTR{idProduct}==\"$(cat "$up/idProduct" 2>/dev/null)\", ATTR{power/control}=\"on\""
                    fi
                    break
                fi
            done ;;
        *"/pci"*) inf "bus    : PCIe" ;;
    esac

    # In-tree drivers live under the kernel's own module tree. Anything from
    # DKMS or extramodules is third-party, and that is worth saying plainly.
    if [ -n "${DRV:-}" ]; then
        MODPATH="$(modinfo -n "$DRV" 2>/dev/null)"
        [ -n "$MODPATH" ] && inf "module : $MODPATH"
        case "$MODPATH" in
            *extramodules*|*dkms*|*updates*)
                bad "OUT-OF-TREE driver (DKMS / extramodules)."
                inf "Third-party Realtek USB drivers in particular are the most"
                inf "reported cause of connect-drop-never-return on Linux."
                inf "If an in-tree driver exists for this chip, prefer it." ;;
        esac
    fi

    case "${DRV:-}" in
        rtw88*|rtw89*|rtl*|8812*|8821*|88x2*|8188*|8192*)
            bad "Realtek. Its power-save handling is the single most common"
            inf "cause of 'connects then silently drops' on Linux."
            inf "Test:  echo 'options ${DRV} disable_aspm=1' | sudo tee /etc/modprobe.d/zen-wifi.conf" ;;
        iwlwifi)
            inf "Intel. Usually solid; check dmesg for firmware asserts below." ;;
        mt76*|mt79*) inf "MediaTek. Check for firmware crash lines in dmesg below." ;;
        ath9k|ath10k|ath11k|ath12k) inf "Atheros/Qualcomm." ;;
        "") bad "no driver bound — USB adapter unplugged, or module not loaded" ;;
    esac
else
    bad "no wifi device at all — is the adapter present? (lsusb / lspci)"
fi

hr "WHY 2 — power saving (the usual suspect)"
if [ -n "${WDEV:-}" ] && command -v iw >/dev/null 2>&1; then
    PS="$(iw dev "$WDEV" get power_save 2>/dev/null | sed 's/.*: //')"
    inf "iw power_save : ${PS:-unknown}"
    if [ "${PS:-}" = "on" ]; then
        bad "ENABLED. On many chipsets this drops the link under light load."
        inf "Test it right now (does not persist):"
        inf "  sudo iw dev $WDEV set power_save off"
        inf "Make it stick:"
        inf "  sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf <<<'[connection]"
        inf "  wifi.powersave = 2'"
    fi
fi
inf "power-profiles-daemon : $(powerprofilesctl get 2>/dev/null || echo 'n/a')"
if [ "$(powerprofilesctl get 2>/dev/null)" = "power-saver" ]; then
    bad "power-saver turns wifi power saving ON. Try 'balanced' and retest."
fi

hr "WHY 3 — the saved profile"
PROF="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | grep -E ':(802-11-wireless|wifi)$' | sed -E 's/:(802-11-wireless|wifi)$//' | head -5)"
if [ -z "$PROF" ]; then
    bad "NO saved wifi profile exists at all."
    inf "That alone explains 'never comes back' — there is nothing to come back to."
else
    echo "$PROF" | while read -r P; do
        [ -z "$P" ] && continue
        inf "── profile: $P"
        for K in connection.autoconnect connection.autoconnect-priority \
                 connection.autoconnect-retries 802-11-wireless.powersave \
                 802-11-wireless.hidden 802-11-wireless.bssid \
                 802-11-wireless.cloned-mac-address \
                 802-11-wireless-security.key-mgmt ipv4.route-metric; do
            V="$(nmcli -t -f "$K" connection show "$P" 2>/dev/null | cut -d: -f2-)"
            printf '       %-42s %s\n' "$K" "${V:-<unset>}"
        done
        AC="$(nmcli -t -f connection.autoconnect connection show "$P" 2>/dev/null | cut -d: -f2-)"
        [ "$AC" = "no" ] && bad "autoconnect is OFF → it will never rejoin on its own"
        CM="$(nmcli -t -f 802-11-wireless.cloned-mac-address connection show "$P" 2>/dev/null | cut -d: -f2-)"
        case "$CM" in
            random|stable) bad "MAC randomisation ($CM) — some routers refuse or lease-conflict."
                           inf "  nmcli connection modify '$P' 802-11-wireless.cloned-mac-address permanent" ;;
        esac
    done
fi

hr "WHY 3b — can NetworkManager actually READ the key?"
if [ -n "$PROF" ]; then
    echo "$PROF" | while read -r P; do
        [ -z "$P" ] && continue
        F="$(nmcli -t -f 802-11-wireless-security.psk-flags connection show "$P" 2>/dev/null | cut -d: -f2-)"
        K="$(nmcli -s -t -f 802-11-wireless-security.psk connection show "$P" 2>/dev/null | cut -d: -f2-)"
        S="$(nmcli -t -f 802-11-wireless-security.key-mgmt connection show "$P" 2>/dev/null | cut -d: -f2-)"
        inf "── $P : key-mgmt=${S:-none} psk-flags=${F:-unset} key=$([ -n "$K" ] && echo readable || echo UNREADABLE)"
        if [ -z "$S" ] || [ "$S" = "none" ]; then ok "open network, no key needed"
        elif [ -n "$K" ] && { [ -z "$F" ] || [ "${F%% *}" = "0" ]; }; then ok "system-owned and readable"
        else
            bad "NM CANNOT READ THIS KEY."
            inf "psk-flags 1 means agent-owned: NM stores nothing and asks a"
            inf "running secret agent (nm-applet / GNOME Shell / plasma-nm)."
            inf "Zen Shell registers no agent, so under Hyprland the key is"
            inf "unreachable and every activation ends in:"
            inf "    no secrets: No agents were available for this request"
            inf "Repair it permanently — NM keeps the key itself afterwards:"
            inf "  nmcli connection modify '$P' 802-11-wireless-security.psk 'YOUR_PASSWORD'"
            inf "  nmcli connection modify '$P' 802-11-wireless-security.psk-flags 0"
            inf "  nmcli connection up '$P'"
        fi
    done
fi

hr "WHY 4 — what NetworkManager says happened"
if command -v journalctl >/dev/null 2>&1; then
    J="$(journalctl -b -u NetworkManager --no-pager 2>/dev/null \
         | grep -iE "$WDEV|wlan|wlp|supplicant|deauth|disconnect|association|link is not ready" \
         | tail -25)"
    if [ -n "$J" ]; then echo "$J" | sed 's/^/      /'
    else inf "nothing wifi-related this boot"; fi
else
    bad "no journalctl"
fi

hr "WHY 5 — what the kernel says"
K="$(dmesg 2>/dev/null | grep -iE 'iwlwifi|rtw|rtl|mt7|ath1|ath9|ath12|brcm|deauth|firmware|wlan|wlp' | tail -20)"
if [ -n "$K" ]; then echo "$K" | sed 's/^/      /'
else inf "nothing (dmesg may need sudo: sudo dmesg | grep -i wlan)"; fi

hr "WHY 6 — regulatory domain"
command -v iw >/dev/null 2>&1 && iw reg get 2>/dev/null | head -6 | sed 's/^/      /'
inf "A domain of 00 (world) blocks many 5GHz channels — if the AP moved the"
inf "5GHz radio to a channel your regdom forbids, the link dies and will not"
inf "re-establish while the router stays there."

hr "WHY 7 — the AP itself"
inf "From the scan above, these BSSIDs share one router:"
nmcli -t -f bssid,ssid,chan,signal,security device wifi list --rescan no 2>/dev/null \
  | sed 's/\\:/:/g' | head -8 | sed 's/^/      /'
inf ""
inf "Same SSID on several BSSIDs = band steering or a mesh node. The AP can"
inf "kick you off one radio expecting you to land on another; wpa_supplicant"
inf "does not always take the hint. Pin one radio to test:"
inf "  nmcli connection modify '<profile>' 802-11-wireless.bssid <BSSID>"
inf "Undo with an empty value once you know whether that was it."
inf ""
inf "Security showing 'WPA1 WPA2' means the AP allows the old WPA/TKIP suite."
inf "Forcing the modern one is worth a try:"
inf "  nmcli connection modify '<profile>' 802-11-wireless-security.proto rsn"
inf "  nmcli connection modify '<profile>' 802-11-wireless-security.pairwise ccmp"
inf "  nmcli connection modify '<profile>' 802-11-wireless-security.group ccmp"

fi   # end --why

hr "done"
if [ "${WHY:-0}" != 1 ]; then
    echo "  Wifi genuinely down rather than mis-reported? Run again with --why"
    echo "  for driver, power-save, profile, journal and AP analysis."
fi
echo "  Send this whole output and the wifi badge can be settled for good."
