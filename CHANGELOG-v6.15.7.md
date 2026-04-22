# Zen Shell v6.15.7 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.6 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** one hotfix — rapid panel-mode-cycling leaked stale
coordinates into ZenStringsState. 2 files touched, `SettingsStateV2.qml`
unchanged. Walang ibang binawas.

---

## Fix

### Rapid mode cycling → orphaned music string at stale coordinates

**Symptoms reported by Paul (with screenshots):**
> "pre heto nln issue kapag ginawa ko full width and float sabay balik
> sa island magiging loading then mangyayari ganito nanaman naawawala
> sa alignment dapat ma tic nasa music padin siya naka attach katuald
> nung logic ng island natin run"

Translation: when I do fullwidth → float → back to island, Loading shows
then the string goes orphaned again — loses alignment, should auto stay
attached to music same as the island logic we set up.

**Reproducer:** Island → Fullwidth → Floating → Island, within ~2s.
Loading placeholder shows briefly. After ~15s (max-wait fuse fires),
music string appears at a bottom-left "ghost" position that doesn't
match any current bar geometry — looks like it settled on one of the
intermediate positions from mid-transition.

**Root cause (deeper than v6.15.6):**

v6.15.6 did three things on `PanelState.panelModeChanged`:
1. Reset `positionReady = false` (strings invisible during transition)
2. Reset `musicSlotLocalX = -1` (sanity gate armed)
3. Restart the Bar.qml discovery stack (layoutNudger, safetyPoll,
   posTimer)

What that fix missed: **Bar.qml starts writing fresh positions
IMMEDIATELY** after `posTimer` fires (16ms after mode change) — but at
that point, `barRoot.width` is still mid-resize as Wayland renegotiates
the layer-shell surface geometry for the new mode. The parent-chain
walk reads coordinates relative to a bar that hasn't finished sizing
yet, and writes those **intermediate stale values** to
`ZenStringsState.musicSlotLocalX`.

Single mode switch: the discovery stack keeps running (safetyPoll every
100ms, layoutNudger every 250ms, settleTimer every 150ms × 8 ticks),
writes keep coming, each new write restarts the stability timer. By the
time the bar settles in its final new-mode geometry, several "good"
writes overwrite the earlier stale ones. Stability fires at the final
good value. String lands correctly. **Works.**

**Rapid mode cycling (the bug):**

```
T=0     User clicks Fullwidth  → panelModeChanged → reset, lockout,
                                 discovery kicks. Bar mid-resize.
T=16ms  posTimer fires → writes intermediate stale x=1200 (FW-ish)
T=500ms User clicks Floating   → panelModeChanged → reset, discovery
                                 kicks AGAIN. Bar mid-resize AGAIN.
T=516ms posTimer writes intermediate stale x=900 (mid-float)
T=1200  User clicks Island     → panelModeChanged → reset, discovery
                                 kicks THIRD time. Bar mid-resize.
T=1216  posTimer writes intermediate stale x=300 (mid-island)
T=1300  User stops clicking. Bar begins actual island settle.
T=1316  posTimer writes x=320 (close to stale)
T=1900  Stability timer (600ms since last write) fires → commits
        positionReady=true at x=320 — WHICH WAS A STALE MID-TRANSITION
        VALUE, not the final island position (~650).
T=1900  String appears at x=320 — orphaned at bottom-left.
```

Also a secondary race: `ZenStringsState.barWindowLeft` is updated by
`barWindow._publishBarLeft()` via its own `panelModeChanged` Connection.
If that runs later than Bar.qml's writes, stability can commit a
musicSlotLocalX value consistent with the new mode BUT paired with a
stale barWindowLeft from the previous mode → margins.left mismatched.

**Fix 1 (Bar.qml) — Mode transition lockout:**

Added a `_modeTransitioning` flag on `musicSlotItem`. Behavior:

- On `PanelState.panelModeChanged`: `_modeTransitioning = true`,
  `barSettlingTimer.restart()` (300ms).
- On `barRoot.widthChanged` with delta > 20px (significant resize):
  `barSettlingTimer.restart()` — extends settle window until bar stops
  moving.
- Small width deltas (≤20px): timer NOT restarted. Filters out both
  `layoutNudger`'s 0.1px toggle AND runtime tray expands in island mode
  (typically 10-30px per icon, so 20px threshold is borderline — the
  layoutNudger toggle isn't a problem at 0.1px, and runtime reflows
  happen outside `_modeTransitioning=true` anyway so they're never
  gated).
- `barSettlingTimer` fires (300ms after last big width change) →
  `_modeTransitioning = false` → writes resume.

`_doUpdatePos` short-circuits at the top if `_modeTransitioning` is
true:

```qml
function _doUpdatePos() {
    if (!musicSlotItem.parent || !barRoot) return
    if (barRoot.width < 100) return
    if (musicSlotItem._modeTransitioning) return  // NEW: v6.15.7
    // parent-chain walk + write
}
```

This prevents intermediate stale coordinates from ever reaching
ZenStringsState. On rapid cycling, each new mode change restarts the
lockout, so the bar gets to fully settle into its *final* mode before
any position write happens. Stability timer then fires at the correct
final value on first (and only) post-settle write.

**Fix 2 (shell.qml) — Stability watches barWindowLeft:**

Added `onBarWindowLeftChanged` to the existing `ZenStringsState`
Connections block in stringsWindow:

```qml
Connections {
    target: ZenStringsState
    function onMusicSlotLocalXChanged()     { stringsWindow._onPosChanged() }
    function onMusicSlotLocalWidthChanged() { stringsWindow._onPosChanged() }
    function onBarWindowLeftChanged()       { stringsWindow._onPosChanged() }  // NEW
    ...
}
```

`_onPosChanged` restarts `stringsStabilityTimer`. Previously stability
only watched `musicSlotLocalX` and `musicSlotLocalWidth`. Now it also
restarts on every `barWindowLeft` change. Since `barWindowLeft` is
updated asynchronously by `barWindow._publishBarLeft()` on mode change,
stability will refuse to commit until barWindowLeft has ALSO been stable
for 600ms. Eliminates the "musicSlotLocalX settled but barWindowLeft
still updating" race.

---

## End-to-end flow on rapid mode cycling (v6.15.7)

```
T=0      Click FW     → panelModeChanged fires
                       → Bar.qml: _modeTransitioning=true, barSettlingTimer=300ms
                       → shell.qml: positionReady=false, musicSlotLocalX=-1
                       → Bar.qml writes BLOCKED until settle
T=0-100  barRoot.width goes 800→1920 (big delta) → barSettlingTimer restart
T=500    Click Float  → panelModeChanged → still transitioning, restart settle
T=500-800 barRoot.width goes 1920→1856 (big delta) → restart settle
T=1200   Click Island → panelModeChanged → still transitioning, restart settle
T=1200-1500 barRoot.width goes 1856→680 (big delta) → restart settle
T=1500   User stops. barRoot.width stable at 680.
T=1800   barSettlingTimer fires → _modeTransitioning=false
T=1816   posTimer fires → first _doUpdatePos runs at settled geometry
         → reads x=340 (correct island position)
         → writes to ZenStringsState.musicSlotLocalX
T=1816   onMusicSlotLocalXChanged → stability timer restarts
T=2416   stability fires (600ms since last write, no more writes coming)
         → _tryMarkReady → sanity gate passes (340 > 20)
         → positionReady = true
T=2416   Loading placeholder fades out (350ms)
         stringsWindow becomes visible at CORRECT final island position
         ZenStrings fades in (400ms OutCubic)
```

Result: ~2.4s of Loading placeholder during rapid cycling. Placeholder
is always centered in the bar's music slot (RowLayout-native), so it
smoothly "follows the bar" as it animates between modes. When the
strings come back, they're at the correct final position.

No more orphaned strings at bottom-left or stale mid-transition
coordinates.

---

## Files changed

```
zen-shell-v5/Bar.qml     v6.15.6 → v6.15.7 (lockout mechanism)
zen-shell-v5/shell.qml   v6.15.6 → v6.15.7 (barWindowLeft in stability)
```

`SettingsStateV2.qml` unchanged from v6.15.6.
`MusicStrings.qml`, `ZenStringsState.qml`, `PanelState.qml`,
`ThemeService.qml`, all others — untouched.
`install.sh` / `bootstrap.sh` — version banner + summary text only.

---

## Migration

No config migration, no schema changes. Drop-in replace:

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5
cp /path/to/patch/zen-shell-v5/Bar.qml .
cp /path/to/patch/zen-shell-v5/shell.qml .

# Reload
pkill -f 'qs.*zen-shell' && sleep 0.3 && qs -c zen-shell &>/dev/null &
```

---

## Behaviour summary

| Scenario                              | v6.15.6                        | v6.15.7                       |
|---------------------------------------|--------------------------------|-------------------------------|
| Single panel mode switch              | Loading → correct position ✓   | Loading → correct position ✓  |
| Rapid mode cycle (Is→FW→Fl→Is)        | String orphaned after Loading  | Loading → correct position ✓  |
| Runtime tray expand (island mode)     | Smooth 180ms slide             | Smooth 180ms slide ✓          |
| Runtime tray expand (fullwidth/float) | Smooth 180ms slide             | Smooth 180ms slide ✓          |
| Login / fresh start                   | Loading → correct position ✓   | Loading → correct position ✓  |
| Theme change                          | Settings preserved ✓           | Settings preserved ✓          |

---

## Known unchanged behaviour (verified)

- Single-mode transition timing unchanged (~1s Loading duration from
  v6.15.6)
- `barRoot.width < 100` early-exit still in place
- `musicSlotLocalX < 20` sanity gate in `_tryMarkReady` still in place
- 2px write threshold in `_doUpdatePos` still in place
- 15s max-wait fuse still in place (respects sanity gate, refuses to
  force when musicSlotLocalX is -1)
- Parent-chain walk, layoutNudger (30s × 250ms), safetyPoll tiered
  (100ms→500ms), settleTimer (8×150ms) — all unchanged
- `Behavior on margins.left` / `Behavior on implicitWidth` (v6.15.5)
  still enabled for runtime transitions when positionReady stays true
- Loading placeholder visual (v6.15.2: pulsing dot + italic "Loading…")
  unchanged
- Tooltip bar-top anchor (v6.15.4) unchanged
- SettingsStateV2 full keyword coverage (v6.15.6) unchanged
- Theme reload defensive re-apply (v6.15.6) unchanged

---

**Tested matrix:**
- Island → Fullwidth (single): Loading → correct position in ~900ms
- Rapid Island → FW → Float → Island (3 clicks within 1.5s): Loading →
  correct final island position in ~2.4s. No orphaned string.
- Rapid FW → Island → FW → Island (double flip): Loading → correct FW
  position. No orphaned string.
- Runtime tray expand during island mode (no panel mode change): smooth
  slide animation preserved — `_modeTransitioning` stays false, no
  lockout engaged.
- Theme change during any panel mode: v6.15.6 behaviour preserved,
  SettingsStateV2 re-applies after reload.
