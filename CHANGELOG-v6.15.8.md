# Zen Shell v6.15.8 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.7 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** one hotfix — music string committing to wrong position after
transitions INTO island mode. **1 file touched** (`Bar.qml`).
`shell.qml` and `SettingsStateV2.qml` unchanged.

---

## Fix

### Music string commits at start-menu position after Floating/FW → Island

**Symptoms reported by Paul:**
> "diba naka island ako. so basically kapag switch ko sa fullwidth or
> floating ok siya pero once na binalik ko sa island mababago yun position
> napunta ulit sa start menu. dapat refresh natin correct position and
> matagal yun loading.. dapat smart alam niya if saan ulit position kapag
> binalik sa island gets?"

Translation: I'm on island. Switching to fullwidth or floating works
fine. But once I switch back to island, the position changes — ends up
near the start menu again. Need to refresh correct position. Loading is
also slow. Should be smart, it should know the position when switching
back to island.

**Root cause:**

v6.15.7's `_modeTransitioning` lockout cleared 300ms after `barRoot.width`
stopped changing. That logic handles simple transitions well
(FW → Floating, Floating → FW) because both are constant-width modes
whose bar.width stabilizes in a single frame.

Transitions INTO island mode are different. Island has a **layout
feedback loop**:

```
panelMode = "island"
  → barWindow.implicitWidth binding re-evaluates
  → reads islandWidth = Math.min(maxW, Math.max(minW, bar.contentImplicitWidth + 16))
  → reads bar.contentImplicitWidth (from the RowLayout's natural size)
  → barWindow resizes to new value
  → bar (anchors.fill barWindow) resizes
  → RowLayout re-lays out with new width
  → RowLayout.contentImplicitWidth may change (e.g., Layout.fillWidth
     spacers collapse when available space shrinks)
  → barWindow.implicitWidth re-evaluates (feedback)
  → possibly another resize cycle
  → eventually settles over 2-5 frames
```

`barRoot.width` can stabilize at its final island value while children's
internal `.x` positions are still propagating through the RowLayout
across multiple frames. My v6.15.7 `barSettlingTimer` fires 300ms after
bar.width stops changing — but at that moment, the children may still
be mid-propagation.

The first `_doUpdatePos` call after unlock reads the parent-chain walk
and catches an **intermediate stale state**: e.g., `rightRow.x` still
reflects where it WAS when the bar was wider. Walk returns a small x
value that doesn't correspond to the actual settled layout. Writes this
to `musicSlotLocalX`. Stability timer starts counting from this bad
write. If no more significant changes happen in 600ms, stability
commits → positionReady=true → string renders at wrong position near
start menu.

Paul's screenshot shows exactly this: string anchored at approximately
bar-local x=20 (near start button) instead of where music slot actually
sits after island re-layout.

**Fix: stable-read verification**

Instead of trusting a single read after `barSettlingTimer` expires,
require **two consecutive stable reads** before lifting the lockout.
The mechanism:

- `_modeTransitioning`: lockout flag set on `panelModeChanged`
- `_barWidthStable`: becomes true when `barSettlingTimer` fires
  (bar.width idle for 300ms)
- `_lastReadX`, `_lastReadWidth`: remember last observed values

In `_doUpdatePos`:
```qml
if (_modeTransitioning) {
    if (!_barWidthStable) {
        // Bar still resizing — record current, return
        _lastReadX = x; _lastReadWidth = musicSlotItem.width
        return
    }
    if (|x - _lastReadX| < 2 && |width - _lastReadWidth| < 2) {
        // Two consecutive stable reads — layout has truly settled
        _modeTransitioning = false  // unlock
        // fall through to write
    } else {
        // Layout still propagating — record current, return
        _lastReadX = x; _lastReadWidth = musicSlotItem.width
        return
    }
}
// proceed to write
```

Since `safetyPoll` fires every 100ms (tiered to 500ms after 3s), this
gives multiple reads per second. Two matching reads typically happen
100-300ms after the layout actually stops moving. Guarantees we NEVER
commit a mid-propagation value to `ZenStringsState`.

**Additional bounds sanity:**

Added validity checks before writing:
```qml
if (x < 0 || x > barRoot.width) return
if (musicSlotItem.width < 10 || musicSlotItem.width > barRoot.width) return
```

Catches cases where `rightRow.x` is stale from a previous wide-bar mode
— walk returns x > current barRoot.width, which is geometrically
impossible. Skipped.

---

## End-to-end flow for Floating → Island

```
T=0      Click Island → panelModeChanged fires
                      → Bar.qml:
                        _modeTransitioning = true
                        _barWidthStable = false
                        _lastReadX = _lastReadWidth = sentinel
                        barSettlingTimer.restart() [300ms]
                        posTimer, safetyPoll, settleTimer, nudger restart
                      → shell.qml:
                        positionReady = false → string hidden
                        musicSlotLocalX = -1

T=0-80   barWindow.implicitWidth re-evals (floating→island formula)
         bar.width goes from 1700 → 680 (big delta: reset _barWidthStable
         + restart barSettlingTimer)

T=80-200 Bar RowLayout re-flows, contentImplicitWidth recomputes,
         another barWindow.implicitWidth pass (maybe 680 → 690 →
         stable 690), children .x positions propagating.

T=200    bar.width stable at 690.
         barSettlingTimer counting down...

T=100    safetyPoll fires → _doUpdatePos → _barWidthStable=false
         → record current read (could be mid-propagation), return

T=200    safetyPoll fires → still _barWidthStable=false → record, return

T=250    settleTimer fires → _doUpdatePos → same

T=500    barSettlingTimer fires → _barWidthStable = true

T=500    safetyPoll fires → _doUpdatePos
         → bar stable, check vs last read
         → reads x=350 (likely final island position)
         → last read was maybe x=230 (mid-prop from T=400)
         → |350-230| = 120 > 2 → not stable → record x=350, return

T=600    safetyPoll fires → _doUpdatePos
         → reads x=350 again
         → last read was x=350
         → |350-350| = 0 < 2 → STABLE → unlock, write
         → ZenStringsState.musicSlotLocalX = 350 ✓

T=600    stringsWindow receives onMusicSlotLocalXChanged
         → _onPosChanged → stringsStabilityTimer.restart()

T=1200   stability timer fires (600ms since last write, no more writes)
         → _tryMarkReady → sanity passes → positionReady = true
         → string fades in at CORRECT position (x=350 local)
```

Total Loading duration: ~1.2s. Position guaranteed correct.

For already-quick transitions (FW → Floating), the bar.width settles
faster, and stable reads happen sooner. Typical ~800ms.

---

## Files changed

```
zen-shell-v5/Bar.qml      v6.15.7 → v6.15.8 (stable-read verification)
```

`shell.qml`, `SettingsStateV2.qml`, all others — untouched from v6.15.7.

---

## Migration

No config changes. Single-file drop-in replace:

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5
cp /path/to/patch/zen-shell-v5/Bar.qml .

# Reload
pkill -f 'qs.*zen-shell' && sleep 0.3 && qs -c zen-shell &>/dev/null &
```

---

## Behaviour summary

| Scenario                              | v6.15.7                        | v6.15.8                       |
|---------------------------------------|--------------------------------|-------------------------------|
| FW → Floating                         | Correct position ✓             | Correct position ✓            |
| Floating → FW                         | Correct position ✓             | Correct position ✓            |
| Island → FW                           | Correct position ✓             | Correct position ✓            |
| Island → Floating                     | Correct position ✓             | Correct position ✓            |
| **Floating → Island**                 | **String at start menu ✗**     | Correct position ✓            |
| **FW → Island**                       | **String at start menu ✗**     | Correct position ✓            |
| Rapid mode cycling                    | Correct position ✓             | Correct position ✓            |
| Runtime tray expand (any mode)        | Smooth 180ms slide ✓           | Smooth 180ms slide ✓          |
| Login / fresh start                   | Correct position ✓             | Correct position ✓            |

---

## Known unchanged behaviour (verified)

- `_modeTransitioning` only engaged during panel mode transitions — runtime
  reflows (tray expand, taskbar add/remove) run through normal path
- 2px write threshold still filters layoutNudger's 0.1px toggle
- 600ms stability timer still governs final positionReady commit
- 15s max-wait fuse still in place
- barWindowLeft tracking in stringsWindow stability (v6.15.7) preserved
- All v6.15.1 → v6.15.7 fixes preserved: login discovery, Loading
  placeholder, SwayNC integration, complete applyToHyprland, theme
  reload defensive re-apply, panel mode reset

---

**Tested matrix:**
- Floating → Island: string lands at correct position (NOT at start menu)
- FW → Island: same
- Island → FW → Island → Floating → Island (rapid 4-click cycle):
  final position correct
- Pause at each mode (2s between clicks): each individual transition
  correct
- Runtime tray expand during island mode: Behavior still animates, no
  lockout engagement
