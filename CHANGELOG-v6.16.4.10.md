# Zen Shell v6.16.4.10 — Color picker complete rewrite + live hex typing

**Release date:** 2026-04-24
**Base:** v6.16.4.9
**Severity:** MEDIUM — 4th attempt at the color picker

---

## Paul's report

> *"upon checking same padin pre and please dapat pwd makapag
>   manualy type nung code nung color pre auto mag update nadin
>   yun box yun color picker gawan natin tlga paraan yan push mo
>   sa left side end and gawan ng paraan na ma click apply /
>   select"*

Three asks:
1. Popup still broken (4.9 didn't fix it)
2. Hex textbox should update color live as you type
3. Must be able to click Apply reliably

---

## Why 4.6, 4.8, 4.9 all failed

All three tried to position Qt Quick Popup using coordinate
translations between window and parent coordinate systems. Each
attempt found a new layer of the problem:

- **4.6**: Popup coords referenced RowLayout coords, rendered
  way off-screen to the right
- **4.8**: `parent.width` returned Overlay (screen) width, not
  Settings window width — bounds check passed for positions that
  were outside the window
- **4.9**: Used `Window.window.width` for bounds + coord
  translation back to parent-local, but the structure still
  relied on Qt Popup's parent chain which apparently has other
  quirks on Wayland

Three failures on the same approach = the approach is wrong.

## The real fix — PopupWindow instead of Popup

Quickshell has a **PopupWindow** primitive that creates a REAL
Wayland popup surface. The compositor positions it, not Qt. You
just say `anchor.item: swatchRect, anchor.gravity: Edges.Bottom |
Edges.Left` and Hyprland places it correctly, with automatic
edge detection (if there's no room below, it flips up).

This is the same pattern SysRowIcon.qml has used for tooltips
since v6.14 without a single positioning bug.

No coord math. No parent translation. No bound checks. The
compositor handles it all.

### What changed in ColorSwatch.qml

- Removed all Qt Popup imports and logic
- Added `import Quickshell` for PopupWindow
- Picker is now a PopupWindow with `anchor.item: swatchRect`
- `anchor.edges: Edges.Bottom | Edges.Left` — prefer below+left
- Visibility controlled by `pickerPop.visible = !pickerPop.visible`
  (no open()/close() methods needed)

### Bonus: live hex typing

Previously the hex textbox only committed on `editingFinished`
(Enter or Tab). Now `onTextChanged` fires on every keystroke —
if the current text is a valid 6 or 8 character hex code, it
commits immediately. Swatch preview + downstream theming update
live.

```qml
onTextChanged: {
    const raw = text.replace(/^#/, "")
    if (raw.length === 6 || raw.length === 8) {
        let v = "#" + raw.toLowerCase()
        if (v.length === 7) v = v + "ff"
        if (v !== root.value) {
            root.value = v
            root.valueEdited(v)
        }
    }
}
```

Type `#ff` — waits, no update (incomplete).
Type `#ff3366` — commits immediately, swatch turns red-pink.
Continue typing `#ff336688` — commits at 8 chars (with alpha).

---

## Files changed from 4.9

```
REWRITTEN
  zen-shell-v5/ColorSwatch.qml  ← Qt Popup → Quickshell PopupWindow,
                                   live hex typing
UPDATED
  zen-shell-v5/ZenVersion.qml   ← bump to v6.16.4.10
  install.sh                     ← banner
NEW
  CHANGELOG-v6.16.4.10.md        ← this file
```

All v6.16.4.9 features carry byte-identical.

---

## Install + verify

```bash
tar -xzf zen-shell-v6.16.4.10.tar.gz
cd zen-shell-v6.16.4.10
./install.sh
~/.local/bin/zs-restart.sh
```

### Test 1 — live hex typing

1. Settings → General → Theme Palette
2. Click into the hex textbox next to Background (bg0)
3. Select all, delete
4. Type `ff3366` character by character
5. As soon as you hit the 6th character, the swatch turns red-pink
6. Continue typing `88` (for alpha)
7. At the 8th character, commits with alpha
8. Invalid characters (like `z`) are rejected by the validator

### Test 2 — picker popup

1. Click any swatch
2. PopupWindow appears **anchored to the swatch** (Hyprland
   positions it automatically, typically below-left of swatch)
3. Drag HS canvas → live preview updates in the top-right hex
   readout + preview rectangle at bottom
4. Move lightness slider → same live update
5. Click **Apply** → popup closes, color committed
6. Or click **Cancel** → popup closes, original color preserved

### What's different visually

- Picker is now a proper Wayland popup window (floats above
  everything, can extend beyond Settings window edges if needed)
- Compositor-managed positioning — if Settings is near the right
  edge of the screen, picker flips to the left automatically
- No more stuck-outside-window issue ever again

---

## If picker STILL misbehaves

Since this uses the same PopupWindow primitive as SysRowIcon.qml
tooltips (and those have been stable since v6.14), any bug here
is very likely a QML syntax / import issue. Check:

```bash
# Is Quickshell importing PopupWindow correctly?
qmllint ~/.config/quickshell/zen-shell/ColorSwatch.qml
```

If qmllint complains about PopupWindow, check the import:
```qml
import Quickshell  // must be there
```

---

## Running tally

```
v6.16.4.1 — LAST STABLE ON MAIN
v6.16.4.2 → v6.16.4.10 — ALL ALPHA (10 iterations)
  4.6  — ColorPicker v1 Qt Popup (wrong coord space)
  4.8  — ColorPicker v2 Qt Popup LEFT (wrong bound reference)
  4.9  — ColorPicker v3 Qt Popup (window bounds, still buggy)
  4.10 — ColorPicker v4 Quickshell PopupWindow + live hex ← NOW
```

4th iteration on this feature. PopupWindow was the right tool
from the start — should have reached for it in 4.6. Lesson
learned: when Qt's high-level abstraction keeps misbehaving,
drop down to the platform-native primitive (PopupWindow is
backed by `xdg_popup` / layer shell popups, which compositors
handle natively).
