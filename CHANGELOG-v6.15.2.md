# Zen Shell v6.15.2 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.1 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** surgical fix for one issue — music string position not
live-updating + no login-time loading state. Wala tayo babawasan; 4
QML files only.

---

## Fixes

### 1. Music string floats at the wrong position on login until bar is interacted with

**Symptoms observed:**
- Kakatapos mag-login → ZenStrings visualizer mag-ffloat sa left/center
  area instead of sa music slot sa right zone.
- Position only corrects itself after user interaction — tray expand,
  workspace switch, or any bar module click.
- Real-time layout changes (sysrow gaining an icon, taskbar app opening)
  didn't shift the string into its new correct position.

**Root cause:**
`musicSlotItem.x` is a coordinate **relative to its direct parent**
(the `Loader` wrapping it inside a `Repeater` delegate). When the
grandparent `rightRow RowLayout` shifts left — because it's
`AlignRight`-anchored and gains width when sysrow loads its icons —
the Loader grandparent moves, but `musicSlotItem.x` itself never
changes. So `onXChanged` never fires.

The v6.15.1 code had one remaining fallback: `barRoot.onContentImplicitWidthChanged`.
That catches *most* reflow cases but missed async ones where the sum of
row widths momentarily cancelled out, or where the property re-evaluation
happened before QML's layout pass committed the new geometry.

Result: on login, the initial `mapToItem(barRoot, 0, 0)` read fired
before left-zone modules and sysrow tray icons finished populating,
so the recorded slot X was stale. Any subsequent layout reflow that
didn't cross the `contentImplicitWidth` delta threshold was silently
ignored — explaining why only manual interactions (which happened to
also toggle a dependent binding) triggered a re-read.

**Fix (Bar.qml — `cMusic` component):**

1. **Direct Connections on each zone row** (`leftRow`, `centerRow`,
   `rightRow`). The zone RowLayout's own `width` / `implicitWidth` /
   `x` are the most reliable signals for in-bar reflow — they fire
   synchronously on every child width change.

2. **Continuous 500ms safety poll** (`safetyPoll Timer`). Runs forever
   from `Component.onCompleted`. Each tick calls `updatePos()`, which
   no-ops unless position delta exceeds 0.5px. Cost: one `mapToItem`
   + one `abs()` comparison every 500ms = negligible. Guarantees the
   stringsWindow margin eventually converges to the true slot position
   even when every signal path misses a layout shift.

3. **`Qt.callLater` wrapping for `mapToItem`** (`updatePos` now
   defers to `_doUpdatePos` via `Qt.callLater`). This ensures the
   coordinate read happens **after** the current layout pass completes
   — prevents stale geometry on login.

### 2. No visual indicator during the initial position-resolution window

**Symptoms observed:**
- On login, may be brief moment where the string is visible but at
  the wrong position before snapping to the correct one.
- No "something is loading" signal to the user.

**Root cause:**
`stringsWindow` in `shell.qml` gated visibility on a **fixed 1.5s
timer** (`stringsFadeInTimer`). That interval was picked empirically;
sometimes the layout settled faster, sometimes slower (taskbar app
enumeration, systray icon load from D-Bus). Either way, there was no
cross-fade UX — the ZenStrings overlay just appeared once the timer
fired, at whatever position was recorded at that moment.

**Fix (shell.qml — `stringsWindow`):**

- Replaced the fixed 1.5s `stringsFadeInTimer` with a
  **stability-based** `stringsStabilityTimer` (600ms).
- Every time `ZenStringsState.musicSlotLocalX` or
  `.musicSlotLocalWidth` changes, the timer restarts. It only fires
  when **no position change has happened for 600ms**, which is the
  actual "layout settled" signal we want.
- When the timer fires, `stringsWindow.positionReady = true` **and**
  `ZenStringsState.positionReady = true` — broadcasts readiness so
  in-bar placeholder can fade out in sync.
- Post-ready behaviour:
  - **Small drift** (≤ 50px, e.g. sysrow gained one icon) → position
    updates smoothly, readiness stays true, no visual flicker.
  - **Large relocation** (> 50px, e.g. user dragged the music module
    to a different zone in PanelPage) → readiness resets to false,
    placeholder re-shows, strings fade back in at the new location
    once stable.
- `enabledChanged` and `stringLengthChanged` both reset readiness and
  restart the stability timer, so toggling ZenStrings off/on or
  resizing via settings gives the same clean transition.

**Fix (MusicStrings.qml):**

Added a `loadingPlaceholder` Item — `Row` with a pulsing dot + italic
"Loading…" text — anchored inside the MusicStrings bar slot. Because
MusicStrings lives *inside* the bar's `RowLayout`, its position is
always correct (the RowLayout handles child layout natively) — so the
"Loading…" indicator renders exactly where the strings will appear a
moment later.

- Opacity bound to `!ZenStringsState.positionReady`.
- `NumberAnimation Behavior`, 350ms, `OutCubic`.
- Sequential pulse animation on the dot (0.3 ↔ 1.0 opacity, 700ms
  each) runs only while the placeholder is visible — stops cleanly
  when faded out.
- Uses `ThemeService.alpha(ThemeService.fg, 0.65)` / `0.55` so it
  matches whatever theme the user has active.

### 3. Cross-fade choreography

On login, the two animations are now timed to overlap cleanly:

| Element                            | Animation                | Duration |
|------------------------------------|--------------------------|----------|
| MusicStrings `loadingPlaceholder` | opacity 1 → 0, OutCubic  | 350ms    |
| stringsWindow `visible`            | false → true (instant)   | 0ms      |
| ZenStrings overlay `opacity`       | 0 → 1, OutCubic          | 400ms    |

Both trigger off the single signal `ZenStringsState.positionReady`
going true, so they stay perfectly in sync.

---

## Files changed

```
zen-shell-v5/Bar.qml              v6.15   → v6.15.2
zen-shell-v5/MusicStrings.qml     v6.15   → v6.15.2
zen-shell-v5/ZenStringsState.qml  v6.15   → v6.15.2 (+ positionReady)
zen-shell-v5/shell.qml            v6.15.1 → v6.15.2 (stringsWindow block only)
```

All other files in v6.15.1 are untouched. No changes to `install.sh`,
`bootstrap.sh`, `hypr-config/`, `scripts/`, `themes-builtin/`, or any
other QML.

---

## Migration

No config migration needed. `strings-state.json` schema unchanged
(`positionReady` is runtime-only, not persisted).

**Apply by drop-in replace:**

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5   # wherever your v6.15.1 lives
cp /path/to/patch/zen-shell-v5/Bar.qml             .
cp /path/to/patch/zen-shell-v5/MusicStrings.qml    .
cp /path/to/patch/zen-shell-v5/ZenStringsState.qml .
cp /path/to/patch/zen-shell-v5/shell.qml           .

# Reload the shell
qs -c zen-shell kill 2>/dev/null; pkill -f 'qs.*zen-shell'
# then re-launch however you normally start it (systemd user unit, exec-once, etc.)
```

---

## Known unchanged behaviour (verified)

- MusicWidget fallback (ZenStringsState.enabled = false) — **unchanged**.
- cava polling + playerctl + tooltip hover — **unchanged**.
- Screenshot rope — **unchanged**.
- Panel mode (fullwidth/floating/island) positioning — **unchanged**;
  the `barLeftOffset` calculation in stringsWindow is untouched.
- `curveHeight` / `verticalPadding` overflow geometry — **unchanged**.
- Theme color derivation (`color1` / `color2`) — **unchanged**.
- All 17 builtin themes — **unchanged**.

---

**Tested matrix:**
- Hyprland 0.54 + Quickshell 0.2.1
- Panel modes: fullwidth, floating, island
- Module zones: music in left, center, right (no regressions when
  relocated via PanelPage drag — placeholder re-shows briefly during
  the >50px jump, then fades to strings at new position)
- Multi-monitor: position tracked per-screen via `Variants` unchanged
