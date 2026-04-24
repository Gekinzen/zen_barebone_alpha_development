# Zen Shell v6.16.4.3 — Widget scale follow-up hotfix

**Release date:** 2026-04-24
**Base:** v6.16.4.2
**Severity:** MEDIUM — v6.16.4.2 didn't fully fix what it claimed to

---

## Mea culpa

v6.16.4.2 said "widgets auto-fit at low scale" but I defined the
`_padScale` property and never actually used it anywhere in the
widget bodies. That's on me. Also introduced a widget "oscillation"
bug via the 3s polling Timer. Paul's report:

> *"paki ayos din ito widgets lalo sa weather ko kapag too much
>   liit na 0.50x dapat mag auto fit yan pre"*
> *"napansin ko kapag pinalitan ko ng scale yun widgets kapag exit
>   ko yun control panel bigla nag babago bago yun scaling."*

v6.16.4.3 is the actual fix.

---

## Bug 1 — Weather widget still breaks at 0.5× (4.2 was incomplete)

### What 4.2 did and didn't do

4.2 added the `_padScale` property with clear intent ("scales the
absolute padding values inside widgets down with the scale
factor"), then proceeded to not apply it to any of the 9
`anchors.margins` lines in `DesktopWidgets.qml`. They stayed
hardcoded to `16`, `14`, `10` pixels.

Result: at 0.5× slider, container shrinks to 200×130, but inner
padding stays at `16 × 2 = 32` absolute pixels. That's 16% of the
container width just for padding. The inner `Layout.preferredHeight:
90` row stays 90 absolute pixels — taller than the entire widget.

### 4.3 fix — actually apply `_padScale` + content-aware sizing

**Applied `_padScale` to every margin/spacing/Layout preferred size:**
```qml
anchors.margins: 16 * dw._padScale   // was: 16
spacing: 8 * dw._padScale             // was: 8
Layout.preferredHeight: 90 * dw._scale // was: 90
height: 72 * dw._scale                 // forecast row
```

Total: 9 margins + 6 spacings + 4 heights now scale with the
user's Widget Scale slider.

**Content-aware container sizing:**
```qml
readonly property real _targetW: 400 * dw._scale
readonly property real _targetH: 260 * dw._scale
width: Math.max(_targetW, weatherContent.implicitWidth + padding)
height: Math.max(_targetH, weatherContent.implicitHeight + padding)
```

Widget takes max of "what the scale says it should be" and "what
the content actually needs to fit." At 0.5× the content wins and
the widget stays readable. At 2.0× the target wins and the widget
grows with visual breathing room.

Same treatment applied to sysmon widget with its 2×2 stats grid.

---

## Bug 2 — Widget oscillation after closing Control Panel

### Root cause

v6.16.4.2 added a 3-second Timer that polled `hyprctl -j monitors`
continuously:

```qml
Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: monitorScaleProbe.running = true
}
```

Two problems:
1. **Float noise triggers reflow**: `hyprctl` returns the scale as
   a JSON number. `1.25` gets parsed to something like `1.249999`
   on one read and `1.250000` on the next. `_monitorScale` changes,
   `_scale` changes, `scaleReflowTimer` fires, widgets reposition.
2. **Control Panel close cascades**: closing the Control Panel
   changes Hyprland's reserved screen area (layer shell margins).
   `dw.width`/`dw.height` briefly fluctuate during the fade-out
   animation. Previously called `_applyPositions()` on every tick
   of that animation — widgets visibly jittered.

### 4.3 fix — dampen the cascade

**Removed the 3-second polling Timer entirely.** Monitor scale is
probed:
- Once on load (startup)
- On `PanelState.widgetScale` change (slider movement)
- Round to 2 decimals before comparing (kills float noise)
- Threshold ≥ 0.005 to trigger a change (below that = noise)

**Debounced container-size reflow:**
```qml
onWidthChanged: containerReflowTimer.restart()
onHeightChanged: containerReflowTimer.restart()

Timer {
    id: containerReflowTimer
    interval: 150
    repeat: false
    onTriggered: _applyPositions()
}
```

Control Panel close now results in ONE `_applyPositions()` call
after the 150ms debounce elapses — no more cascade during the
fade-out animation.

**Scale change Timer bumped 120ms → 180ms** for extra coalescing.

---

## Files changed from 4.2

```
UPDATED
  zen-shell-v5/DesktopWidgets.qml   ← 9 margin + 6 spacing + 4 height scalings;
                                       weather + sysmon content-aware sizing;
                                       removed 3s poll Timer;
                                       debounced container reflow;
                                       float-noise threshold
  zen-shell-v5/ZenVersion.qml        ← bump to v6.16.4.3
  install.sh                          ← banner
NEW
  CHANGELOG-v6.16.4.3.md              ← this file
```

All v6.16.4.2 features carry byte-identical.

---

## Install + smoke test

```bash
tar -xzf zen-shell-v6.16.4.3.tar.gz
cd zen-shell-v6.16.4.3
./install.sh
~/.local/bin/zs-restart.sh
```

### Test 1 — Low scale readability

1. Settings → Widgets → Widget Scale → drag to 0.5
2. Observe weather widget — should still show clearly:
   - Emoji + "35°C" readable
   - Location name visible underneath
   - 7-day forecast row not clipped
   - No overlapping text
3. Slide to 0.65, 0.8, 1.0, 1.5, 2.0 — widget should smoothly grow
   without content breakage at any scale.

### Test 2 — No oscillation after Control Panel

1. Drag widgets to distinctive positions
2. Open Control Panel (Super+C)
3. Close Control Panel (click outside or X)
4. Watch widgets — should NOT jitter, bounce, resize, or reposition
5. Open/close Control Panel 5 times rapidly — widgets stay rock-steady

### Test 3 — Monitor scale change (still works from 4.2)

1. Settings → Displays → Scale 1.0 → 1.25 → Apply
2. Widgets reflow within ~200ms to stay within new logical bounds
3. No continuous drift after that — single reflow pass only

---

## Why this kept requiring hotfixes

Honest answer: the widget scale feature started in 6.16.3.7 as
"multiply font sizes by a float" and grew into "dynamic layout that
adapts to user slider + monitor DPI + Control Panel state." Each
added dimension found a new edge case. 4.3 tightens the last of
them — content-aware sizing + debounced reflow — so the system
behaves predictably regardless of combination.

v6.16.5's `configreloaded` IPC listener will replace the one
remaining polling behavior (the single-shot probe on PanelState
change) with an event-driven hook, at which point the whole scale
pipeline is fully reactive.
