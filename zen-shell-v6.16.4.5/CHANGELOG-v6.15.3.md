# Zen Shell v6.15.3 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.2 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** hotfix sa v6.15.2 — yung "Loading…" placeholder ng music
strings nag-loop forever. 2 QML files lang, walang ibang binawas.

---

## Fixes

### 1. Music strings "Loading…" placeholder never resolves

**Symptoms observed after v6.15.2:**
- Pag-login, "Loading…" placeholder tuluy-tuloy ang pulse, hindi
  naman nag-fade sa actual ZenStrings visualizer.
- Totally idle mo lang ang bar (walang user interaction, walang
  playing music) — still stuck sa Loading.

**Root cause:**
`ZenClock` module updates `now = new Date()` every 1000ms, and the
default clock format includes live seconds (e.g. `2026-04-20 03:08:16 PM`).
When the second-digit ticks over, the rendered text's
`implicitWidth` shifts by ~0.5–2px because the font is not strictly
monospaced — different glyphs ("6" → "7", "9" → "0") occupy
slightly different advance widths.

That sub-pixel width change propagates through the layout:

```
clockText.implicitWidth → clockRoot.implicitWidth
→ rightRow.implicitWidth (via Layout.preferredWidth)
→ Bar.qml's Connections { target: rightRow; onWidthChanged }
→ musicSlotItem.updatePos()
→ mapToItem(barRoot) returns new absolute X
→ delta vs previous X exceeds the 0.5px write threshold
→ write ZenStringsState.musicSlotLocalX
→ shell.qml's stringsStabilityTimer.restart()
```

Because the stability window was 600ms but the clock emitted a
write-worthy change every ~1000ms, *plus* taskbar badge counts
(e.g. Brave's tab count "4", VS Code's "2") and sysrow state icons
contributed additional sub-second jitter, the cumulative pattern
restarted the stability timer often enough that it **never fired**.

Result: `positionReady` stayed `false` forever, so
`stringsWindow.visible` stayed `false`, so MusicStrings.qml's
`loadingPlaceholder.opacity` stayed at `1.0` forever. Infinite
"Loading…".

**Fix (Bar.qml — `_doUpdatePos`):**

- Write threshold bumped from **0.5px → 2.0px**.
- 2px is below visual perception for this use case — the bow
  curves swing by `curveHeight` (default 60px) anyway, so a 2px
  horizontal offset on the string's anchor point is invisible.
- 2px is also above every jitter source I could observe:
  - Clock second-digit rendering: ≤ 2px across the Noto Sans
    variants used by the default themes.
  - Badge count width change (1-digit ↔ 2-digit): ~5-8px — still
    triggers, as intended, since it's a genuine layout change.
  - Taskbar icon hover/active indicator: irrelevant (doesn't
    change the icon's own width).

**Fix (Bar.qml — `safetyPoll`):**

- Now auto-stops once `ZenStringsState.positionReady` flips true,
  and auto-restarts on explicit user setting changes (`enabledChanged`,
  `stringLengthChanged`).
- Steady state = zero continuous polling. The zone-row Connections
  (leftRow/centerRow/rightRow widthChanged) still catch all genuine
  runtime reflows (sysrow icon added, notification count change,
  etc.) instantly via signal — nothing is lost.

**Fix (shell.qml — `stringsWindow`):**

1. **Absolute 4s max-wait timer** (`stringsMaxWaitTimer`). This
   is the ultimate fuse: regardless of stability outcome, after
   4 seconds from stringsWindow creation the strings WILL become
   visible. Prevents any future loop-like pathology, even ones
   we haven't discovered yet.

2. **Once-ready-stays-ready**. Removed the v6.15.2 "large jump
   (>50px) re-enters loading" heuristic. Natural runtime jitter
   made the 50px threshold unreliable — it was either too tight
   (tripped by a single badge width change that cumulatively moved
   the slot) or too loose (didn't react when the user actually
   dragged the module to a new zone). Instead, `positionReady`
   is now a one-way flip for the session duration. Subsequent
   position changes just update `stringsWindow.margins.left` via
   the existing binding — smooth, no loading flicker.

3. **User-driven reset preserved**. If the user toggles
   ZenStrings off/on via GeneralPage, or changes `stringLength`
   via strings settings, we do reset `positionReady = false` and
   restart both stability + max-wait timers — because in those
   cases a fresh transition makes sense.

### 2. New behavior summary

| Scenario                         | Before v6.15.3              | After v6.15.3                   |
|----------------------------------|-----------------------------|---------------------------------|
| Fresh login, no music playing    | Loading forever (bug)        | Loading → strings in ≤4s ✓      |
| Fresh login, music already playing| Loading forever (bug)       | Loading → strings in ≤4s ✓      |
| Clock ticks every 1s             | Restarts stability (loop)   | Below 2px threshold, ignored ✓ |
| Sysrow gains new icon            | Smooth reposition           | Smooth reposition (unchanged)   |
| User toggles ZenStrings off→on   | Loading → strings           | Loading → strings (unchanged)   |
| User drags music to new zone     | Loading → strings at new pos| Smooth slide to new position    |

---

## Files changed

```
zen-shell-v5/Bar.qml              v6.15.2 → v6.15.3
zen-shell-v5/shell.qml            v6.15.2 → v6.15.3 (stringsWindow block only)
```

`MusicStrings.qml` and `ZenStringsState.qml` **unchanged** from
v6.15.2 — their logic is sound. Only the consumer side (stability
detection in shell.qml, write threshold in Bar.qml) needed tuning.

---

## Migration

No config migration, no schema changes, no new dependencies.
`strings-state.json` untouched.

**Apply by drop-in replace (from v6.15.2):**

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5   # or wherever your install lives
cp /path/to/patch/zen-shell-v5/Bar.qml   .
cp /path/to/patch/zen-shell-v5/shell.qml .

# Reload
pkill -f 'qs.*zen-shell' && sleep 0.3 && qs -c zen-shell &>/dev/null &
```

Or run the bundled `install.sh` — idempotent, preserves user config.

---

## Known unchanged behaviour (verified)

- MusicStrings hover tooltip — unchanged.
- Loading placeholder pulse animation — unchanged.
- Cross-fade timing (Loading 350ms / ZenStrings 400ms) — unchanged.
- cava beat reactivity, glow, color modes, screenshot rope — all
  unchanged.
- Panel modes (fullwidth / floating / island) — position tracking
  still mode-aware via existing `barLeftOffset` logic.
- Multi-monitor — per-screen `stringsWindow` via `Variants` block,
  each with its own stability + max-wait timers (independent fuses).

---

**Tested matrix:**
- Fresh login with 5+ open apps (Steam, Brave, VS Code, etc.) — strings
  appear within 1-2s stable detection.
- Idle bar, just clock ticking — strings still appear (via stability
  now that the 2px threshold ignores the tick jitter).
- Worst case (imagined): every module continuously shifting by >2px
  every 300ms — strings still appear at 4s via max-wait fuse.
