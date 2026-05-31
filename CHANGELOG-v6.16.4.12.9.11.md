# v6.16.4.12.9.11 — Modori (戻り) · hotfix 11

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.10 — Modori hotfix 10

## Summary

Three real bugs reported on the Modori .9.10 WiFi+BT redesign:

1. **Tap on WiFi rows did nothing** — couldn't connect to new
   networks, couldn't reconnect to saved networks, couldn't
   trigger the password prompt.
2. **Open networks confusing** — looked the same as secured but
   tapping them also did nothing (same root cause as #1).
3. **WiFi connect didn't take over from LAN** — when ethernet
   was plugged in, tapping a WiFi network technically connected
   it but the default route stayed on ethernet. Browser, apps,
   etc. kept routing through LAN.

## What this drop fixes

### Bug #1 + #2 — Flickable was eating the tap

**Root cause.** The WiFi and Bluetooth lists live inside a
`Flickable`. When the list overflows the visible area,
`Flickable.interactive` becomes `true` and Flickable starts
intercepting mouse press events to detect potential drag-to-
scroll gestures. The MouseArea on each WiFi/BT row never sees
the press — Flickable swallows it first as part of its drag
detection.

The old "Connect" button design (60×24px tiny target) sort of
worked because it was a small target inside a flush row, and
Flickable's gesture recognizer was less aggressive on small
targets. The new "whole row tappable" 44px-tall design hit the
threshold where Flickable consistently grabbed the press as a
potential scroll start.

**Fix.** `preventStealing: true` on every WiFi/BT row
MouseArea. This is the standard Qt fix for this pattern — tells
Flickable "this MouseArea owns its press events, do not steal
them for gesture recognition". Applied to all 9 row MouseAreas:

| MouseArea id | Where |
|---|---|
| `savedRowMouse` | WiFi saved network row (tap to reconnect) |
| `forgetMouse` | WiFi forget button (trash icon) |
| `availRowMouse` | WiFi available network row (tap to connect) |
| `wifiRefreshMouse` | WiFi rescan button |
| `btDiscMouse` | BT disconnect button |
| `pairedRowMouse` | BT paired row (tap to reconnect) |
| `btForgetMouse` | BT unpair button (trash icon) |
| `nearbyRowMouse` | BT nearby row (tap to pair) |
| `btScanMouse` | BT scan toggle |

### Bug #2.5 — Open networks treated as secured

**Root cause.** `nmcli -t -f active,ssid,signal,security device
wifi list` outputs the literal string `"--"` in the security
field for open networks (this is nmcli's null-marker convention
for `-t` terse mode). The parser treated `security` as a
truthy string of length 2 — so:

- The lock icon `\uf023` showed on open networks (visually
  confusing — open networks looked secured)
- The connectWifi flow saw `isSecured = true` and tried to open
  the password prompt for open networks (which would then fail
  to connect because nmcli rejects a password on an open SSID)

**Fix.** Normalize `security === "--"` to empty string `""` in
the WIFI_STATUS parser. Open networks now show no lock icon
and connect directly with no password prompt.

### Bug #3 — Default route stayed on LAN

**Root cause.** NetworkManager's default IPv4 route metrics are:

- Ethernet: **100** (lowest = highest priority)
- WiFi: **600**
- WWAN: **700**

Lower metric = higher priority. So when both ethernet and WiFi
are connected, the kernel picks ethernet for the default route
unless you explicitly tell NM otherwise. This is documented NM
behavior — you connected the cable, NM assumes you want the
faster, more reliable link.

For a workflow where you tap a WiFi network specifically because
you want to USE that WiFi (e.g. troubleshooting, testing, or
because the LAN is going to be unplugged soon), having the
route stay on LAN is the wrong default.

**Fix.** Every explicit user-tap-to-connect path now chains a
`nmcli connection modify '<SSID>' ipv4.route-metric 50
ipv6.route-metric 50` call after the connect. With wifi metric
50 < ethernet metric 100, the kernel picks wifi for the default
route. Persistent — also applied on future auto-reconnects of
that saved connection.

The chain uses `;` not `&&` so a metric-set failure doesn't
roll back the connect itself. Worst case is "connected but
metric unchanged, default route still LAN" — same as before
the fix. Safe degradation.

Applied to all 4 connect paths:

- Saved network reconnect (`reconnectWifi(ssid)`)
- Open network direct connect
- Secured network with zenity fallback
- Secured network with in-shell PasswordPromptService callback

The legacy `connectWifi(ssid, password)` direct-string form
also gets the metric tail.

### Bonus fix — actionRunner re-entry

While digging through the action layer, found a separate latent
bug. `Process { id: actionRunner; running: false }` was reused
for every WiFi/BT/audio action. Setting `actionRunner.running =
true` while it was already `true` is a no-op in Qt — the
property change is suppressed because old value === new value.
So if you tapped Connect twice quickly, the second tap was
silently dropped.

**Fix.** New `_runAction(cmdArr)` helper resets `running = false`
first, then sets `command + running = true`. Forces Qt to fire
the change. All 19 callsites of the old pattern were rewritten
to use `_runAction()` via a single bulk pass.

Also added an `onExited` handler on `actionRunner` that triggers
an immediate `update()` plus a delayed `update()` at +1.5s
(catches slow nmcli convergence). User taps Connect, sees the
result within 1-2 seconds instead of waiting for the next 5s
poll.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.11. |
| `zen-shell-v5/ConnectivityService.qml` | (1) New `_runAction(cmdArr)` helper that resets `running=false` first then sets `command + running=true` to force Qt re-trigger. (2) `actionRunner` now has `onExited` handler that fires immediate `update()` + delayed `update()` at +1.5s via a new `postActionRefreshTimer`. (3) All 19 `actionRunner.command = ... ; actionRunner.running = true` callsites rewritten to `_runAction([...])` via single bulk pass. (4) Parser `security === "--"` normalized to empty string so open networks aren't treated as secured. (5) All connect paths chain `nmcli connection modify '<SSID>' ipv4.route-metric 50 ipv6.route-metric 50` after the connect to make WiFi the preferred default route over LAN. (6) `reconnectWifi` also gets the metric tail. (7) actionRunner stderr collected and warned to console on non-empty output (hidden errors before — now visible in `journalctl --user -t quickshell`). |
| `zen-shell-v5/ControlPanel.qml` | `preventStealing: true` added to 9 WiFi/BT row MouseAreas (savedRowMouse, forgetMouse, availRowMouse, btDiscMouse, pairedRowMouse, btForgetMouse, nearbyRowMouse, wifiRefreshMouse, btScanMouse). Stops the parent `Flickable` from grabbing tap events as drag-to-scroll candidates when the list overflows. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.11.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.11
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

## Test scenarios

### Tap-to-connect (Bug #1, #2)

1. **Open Control Panel** (Super+C) → WiFi tab.
2. **Tap an open network** in AVAILABLE NETWORKS. Should connect
   immediately, no password prompt. The row flips into SAVED
   NETWORKS within ~3s.
3. **Tap a secured network** in AVAILABLE NETWORKS. Password
   prompt should pop up centered on screen.
4. **Tap a saved network** in SAVED NETWORKS. Should reconnect
   instantly without password prompt.
5. **Tap the trash icon** on a saved row. Network removed from
   saved list within ~3s.

### Bluetooth tap actions

1. **Open Bluetooth tab.**
2. **Tap "Scan nearby"**. Button should flip to "Stop scan" with
   blue tint.
3. **Tap a nearby device** (when one appears). Pair+trust+connect
   chain should run.
4. **Tap a paired device** (paired but not connected). Should
   reconnect.
5. **Tap Disconnect** on a connected device. Should disconnect.

### Route metric (Bug #3)

After connecting to a WiFi while LAN is plugged in, verify the
default route went to wifi:

```bash
ip route | grep default
# Expected:
# default via <gw> dev wlan0 proto dhcp metric 50
# default via <gw> dev eth0 proto dhcp metric 100
#
# wifi metric 50 < ethernet metric 100 → wifi wins default route.
# Verify with:
ip route get 1.1.1.1
# Should show "dev wlan0" (or whatever your wifi interface is).
```

If you want to revert wifi back to "lower priority than LAN" for
a specific network:

```bash
nmcli connection modify '<SSID>' ipv4.route-metric "" ipv6.route-metric ""
```

(Empty string clears the override → falls back to NM defaults.)

If you want to disable the auto-metric behavior entirely, you can
set `connection.permissions=off` on the wifi connection or just
not tap-connect from the Control Panel (use `nmcli` directly).

## Carry-forward

All Modori .9.10 features preserved:

- In-shell WiFi password prompt at WlrLayer.Overlay
- WiFi+BT Control Panel redesign (saved/available split, refresh,
  forget, scan, pair, larger tap targets)
- GTK Dark Mode toggle
- Bulletproof sidebar user labels
- Smart-contrast theme engine
- Modori Dark + Light themes + paired procedural wallpapers
- Default wallpaper switched to Modori Dark on fresh install
- Settings persistence fix
- Slider-drag save corruption fix
- L/R panel position cards hidden + L/R-to-Bottom migration
- All Tachiagari .7.1 features

## Wala tayong babawasan

Pure additive fixes. No UI surface removed, no API surface
removed. Existing `connectWifi(ssid, security)` and
`connectWifi(ssid, password)` signatures unchanged. The metric
tail is appended to the bash chain, not a separate API surface.

## Future enhancements (still deferred)

- Wrong-password feedback (re-open prompt with `setError` if
  authentication fails)
- "Connect automatically" checkbox in password prompt
- WPA-Enterprise (802.1X) multi-field form
- Confirm dialogs for forget/unpair (currently fire on single tap)
- Auto-rescan WiFi every 30s while tab is open
- Bluetooth audio sink routing prompt
- Multi-bar Nerd Font signal-strength glyphs
