# v6.16.4.12.9.9 — Modori (戻り) · hotfix 9

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.8 — Modori hotfix 8

## Summary

Major redesign of the WiFi + Bluetooth tabs in the Control Panel
(Super+C). User reported the previous compact rows were "ang
hirap mag-select" — tap targets too small (60×24px Connect
buttons), no Saved Networks distinction, no Forget option, no
manual rescan, and Bluetooth only showed currently-connected
devices (no way to reconnect a paired-but-disconnected device,
no way to scan for new devices to pair).

This drop ports the convenience patterns from Paul's previous
GTK4 `wifi_selector.py` standalone tool directly into the
Control Panel, plus brings the Bluetooth tab to feature parity.

## What you get

### WiFi tab redesign

- **Rescan button** at the top right — explicit `nmcli device
  wifi rescan` with immediate UI refresh.
- **SAVED NETWORKS section** at top — only saved SSIDs that are
  currently in scan range. Shows a green-tinted highlight + "✓
  Connected" sub-label for the active one. Other saved networks
  show "Saved · tap to reconnect · {signal}%".
- **Tap-to-reconnect** for saved networks — uses
  `nmcli connection up` directly (instant, no zenity prompt
  since credentials are already stored).
- **Forget button (trash icon)** per saved row — one-tap
  `nmcli connection delete`.
- **AVAILABLE NETWORKS section** below — networks not in saved
  list, sorted by signal strength.
- **Larger row height** (44px instead of 36px) — easier to tap.
- **Whole-row tap target** for connect (no tiny "Connect"
  button to aim at).
- **Signal-strength colored icons**:
  - ≥ 60% → green
  - ≥ 35% → yellow
  - < 35% → grey
- **Lock icon** on secured networks.
- **Sub-label per row** showing "{signal}% · {security}" or
  "{signal}% · Open" for unencrypted networks.

The existing `connectWifi()` flow (saved-creds preflight +
zenity password prompt for new secured networks) is unchanged
— still the right behavior for first-time connection.

### Bluetooth tab redesign

- **Scan toggle button** at top right — starts/stops
  `bluetoothctl scan on` in the background. While scanning,
  the button shows "Stop scan" with a blue-tinted highlight.
- **CONNECTED section** — devices currently connected. Green
  highlight + "Connected · {MAC}" sub-label. Larger Disconnect
  button (90×30 instead of 70×24).
- **PAIRED · TAP TO RECONNECT section** — devices that are
  paired/bonded but currently disconnected. Tap the row to
  `bluetoothctl connect <MAC>`. Trash button on each row to
  unpair (`bluetoothctl remove`).
- **NEARBY · TAP TO PAIR section** — only visible while scan is
  active. Shows discovered devices not yet paired/connected.
  Tap the row to pair + trust + connect in one shot (the trust
  step is critical — without it the device disconnects after
  first sleep cycle).
- **Empty state** with helpful hint: "No paired or connected
  devices. Tap 'Scan nearby' to find devices."

### ConnectivityService additions

New properties:
- `savedWifiNetworks` — array of saved SSIDs (filtered from
  `nmcli connection show` to type `802-11-wireless`)
- `btPairedDevices` — paired-but-disconnected devices (Paired
  set minus Connected set)
- `btNearbyDevices` — scan-discovered devices (all known minus
  paired minus connected)
- `btScanning` — boolean, true while scan is active

New functions:
- `forgetWifi(ssid)` — `nmcli connection delete`
- `scanWifi()` — `nmcli device wifi rescan` + immediate poll
- `reconnectWifi(ssid)` — `nmcli connection up` (skips zenity
  preflight for known networks)
- `startBtScan()` / `stopBtScan()` — toggle bluetoothctl scan
  on/off (run as detached background process)
- `pairBtDevice(mac)` — pair + trust + connect chain
- `unpairBtDevice(mac)` — `bluetoothctl remove`

The `update()` poll was extended to include three new sections:
- `WIFI_SAVED` — `nmcli connection show` filtered to
  802-11-wireless
- `BT_PAIRED` — `bluetoothctl devices Paired`
- `BT_NEARBY` — `bluetoothctl devices` (full known-devices
  list, gets filtered against paired+connected to extract
  scan results)

## Why the previous tabs were broken

The original WiFi tab had three structural problems:

1. **No saved/available split.** Every visible network looked
   the same regardless of whether you'd ever connected to it
   before. Reconnecting to your home WiFi required reading
   small text to find your SSID in a list of nearby networks.

2. **Tiny Connect buttons.** 60×24px buttons in a 36px-tall
   row left only ~80% of the row height for the actual click
   target. With a 0.5° angle to the screen the precision
   needed was annoying.

3. **No rescan.** Once the cached scan was stale (e.g. you
   moved rooms or toggled WiFi off and back on), the network
   list could be wrong with no way to refresh it short of
   manually `nmcli device wifi rescan` from a terminal.

The Bluetooth tab had its own issue: it ONLY showed currently
connected devices. If your wireless headphones were paired
but disconnected (e.g. they auto-disconnected after sleep),
there was no way to reconnect from the Control Panel — you had
to open `blueman-manager` or run `bluetoothctl connect <MAC>`.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.9. |
| `zen-shell-v5/ConnectivityService.qml` | New properties: `savedWifiNetworks`, `btPairedDevices`, `btNearbyDevices`, `btScanning`. New functions: `forgetWifi`, `scanWifi`, `reconnectWifi`, `startBtScan`, `stopBtScan`, `pairBtDevice`, `unpairBtDevice`. New Process instances: `btScanProc`, `btScanStopProc`. `update()` extended with WIFI_SAVED, BT_PAIRED, BT_NEARBY sections. `_parseAll` extended with corresponding parsing logic + set-based filtering to split paired/nearby cleanly. |
| `zen-shell-v5/ControlPanel.qml` | WiFi tab ColumnLayout fully rewritten: refresh button row, saved/available section split, larger 44px rows, whole-row tap targets, forget buttons, signal-strength colored icons, lock icons. Bluetooth tab ColumnLayout fully rewritten: scan toggle button, connected/paired/nearby section split, tap-to-reconnect for paired devices, tap-to-pair for nearby devices, trash button to unpair, larger 30/44/48px rows. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.9.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.9
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

After install:

1. `Super+C` → Control Panel.
2. Click WiFi tab. Should see "Rescan" button at top right.
   Below it, "SAVED NETWORKS" section (if any of your saved
   networks are in range), then "AVAILABLE NETWORKS" below.
3. Click Bluetooth tab. Should see "Scan nearby" button. Below
   it, sections for currently-connected, paired-but-not-
   connected, and (when scanning) nearby devices.

Test scenarios:

- **Reconnect to saved WiFi**: Tap row in SAVED NETWORKS
  section. Should reconnect instantly (no password prompt).
- **Forget saved WiFi**: Tap trash icon on saved row. Network
  removed from saved list immediately.
- **Connect to new WiFi**: Tap row in AVAILABLE NETWORKS. If
  secured, zenity password prompt appears. If open, connects
  immediately.
- **Reconnect Bluetooth**: Turn paired headphones off and on
  again. Should appear in PAIRED section. Tap row → reconnect.
- **Pair new Bluetooth device**: Tap "Scan nearby" → wait for
  device to appear in NEARBY section → tap row → pair+trust+
  connect chain runs.

## Carry-forward from Modori .9.8

All Modori .9.8 features preserved:

- GTK Dark Mode toggle (Super+C → Dark Mode row)
- Bulletproof sidebar user labels (env-fallback resolution)
- Smart-contrast theme engine
- Modori Dark + Light themes + paired procedural wallpapers
- Default wallpaper switched to Modori Dark on fresh install
- Settings persistence fix
- Slider-drag save corruption fix
- Left/Right panel position cards hidden + L/R-to-Bottom
  migration safety net
- Updated README image URLs pointing to actual demo repo files
- All Tachiagari .7.1 features

## Wala tayong babawasan

The previous WiFi + Bluetooth functionality is preserved — every
existing `connectWifi`, `disconnectWifi`, `disconnectBtDevice`
call still works exactly as before. The redesign is additive:
new sections, new buttons, new tap targets. Anything you could
do before, you can still do, but now there are also more ways
to do it.

## Future enhancements (deferred)

- **In-shell password dialog** instead of zenity. Would be a
  proper QML PopupWindow with PasswordEntry + Connect/Cancel
  buttons matching the shell's theme. Tracked in
  BETA-BLOCKERS.md.
- **Show signal-strength bars** as actual bar count icon
  (currently single fa-wifi glyph, color-coded). Nerd Font has
  separate glyphs (`\uf683` `\uf682` `\uf681`) for tier
  display.
- **Auto-rescan** every 30s while WiFi tab is open (currently
  only initial poll + manual rescan).
- **Bluetooth audio routing** — when connecting BT headphones,
  prompt to switch audio sink. Requires PipeWire integration.
- **Forget confirmation dialog** to prevent accidental tap on
  the trash icon. Currently it acts immediately.
