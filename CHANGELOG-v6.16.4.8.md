# Zen Shell v6.16.4.8 — WiFi Connect (really this time) + Color picker left-side

**Release date:** 2026-04-24
**Base:** v6.16.4.7
**Severity:** MEDIUM — two alpha follow-ups

---

## Paul's report

> *"hindi padin maka connect sa wifi connectquick settings kapag
>   click ko button wala nangyayari tapos dun sa color picker
>   naman sa general dapat ata nasa left side pra ensure na
>   makakaclick ng colors"*

Two items:
1. v6.16.4.6's WiFi Connect fix didn't actually work
2. Move the color picker to the left of the swatch for guaranteed
   clickability

---

## Bug 1 — WiFi Connect still broken (4.6 was broken too)

### What 4.6 tried

```js
if (arguments.length >= 2 && typeof arguments[1] === "string"
    && arguments[1].length > 0
    && !["--", "WPA2", "WPA", "WEP", "WPA3"].includes(arguments[1])) {
    // Treat arg2 as password
```

The intent: detect whether the caller passed a security string
(like "WPA2") or an actual password. The check excludes exact
matches against a whitelist.

### Why it failed

`nmcli -t -f active,ssid,signal,security device wifi list` returns
security values like:

- `"WPA2"`
- `"WPA1 WPA2"`
- `"WPA2 802.1X"` ← composite
- `"WPA3"`
- `"WPA2 WPA3"` ← composite

The whitelist only contained exact strings. Any composite like
`"WPA2 802.1X"` failed the whitelist check → treated as a password
→ fed literally to `nmcli ... password "WPA2 802.1X"` → nmcli
rejects that as wrong password → silent failure.

Paul tapped Connect on KiyuFamilyFibr which had `"WPA2 802.1X"`
security → button felt dead.

### 4.8 fix — explicit named arg pattern

```js
function connectWifi(ssid, security, password) {
    const sec = (typeof security === "string") ? security : ""
    const pwd = (typeof password === "string") ? password : ""
    // ...
    const isSecured = sec.length > 0
                   && sec !== "--"
                   && sec.toLowerCase() !== "none"
```

No more type-sniffing. Security is always arg 2, password is
always arg 3. Caller passes `modelData.security` to arg 2 — any
non-empty non-sentinel string means "secured network, prompt
for password if no saved creds."

### New: WiFi audit log

Added logging to `~/.cache/zen-shell/wifi.log`:

```
[14:32:01] connect 'KiyuFamilyFibr' secured=1
[14:32:01] using saved connection profile
Device 'wlp3s0' successfully activated with 'KiyuFamilyFibr'.
```

If Connect doesn't work, this log shows exactly where the flow
broke: did it enter saved-creds path? Did zenity prompt open?
Did nmcli error? Previously invisible, now debuggable.

### Check the log

```bash
tail -20 ~/.cache/zen-shell/wifi.log
```

### Required: zenity

For secured networks without saved creds, the prompt uses zenity.
If zenity isn't installed:

```bash
paru -S zenity
# or
sudo pacman -S zenity
```

Zenity is in the recommended deps and `--bootstrap` installs it
automatically. If you copied QML files manually, might be missing.

---

## Feature 2 — Color picker opens LEFT of swatch

### Why the switch

4.6 moved popup positioning from broken coordinates to proper
`mapToItem` with clamp. That worked — popup stayed on-screen.
BUT the swatches in GeneralPage's Theme Palette are right-aligned
in HMRow layouts, so "below" often placed the popup near the
right edge of the Settings window. The Apply button could end up
pressed against the window border.

Paul's call: put it LEFT of the swatch instead. More reliable
clickable area, plus it stays inside the content area where the
existing Settings UI already lives.

### 4.8 fix — multi-position fallback

Priority order:

1. **LEFT** of swatch (new default)
2. **RIGHT** of swatch (if no room on left)
3. **BELOW** swatch (if no room left or right)
4. **ABOVE** swatch (last resort)

Y is centered vertically against the swatch for side placements.
X maintains swatch-left-edge alignment for below/above.

All positions clamp to stay within parent window bounds with a
12px margin. First position that fully fits wins.

### Why fallbacks matter

If you collapse the Settings window very narrow, there might not
be room to the left. Then popup goes right. If your window is
maximized at 4K, left works fine. The code picks whichever
placement guarantees the popup is fully visible AND clickable.

---

## Files changed from 4.7

```
UPDATED
  zen-shell-v5/ConnectivityService.qml ← rewrote connectWifi,
                                         added wifi.log
  zen-shell-v5/ColorSwatch.qml          ← multi-position popup
                                         (LEFT default)
  zen-shell-v5/ZenVersion.qml           ← bump to v6.16.4.8
  install.sh                             ← banner
NEW
  CHANGELOG-v6.16.4.8.md                 ← this file
```

All v6.16.4.7 features carry byte-identical (including Super+T
fix and Dark Mode toggle).

---

## Install + verify

```bash
tar -xzf zen-shell-v6.16.4.8.tar.gz
cd zen-shell-v6.16.4.8
./install.sh
~/.local/bin/zs-restart.sh
```

### Test 1 — WiFi Connect

1. Super+C → Connectivity
2. Tap Connect next to a new secured network
3. **Zenity password dialog must appear** (if it doesn't, check
   `which zenity`)
4. Type password → OK → within ~2s, network connects
5. Verify via log:
   ```bash
   tail -20 ~/.cache/zen-shell/wifi.log
   ```
   Should show the connect attempt and nmcli result.

If the zenity dialog DOES appear but nmcli rejects the password,
check the log for the actual error. Common reasons:
- "Secrets were required, but not provided" — password was empty
- "The wireless network is already active" — already connected
- "Connection activation failed: No suitable device" — wrong
  interface name (contact me if this happens)

### Test 2 — Color picker position

1. Settings → General → Theme Palette
2. Click "Background (bg0)" swatch
3. Popup should appear **to the LEFT** of the swatch (not below,
   not right)
4. Entire popup including Apply button is fully visible
5. Click Apply → popup closes, color applied
6. Try other palette rows — same LEFT behavior
7. If you resize the Settings window very narrow, popup falls back
   to RIGHT or BELOW as needed

---

## Running tally

```
v6.16.4   — Panic keybind (3 bugs)
v6.16.4.1 — Panic script hotfix (LAST STABLE ON MAIN)
v6.16.4.2 — Widget scale + display resolution (incomplete)
v6.16.4.3 — Widget scale actually working + oscillation killed
v6.16.4.4 — Gaps preserved after Displays apply
v6.16.4.5 — Start Menu pinned tile breathing room
v6.16.4.6 — Wallpaper cols + (broken) WiFi + ColorPicker v1
v6.16.4.7 — Super+T + Dark Mode toggle
v6.16.4.8 — WiFi (actually) + ColorPicker LEFT-side ← YOU'RE HERE
```

9 alpha iterations over 2 days. The WiFi bug is the second-time-
fixing on this feature, first attempt missed the composite
security string case.
