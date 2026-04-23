# Zen Shell v6.16.3.4.6 — ZenComboBox: bounds-aware + auto-flip upward

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.3.4.6`
**Base:** v6.16.3.4.5
**Status:** Beta — single-file patch to ZenComboBox

---

## TL;DR

> *"paki double check lahat pre katulad neto hindi ko na ma click yun
>   kasunod yan yun sinasabi ko ensure natin ma cclick lahat pre na
>   lilimit kapag super dami na"*

v6.16.3.4.5's ZenComboBox fixed the 21-item animation preset overflow
but still failed when a ComboBox sat near the bottom of the Settings
window AND had enough items to extend past the window edge (e.g. the
10-font Bar Modules → Font family picker). A fixed 280px cap is not
enough when the combobox is 180px from the window bottom — the popup
clipped past the surface, last items became unclickable.

Fixed with three changes, all inside `ZenComboBox.qml`:

1. **Dynamic bounds.** Popup measures actual space available between
   the ComboBox and the owning window's bottom edge. If only 180px
   below, the popup is 180px tall and the rest scrolls internally.
2. **Auto-flip upward.** If space below < `flipMargin` (default 140px)
   AND space above is bigger, popup opens upward instead. The
   10-item font picker near the window bottom now opens above the
   ComboBox where there's plenty of room.
3. **Persistent ScrollBar** (replaces the auto-fading ScrollIndicator).
   8px rounded bar, stays visible while content overflows, hidden
   when the list fits — users get an obvious affordance that "more
   items exist below" instead of a ghost indicator that fades after
   2 seconds.

Zero changes to the 30 ZenComboBox call sites across 9 pages — all
existing usages benefit from the new behavior automatically.

**Wala tayong binawasan.**

---

## Implementation detail

### Space measurement

```qml
readonly property var _window: root.Window.window

readonly property real _availableBelow: {
    if (!_window) return root.maxPopupHeight
    const p = root.mapToItem(null, 0, root.height)
    return Math.max(0, _window.height - p.y - 12)
}

readonly property real _availableAbove: {
    if (!_window) return 0
    const p = root.mapToItem(null, 0, 0)
    return Math.max(0, p.y - 12)
}
```

`root.Window.window` resolves to the QQC2 ApplicationWindow the
combobox is inside. `mapToItem(null, …)` returns scene (window-local)
coordinates. The 12px margin keeps the popup from kissing the window
edge.

### Flip decision

```qml
readonly property bool _flipUp:
    _availableBelow < root.flipMargin
    && _availableAbove > _availableBelow
```

Two conditions must both hold: below must be actively cramped, AND
above must have genuinely more room. Prevents flipping for comboboxes
that are in the middle of the window (where below is plenty).

### Effective height

```qml
readonly property real _effectiveMax:
    Math.min(
        root.maxPopupHeight,
        _flipUp ? _availableAbove : _availableBelow
    )

y: _flipUp ? -height : root.height
implicitHeight: Math.min(contentItem.implicitHeight, _effectiveMax)
```

The final popup height is the MINIMUM of three things:
- Full content height (if the list is short, fit naturally)
- User's `maxPopupHeight` ceiling (default 280)
- Available space on the chosen side

Whichever is smallest wins — popup never exceeds any of them.

### ScrollBar over ScrollIndicator

```qml
ScrollBar.vertical: ScrollBar {
    policy: ScrollBar.AsNeeded
    active: true
    width: 8
    contentItem: Rectangle {
        radius: 3
        color: pressed
            ? ThemeService.alpha(ThemeService.fg, 0.55)
            : ThemeService.alpha(ThemeService.fg, 0.35)
    }
}
```

`ScrollBar.AsNeeded` shows the bar only when the content overflows.
Because `active: true`, it doesn't auto-hide after an idle timeout
the way ScrollIndicator does. The 35%/55% fg-alpha colors match the
shell's existing translucent surfaces.

---

## Files in this drop

### UPDATED

```
zen-shell-v5/ZenComboBox.qml       ← bounds-aware + flip-up + ScrollBar
zen-shell-v5/ZenVersion.qml        ← bump to v6.16.3.4.6
install.sh                          ← banner bump
CHANGELOG-v6.16.3.4.6.md            ← this file (NEW)
```

### CARRIED OVER

Everything from 3.4.5 byte-identical, including:
- 30 ZenComboBox usages across 9 Settings pages (API untouched)
- PowerBadge A+B fix (install.sh migration + BarModulesPage toggle)
- Previous 3.4.x fixes

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.4.6.tar.gz
cd zen-shell-v6.16.3.4.6
./install.sh
~/.local/bin/zs-restart.sh
```

### Reproduce the original bug (to confirm the fix)

1. Settings → Bar Modules → scroll to the Font section
2. Open the "Font family" dropdown
3. **Before v6.16.3.4.6:** popup extends past Settings window bottom
   edge, `Inter` (10th font) either clipped or unclickable
4. **After v6.16.3.4.6:** popup either (a) opens upward with all 10
   fonts visible, or (b) fits in available space below with persistent
   ScrollBar showing you can reach `Inter` by scrolling

### Verify across other tight-space dropdowns

- Settings → Themes → theme picker (16+ themes)
- Settings → Widgets → timezone pickers in clock section (20+ entries)
- Settings → Battery & Power → brightness device picker (if laptop)

All should behave sensibly: popup never extends past window edge,
ScrollBar visible when content overflows, keyboard nav still works.

---

## Per-instance override

If a specific dropdown needs different behavior, pass the properties:

```qml
ZenComboBox {
    maxPopupHeight: 400     // taller popup for a huge list on a big monitor
    flipMargin: 200         // flip upward more aggressively
    model: [...]
}
```

Defaults (280 / 140) work for every current call site.
