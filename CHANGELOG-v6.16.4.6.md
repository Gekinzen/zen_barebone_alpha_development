# Zen Shell v6.16.4.6 — Three alpha bug fixes

**Release date:** 2026-04-24
**Base:** v6.16.4.5
**Severity:** MEDIUM — three independent UX bugs Paul hit testing alpha

---

## Paul's report

> *"kapag click ko refresh sa wallpaper ko etc nagiging 5 rows
>   dapat tig 4 rows lang, tapos yun sa quick settings hindi
>   ma click yun connect button tas pangatlo yung pag select
>   ng colors hindi maka pag select color apply yan yung mga
>   bugs."*

Three separate bugs, three separate root causes, three different
files touched. None are connected to each other.

---

## Bug 1 — Wallpaper grid 5 columns → 4 columns

### Symptoms

After refresh, wallpaper selector showed 5 thumbnails per row.
At monitor scale 1.25× or on narrower Settings windows, each
thumbnail became too small to preview properly. User preference:
4 per row for bigger previews.

### Fix

`WallpaperPage.qml`:

```qml
GridLayout {
    columns: 4                   // was 5
    Component.onCompleted: WallpaperServiceV5.wallpapersPerPage = 4 * 4
}
```

Page size updated from 20 (5×4) to 16 (4×4) per page.

---

## Bug 2 — Connect button in Quick Settings did nothing

### Symptoms

Tapped "Connect" next to a secured Wi-Fi network. Nothing
visible happened. Button felt broken.

### Root cause

`nmcli device wifi connect <SSID>` without a password argument
silently fails on secured networks. The click handler fired, the
Process ran, nmcli exited with an auth error — but there was no
UI feedback, and no password prompt either. User saw nothing =
button "not working."

### Fix

Rewrote `ConnectivityService.connectWifi(ssid, security)` with a
bash one-liner that does:

1. **Saved-creds preflight** — if NetworkManager already has a
   connection profile for this SSID, use `nmcli connection up
   <SSID>` directly. Works for networks the user has connected
   to before.
2. **Zenity password prompt** — if no saved creds AND the network
   is secured, pop a `zenity --password` dialog. Pass the entered
   password to `nmcli device wifi connect ... password ...`.
3. **Open networks** — direct connect, no prompt.

Also updated the ControlPanel.qml caller to pass `modelData.security`
so the service knows whether to prompt.

```qml
// Before
onClicked: ConnectivityService.connectWifi(modelData.ssid)

// After
onClicked: ConnectivityService.connectWifi(modelData.ssid, modelData.security)
```

Legacy 2-arg signature `connectWifi(ssid, password)` still works
— the new code detects whether arg 2 is a security string
("WPA2"/"WPA"/"WEP") or an actual password and routes accordingly.

---

## Bug 3 — Color picker Apply button unreachable

### Symptoms

Open a color swatch (Active border, Inactive border, or any theme
palette row). Color picker popup appears — **but floating to the
right of the Settings window, partially off-screen**. Apply button
is visible but clicking does nothing.

### Root cause

`ColorSwatch.qml` Popup used:

```qml
Popup {
    x: swatchRect.x
    y: swatchRect.y + swatchRect.height + 6
```

These coordinates reference the `RowLayout`'s coordinate system.
But Qt Quick Popups render in the **window Overlay**, where (0,0)
is the Settings window's top-left corner — not the RowLayout's.

On deeply-nested swatches (inside Flickable inside HMRow inside
HMSection inside page Flickable), the coord offset made the popup
end up way past the Settings window boundary. The swatch thought
it was placing the popup "just below and aligned," but Overlay
coords pushed it ~400-600px to the right.

Apply button was technically rendered, but its click area extended
off the window clip bounds — pointer events outside the window
don't reach Popup children.

### Fix

Switched to imperative positioning via `mapToItem`:

```qml
function _reposition() {
    if (!parent) return
    const pt = swatchRect.mapToItem(parent, 0, swatchRect.height + 6)
    let nx = pt.x, ny = pt.y
    // Clamp within parent window bounds
    if (nx + width + 16 > parent.width) nx = parent.width - width - 16
    if (ny + height + 16 > parent.height) ny = parent.height - height - 16
    if (nx < 16) nx = 16
    if (ny < 16) ny = 16
    x = nx; y = ny
}

onOpened: {
    _reposition()
    // ... existing init code
}
```

`mapToItem(parent, 0, h)` converts the swatch's position into the
Overlay's coordinate system — same space as Popup.x/y. Plus the
clamping ensures the popup is always fully on-screen and clickable.

---

## Files changed from 4.5

```
UPDATED
  zen-shell-v5/WallpaperPage.qml        ← grid 5→4 columns
  zen-shell-v5/ConnectivityService.qml  ← saved-creds check + zenity prompt
  zen-shell-v5/ControlPanel.qml         ← pass security to connectWifi
  zen-shell-v5/ColorSwatch.qml          ← mapToItem positioning + clamp
  zen-shell-v5/ZenVersion.qml           ← bump to v6.16.4.6
  install.sh                             ← banner
NEW
  CHANGELOG-v6.16.4.6.md                 ← this file
```

All v6.16.4.5 features carry byte-identical. Still on alpha channel.

---

## Install + verify

```bash
tar -xzf zen-shell-v6.16.4.6.tar.gz
cd zen-shell-v6.16.4.6
./install.sh
~/.local/bin/zs-restart.sh
```

### Test 1 — Wallpaper grid

1. Settings → Wallpaper
2. Count columns: must be **4** (not 5)
3. Pagination: 16 wallpapers per page (4 rows × 4 cols)

### Test 2 — Wi-Fi Connect

1. Super+C → Connectivity
2. Tap Connect next to a network you've never connected to
3. **Zenity password dialog** should appear
4. Type password → OK → wait ~2 seconds → network connects
5. Tap Connect next to a network you've connected before
   → should connect directly (no prompt)

### Test 3 — Color picker Apply

1. Settings → General → Theme Palette section
2. Click any color swatch (Background, Surface, etc.)
3. Popup should appear **attached to the swatch** (not floating
   off to the right)
4. Drag the HS canvas crosshair, adjust lightness slider
5. Click Apply
6. Popup closes, color change visible immediately across the UI
7. Repeat with border colors and active/inactive colors — same
   behavior

---

## Known caveats

- **Bug 2**: requires `zenity` installed. It's in the recommended
  deps list and `--bootstrap` already installs it. If you installed
  without `--bootstrap` on a non-Arch distro, run
  `paru -S zenity` or your distro equivalent.
- **Bug 3**: the popup clamp keeps it within the Settings window
  bounds. If the Settings window is very narrow (< 300px), the
  popup might overlap the swatch. Settings window minimum width is
  820px so this shouldn't hit in practice.

---

## Running tally of 4.x alpha

- v6.16.4   — Panic keybind (had 3 bugs)
- v6.16.4.1 — Panic script hotfix ← **last stable promoted to main**
- v6.16.4.2 — Widget scale + display resolution (incomplete)
- v6.16.4.3 — Widget scale actually working + oscillation killed
- v6.16.4.4 — Gaps preserved after Displays apply
- v6.16.4.5 — Start Menu pinned tile breathing room
- **v6.16.4.6** — Wallpaper cols + WiFi Connect + ColorPicker ← **this one**

Seven bug-hunting passes in 2 days. The alpha branch is earning
its stripes. v6.16.5's configreloaded IPC listener remains the
next architectural milestone.
