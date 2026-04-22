# Zen Shell v6.15.5 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.4 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** single-file enhancement — music string now SLIDES smoothly
into new positions when the bar reflows at runtime, instead of
snap-after-delay. No fixes, just polish. 1 file changed. Walang
binawas.

---

## Enhancement

### Smooth runtime transitions on margin/width changes

**What Paul reported:**
> "kapag expand ko kunwari yung tray ko medyo na dedelay lang din yun
> adjustment ni string ko"

Translation: when the tray expands, there's a small delay before the
string adjusts to its new position.

**Why the delay exists:**
The delay is physically unavoidable given the architecture. When the
user clicks the tray chevron to expand:

```
T=0        sysrow (or tray) width increases
T=0        rightRow.widthChanged fires
T=0        Bar.qml's Connections → posTimer.restart() (16ms debounce)
T=16ms     posTimer triggers → updatePos() → Qt.callLater(_doUpdatePos)
T=16-18ms  _doUpdatePos runs → parent-chain walk → write to ZenStringsState
T=18ms     ZenStringsState.musicSlotLocalXChanged fires
T=18ms     stringsWindow.margins.left binding re-evaluates
T=18ms     Wayland: margin update sent to compositor
T=~35ms    Compositor: repositions layer surface, commits frame
T=~50ms    User sees new position
```

Total perceived delay: ~40-60ms under normal load, up to 100-200ms
on a busy compositor. Previously this appeared as a visible "snap
to new position after a brief hitch."

**The three options considered:**

1. **Reduce posTimer debounce to 0ms** — would save 16ms but risks
   firing mid-layout reads (the whole reason v6.15.2 added the
   16ms debounce). Not worth the regression risk.
2. **Show Loading placeholder during every reflow** — too
   distracting. Tray expands / taskbar changes happen frequently;
   flashing Loading constantly would be worse than the current
   hitch.
3. **Animate the margin change over 180ms** ← chosen. The physical
   delay still exists, but the animation glides the string into
   place over ~11 frames, so the user sees smooth motion instead
   of a snap.

**Fix (shell.qml — `stringsWindow`):**

Added `Behavior` animation on the two runtime-variable geometry
properties:

```qml
margins.left: barLeftOffset + ZenStringsState.musicSlotLocalX

Behavior on margins.left {
    enabled: stringsWindow.positionReady
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
}

implicitWidth: ZenStringsState.musicSlotLocalWidth

Behavior on implicitWidth {
    enabled: stringsWindow.positionReady
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
}
```

**Design details:**

- **`enabled: stringsWindow.positionReady`** — critical. The initial
  placement (on login, going from default `-1` to the real position
  after stability fires) should NOT animate. Without this guard,
  users would see the string sweep across the whole screen on
  login. Animation only applies to runtime updates after
  `positionReady` is true.

- **180ms duration** — tuned by feel:
  - 100ms: still feels jumpy
  - 150ms: good
  - 180ms: sweet spot, smooth without feeling sluggish
  - 200ms+: starts to feel laggy

- **OutCubic easing** — starts fast, eases out. Feels like the
  string is "catching up" to the new position. Alternative
  InOutQuad was symmetric but felt less responsive.

- **Wayland cost analysis** — a 180ms animation at 60fps = ~11
  margin-update round-trips with the compositor. Earlier versions
  worried about flooding this path on rapid-fire signals (clock
  ticks, sysrow state changes). But Bar.qml's 2px write threshold
  (v6.15.3) already filters out sub-pixel jitter — only genuine
  layout deltas of 20px+ (tray expand, app open, workspace switch)
  trigger a write, which then triggers one animation. So in steady
  state Wayland traffic stays zero; animation traffic is bounded
  to discrete user-visible events.

- **Interrupt handling** — QML's NumberAnimation on Behavior
  handles mid-animation retargeting natively. If the user
  expand-collapses-expands the tray rapidly, each event just
  retargets the running animation from current interpolated
  value to new destination. No queueing, no jumps.

---

## Files changed

```
zen-shell-v5/shell.qml  v6.15.4 → v6.15.5 (two Behavior blocks added)
```

`Bar.qml`, `MusicStrings.qml`, `ZenStringsState.qml` all unchanged
from v6.15.4. The producer-side position-tracking logic was already
correct after v6.15.4 — this release only polishes the consumer-side
visual response.

---

## Migration

No config migration, no schema changes, no new dependencies.

**Apply by drop-in replace (from v6.15.4):**

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5
cp /path/to/patch/zen-shell-v5/shell.qml .

# Reload
pkill -f 'qs.*zen-shell' && sleep 0.3 && qs -c zen-shell &>/dev/null &
```

---

## Behaviour summary

| Event                        | Before v6.15.5                   | After v6.15.5                   |
|------------------------------|----------------------------------|---------------------------------|
| Login, first placement       | Snap to correct position         | Snap to correct position ✓      |
| Tray expand / collapse       | Snap after 40-60ms delay         | Smooth 180ms slide ✓            |
| Taskbar app opens / closes   | Snap after ~40ms delay           | Smooth 180ms slide ✓            |
| Workspace switch reflow      | Snap after ~40ms delay           | Smooth 180ms slide ✓            |
| Clock tick (sub-2px jitter)  | No change (filtered at 2px)      | No change (filtered at 2px)     |
| stringLength resized         | Width snaps                      | Width smoothly animates         |
| Rapid tray click spam        | Snap-snap-snap (ugly)            | Smooth retargeting ✓            |

---

## Known unchanged behaviour (verified)

- Loading placeholder on login — unchanged (still shows before
  `positionReady` fires, fades at 350ms OutCubic).
- ZenStrings opacity fade-in — unchanged (still 400ms OutCubic).
- Tooltip anchoring — unchanged (v6.15.4 barTopAnchor fix intact).
- Cava beat reactivity, glow, color modes, screenshot rope — all
  untouched.
- Panel modes (fullwidth/floating/island) — unchanged.
- Multi-monitor — per-screen Behaviors animate independently.
- Bar.qml position tracking (layoutNudger, safetyPoll, parent-chain
  walk, 2px threshold, sanity gate) — all intact from v6.15.4.

---

**Tested matrix:**
- Tray expand: string slides smoothly into new position, no hitch.
- Rapid expand/collapse: string retargets mid-animation, no
  stutter.
- Login: placement still snap (no pre-stability animation).
- Multi-monitor: each monitor's string animates independently.
- Clock jitter: no spurious animations (2px filter holds).
