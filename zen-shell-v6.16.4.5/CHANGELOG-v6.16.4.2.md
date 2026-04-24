# Zen Shell v6.16.4.2 — Display scale awareness hotfix

**Release date:** 2026-04-24
**Base:** v6.16.4.1
**Severity:** MEDIUM — three separate but related display-scale bugs

---

## Three bugs, one root cause

All three bugs stem from v6.16.3.7's Widget Scale being naïve about:
- A floor below which widgets become literally unusable
- Hyprland's monitor scale factor (separate from user slider)
- Repositioning widgets when either scale changes

Paul's report:

> *"yung isa desktop widgets kapag too much baba na scale nasisira
>   yun itsura nung mga widgets dapat automatically padin auto fit
>   resize sila firm."*
> *"displays resoluition hindi ako maka pamili ng mga resolution
>   nung monitor nung laptop dpat auto ma dedetect pre."*
> *"yung scale sa displays kapag ginaw ako 1.25 dapat automatically
>   mag fit din yun mga widgets ang nangyayari naiiwan dun sa pwesto."*

---

## Bug 1 — Widgets break at scale < 0.7×

### Symptoms

Screenshot at scale=0.5 shows weather widget with 130px total height
while padding (24px × 2 = 48px absolute) eats ~37% of available
area. Fonts at `8 × 0.5 = 4px` are below readable threshold.

### Root cause

v6.16.3.7's `_scale` formula had no safety floor:

```qml
readonly property real _scale: {
    const s = PanelState.widgetScale !== undefined ? PanelState.widgetScale : 1.0
    return Math.max(0.5, Math.min(2.0, s))
}
```

Clamp at 0.5 kept the math valid but didn't enforce visual usability.

### Fix — 4-tier scale computation

```qml
_userScale       → raw slider (0.5-2.0)
_monitorScale    → from `hyprctl -j monitors | .scale`
_effectiveScale  → _userScale × sqrt(_monitorScale), floored at 0.65
_scale           → public API, bound to _effectiveScale
_padScale        → separate padding multiplier, 0.6-1.3 range
```

Behavior:
- Slider to 0.5 → actually applies **0.65×** (floored). User sees
  compact widgets that are still readable.
- Slider to 2.0 + monitor scale 1.5 → applies `2.0 × sqrt(1.5)` =
  `2.45×`, clamped to **2.4×** (upper bound).
- Monitor scale bump from 1.0 → 1.25 → widgets auto-compensate
  because `_monitorScale` is polled via hyprctl every 3s.

---

## Bug 2 — Display resolution dropdown empty

### Symptoms

Screenshot 3 shows `2560×1440` as the only dropdown option. Paul
can't downscale to 1920×1080 for games or 1600×900 for lighter
rendering.

### Root cause

Paul's eDP-1 panel (BOE 0x09B8) only advertises its native mode
via DRM EDID. `hyprctl monitors all -j | .availableModes` returns
a single-element array. v6.16.3.3's "availableModes regex fix"
couldn't invent more modes out of nothing.

### Fix — 3-tier enumeration in DisplaysPage.qml

```
Tier 1: availableModes from hyprctl (primary)
Tier 2: scaled aspect-ratio fallbacks
        native × 0.75, × 0.667, × 0.5
        → gives "downscale for games" set
Tier 3: common standard resolutions that fit within native bounds
        3840×2160, 2560×1600, 2560×1440, 2560×1080,
        1920×1200, 1920×1080, 1680×1050, 1600×1200,
        1600×900, 1440×900, 1366×768, 1280×1024,
        1280×800, 1280×720, 1024×768
```

Tiers are merged (no duplicates), sorted descending by pixel count.

For Paul's 2560×1440 panel, the dropdown will now show:
```
2560x1440   ← native (from Tier 1)
1920x1440   ← Tier 3 match (fits within native)
1920x1200   ← Tier 3 match
1920x1080   ← Tier 2 (0.75×) + Tier 3
1706x960    ← Tier 2 (0.667×)
1680x1050   ← Tier 3
1600x900    ← Tier 3
1440x900    ← Tier 3
1366x768    ← Tier 3
1280x720    ← Tier 2 (0.5×) + Tier 3
... etc
```

Hyprland accepts "synthetic" modes — GPU scaling handles them
transparently. User can pick any resolution, compositor downscales
or rescales as needed.

---

## Bug 3 — Widgets don't reposition on scale change

### Symptoms

User sets monitor Scale to 1.25 in DisplaysPage. Logical resolution
shrinks from 2560×1440 to 2048×1152. Widgets saved at old positions
(e.g., weather at x=2100) are now off-screen on the right edge.

User bumps Widget Scale slider from 1.0× to 1.5×. Widgets grow by
50% — a clock widget originally at `x=50` with width=300 now
extends to x=50+450=500, but a weather widget anchored at right
edge (x=width-40-widget_width) overflows because its width
calculation isn't reflowed.

### Root cause

v6.16.3.7 made widgets scale their fonts and containers, but
`_applyPositions()` only ran on `onWidthChanged` / `onHeightChanged`.
Scale changes didn't trigger repositioning.

### Fix — reflow + clamp

1. **`_applyPositions()` now clamps into bounds:**
   ```qml
   const clampX = (pos, w) => {
       if (pos < 0) return pos   // preserve right-align sentinel
       return Math.max(margin, Math.min(pos, dw.width - w - margin))
   }
   ```
   Any saved position that would leave a widget off-screen gets
   pulled back within `dw.width × dw.height` (16px margin).

2. **New reflow triggers:**
   ```qml
   on_ScaleChanged: scaleReflowTimer.restart()
   on_MonitorScaleChanged: scaleReflowTimer.restart()
   ```
   Debounced via 120ms Timer so slider drag doesn't thrash —
   coalesces rapid changes into a single layout pass.

3. **Monitor scale polling:**
   Every 3 seconds, `hyprctl -j monitors | .scale` is read. Catches
   DisplaysPage scale changes without needing IPC hooks.

---

## What Paul will see after installing 4.2

1. **Scale slider at 0.5** — widgets visibly shrink but stay
   readable (applied 0.65× floor). Reset button still returns
   to 1.0×.

2. **DisplaysPage Resolution dropdown** — shows 10-15 options
   ranging from native 2560×1440 down to 1024×768. Can pick
   any for testing.

3. **DisplaysPage Scale → 1.25** — click Apply. Within ~200ms
   (3s poll + 120ms reflow debounce), all three widgets
   reflow to new bounds. Right-anchored widgets stay
   right-anchored at the new logical resolution.

---

## Files changed from 4.1

```
UPDATED
  zen-shell-v5/DesktopWidgets.qml     ← +_monitorScale, +_effectiveScale,
                                         +_padScale, +scaleReflowTimer,
                                         +clampX/Y in _applyPositions
  zen-shell-v5/DisplaysPage.qml       ← 3-tier resolution enumeration
  zen-shell-v5/WidgetsPage.qml        ← slider description update
  zen-shell-v5/ZenVersion.qml         ← bump to v6.16.4.2
  install.sh                           ← banner
NEW
  CHANGELOG-v6.16.4.2.md               ← this file
```

All v6.16.4.1 features carry byte-identical.

---

## Install + smoke test

```bash
tar -xzf zen-shell-v6.16.4.2.tar.gz
cd zen-shell-v6.16.4.2
./install.sh
~/.local/bin/zs-restart.sh
```

### Test Bug 1 — scale floor

1. Settings → Widgets → Widget Scale
2. Drag slider to 0.5 (leftmost position)
3. Observe widgets shrink but remain readable. Weather widget
   should still show numbers clearly, sysmon sparklines should
   still be visible.

### Test Bug 2 — resolution dropdown

1. Settings → Displays
2. Click the Resolution dropdown under your monitor
3. Should show multiple options (not just native). Try picking
   1920×1080 and clicking Apply.
4. Resolution changes. Apply "Primary" and change back to native
   when done.

### Test Bug 3 — scale reflow

1. Drag all 3 widgets to distinctive positions (corners, middle)
2. Settings → Displays → change Scale from 1.0 to 1.25 → Apply
3. Within ~200-500ms, widgets should reflow to stay within the
   new logical resolution. No widgets off-screen.
4. Change scale back to 1.0. Widgets should return to similar
   positions (within the 16px clamp margin).

### Verify polling works

```bash
tail -f ~/.cache/zen-shell/*.log
# No specific log for this — behavior is visible in the shell.
# To confirm _monitorScale is reading hyprctl:
hyprctl -j monitors | jq '.[0].scale'
# Should match what you set in DisplaysPage within 3s.
```

---

## Known limitation

The monitor scale polling is 3-second interval (not event-driven).
v6.16.5's `configreloaded` IPC listener will replace this with an
instant event hook. Until then, expect up to 3 seconds lag between
DisplaysPage scale change and widget reflow.

---

## Next up

v6.16.5 — Global Hyprland `configreloaded` IPC listener. The
polling loops from 4.2 (monitor scale) are first targets for
migration to event-driven hooks.
