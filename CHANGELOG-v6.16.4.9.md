# Zen Shell v6.16.4.9 — Color picker position (actually LEFT this time)

**Release date:** 2026-04-24
**Base:** v6.16.4.8
**Severity:** LOW — cosmetic positioning

---

## Paul's report

> *"ayaw padin ma click apply pre kala ko ba nabago na ito hehe"*

Screenshot showed popup still floating to the RIGHT of the swatch,
with Apply button outside the Settings window boundary — so it
was technically visible but unreachable.

---

## Why 4.8 failed

I used `parent.width` / `parent.height` for bound checks:

```js
const pw = (parent.width  || 1920)
```

**But:** in Qt Quick Popups, `parent` can resolve to `Overlay` or
the owning window's `contentItem`, and `Overlay` is often
SCREEN-SIZED, not window-sized. So:

- Screen: 1920×1200 (full monitor)
- Settings window: 1050×750 (what Paul sees)
- `parent.width` returned 1920

My "RIGHT of swatch" check passed because `rightX + width (~1180)`
was comfortably < parent.width (1920). But visually 1180 was
WAY past the Settings window's right edge (1050) — the popup
ended up outside the window, clamped to screen but not to window.

Then Apply button clicks didn't register because event delivery
stops at the window boundary.

---

## The real fix — two-step coord dance

```js
// Step 1: compute in WINDOW coords
const win = Window.window  // the Settings window itself
const sWin = swatchRect.mapToItem(null, 0, 0)  // swatch in window coords
// ... candidate logic uses win.width/height for bound checks

// Step 2: translate back to PARENT-LOCAL coords for Popup.x/y
const local = parent.mapFromItem(null, winX, winY)
x = local.x
y = local.y
```

Why two steps:
- Positioning decisions (LEFT/RIGHT/BELOW/ABOVE) need window-scope
  bounds to be correct.
- `Popup.x/y` are in the popup's parent coord system — NOT window,
  NOT Overlay. Setting them requires coord translation back to
  parent-local.

Previously I was mixing: computed in parent coords, bound-checked
against parent.width (which was screen-sized), set in parent
coords. The bound check was against wrong reference frame → popup
positioned outside window visibility area.

---

## Files changed from 4.8

```
UPDATED
  zen-shell-v5/ColorSwatch.qml  ← window-scoped bound check +
                                   proper coord translation
  zen-shell-v5/ZenVersion.qml   ← bump to v6.16.4.9
  install.sh                     ← banner
NEW
  CHANGELOG-v6.16.4.9.md         ← this file
```

All v6.16.4.8 features carry byte-identical (including WiFi
connect log + Super+T + Dark Mode toggle).

---

## Install + verify

```bash
tar -xzf zen-shell-v6.16.4.9.tar.gz
cd zen-shell-v6.16.4.9
./install.sh
~/.local/bin/zs-restart.sh
```

### Test

1. Settings → General → Theme Palette
2. Click "Background (bg0)" swatch
3. Popup should appear **INSIDE the Settings window**, to the
   LEFT of the swatch (or RIGHT if no room on left, or BELOW/ABOVE
   as further fallbacks)
4. Apply button must be clickable — whole popup inside window
   boundary
5. Click Apply → closes, color applied

If popup still ends up outside the window, check:
```bash
qmllint ~/.config/quickshell/zen-shell/ColorSwatch.qml
# Should complete without errors
```

And confirm `import QtQuick.Window` is at the top — that's the
new import 4.9 requires.

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
v6.16.4.8 — WiFi log + ColorPicker LEFT (wrong bounds)
v6.16.4.9 — ColorPicker (actually LEFT, window bounds) ← YOU'RE HERE
```

Third attempt on the color picker positioning. If this one STILL
ends up outside the window, yung whole approach needs rethinking
(e.g. render popup inside the RowLayout as a sibling Rectangle
instead of using Qt Popup).
