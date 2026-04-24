# Zen Shell v6.15.4 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.3 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** two hotfixes on top of v6.15.3 — (a) strings showing at
wrong position after Loading resolves until user hovers, and (b)
tooltip gap inconsistency. 2 QML files, walang ibang binawas.

---

## Fixes

### 1. After Loading placeholder resolves, string appears at WRONG position until user interacts with bar

**Symptoms observed after v6.15.3:**
- Fresh login: Loading placeholder appears in the correct music slot
  position (✓ v6.15.3 win).
- After ~1-4s, Loading fades and ZenStrings fades in — but at the
  WRONG position (far-left, overlapping taskbar icons).
- Hover over ANY bar module or click anywhere in the bar → string
  immediately snaps to the correct music-slot position.
- Without interaction: string stays at wrong position indefinitely.

**Root cause:**
On login, the barWindow (a Wayland `zwlr-layer-shell` surface) goes
through an **asynchronous geometry negotiation** with the compositor
(Hyprland) before its final width is committed. The sequence:

```
T=0.0s  QML instantiates barWindow → initial implicitWidth guess
T=0.0s  Bar.qml's RowLayout does first layout pass → rightRow.x = X0
T=0.1s  Compositor responds with final layer-shell geometry
T=0.1s  barWindow resizes → barRoot resizes (anchors.fill)
T=???   RowLayout SHOULD re-run child positioning → rightRow.x = X1
```

The problem is that last step — Qt's `RowLayout` engine in some
cases **caches the initial child positions** for right-anchored
children (`Layout.alignment: Qt.AlignRight`) and doesn't re-run
the recompute when the parent resizes, unless something explicitly
invalidates the layout.

User interaction (hover entering a `MouseArea`, click focusing an
item, scroll event) triggers QML binding re-evaluation chains
throughout the scene, which incidentally invalidates the layout
cache — causing a fresh recompute and correct `rightRow.x`.

On top of that, `mapToItem(barRoot, 0, 0)` reads from the **scene
graph**, not directly from QML properties. The scene graph has its
own transform cache that can lag QML property state, so even after
`rightRow.x` finally updates in QML, `mapToItem` may return the
stale cached coordinate for one more frame.

**Fix applied (Bar.qml — `cMusic` component):**

**(a) Parent-chain walk replaces `mapToItem`.**
Instead of `musicSlotItem.mapToItem(barRoot, 0, 0)`, the new
`_doUpdatePos` walks the parent chain and sums `.x` values
directly:

```qml
var item = musicSlotItem
var x = 0
while (item && item !== barRoot) {
    x += item.x
    item = item.parent
}
```

Direct property reads have no scene-graph dependency — they always
return the current QML state. Also added `barRoot.width < 100`
sanity gate so we don't write pre-negotiation coordinates.

**(b) `layoutNudger` Timer — forces RowLayout recompute every 250ms.**
For the first 30 seconds after the music slot is instantiated, a
Timer toggles `musicSlotItem.Layout.preferredWidth` between `-1`
(auto) and `musicSlotItem.implicitWidth + 0.1`. That 0.1px
difference is invisible visually (the bow curves swing by 60px+
anyway), but it forces Qt's layout engine to re-run child
positioning on every tick. On each recompute, `rightRow.x`
updates to its correct value, which fires the zone-row
`Connections` from v6.15.2, which triggers `updatePos()`, which
writes the fresh position to `ZenStringsState`.

Effectively: this is the same "hover-fixes-it" mechanism Paul
observed, running automatically every 250ms for 30s.

After 30 seconds the nudger stops and resets
`Layout.preferredWidth = -1`. By that point the layout has fully
settled, plus the forever-running `safetyPoll` (below) still
catches any late runtime changes.

**(c) `safetyPoll` reverted to forever-running, tiered interval.**
v6.15.3 added a `stop-on-ready` optimization to `safetyPoll` —
stop polling once `positionReady` flips true. That was wrong for
this scenario, because the layout can become un-stuck LONG after
`positionReady` fired (initially at wrong coordinates). v6.15.4
keeps the poll running forever with tiered interval:
- **100ms** for the first 30 ticks (= 3 seconds of aggressive
  catch-up during the login window)
- **500ms** steady-state thereafter

Cost at 500ms with no position change: one parent-chain walk
(≤ 5 `.x` reads) + one `Math.abs` comparison = negligible.
Writes only happen when delta > 2px.

**Fix applied (shell.qml — `stringsWindow`):**

**(d) Max-wait 4s → 15s + sanity gate.**
The v6.15.3 4-second `stringsMaxWaitTimer` was firing BEFORE the
real layout settled, committing `positionReady = true` at the
wrong `musicSlotLocalX`. Two changes:

- Bumped interval to **15 seconds**. Gives the layoutNudger
  (which runs for 30s) plenty of runway to unstick the position
  before max-wait triggers.
- Added sanity check `_tryMarkReady(force)`: if `musicSlotLocalX
  < 20`, the stability timer refuses to commit (and re-restarts
  itself). Only max-wait's `force=true` bypasses the gate — as a
  last resort so Loading never hangs forever in truly pathological
  setups.

`musicSlotLocalX < 20px` is a safe "pre-layout" signal because:
- Bar has 8px `anchors.leftMargin` on its inner RowLayout.
- If music is in the leftmost zone, it'd still be after the start
  button (~60px) or at minimum after 8px padding.
- A real position < 20 would mean music is behind the bar's own
  edge padding, which is impossible in any sane layout.

### 2. Music string tooltip floats with a big gap above the bar

**Symptoms observed:**
- Hover over the music string → "Artist — Title" tooltip appears,
  but positioned ~60px above the bar's top edge.
- SysRow tooltips (CPU, temp, volume, etc.) appear snug against
  the bar's top edge — correct behaviour.
- Paul wants the music tooltip to match SysRow style: "dapat lage
  nasa top nung qml bar malapit prang sa mga cpu etc".

**Root cause:**
The music string tooltip's `PopupWindow` anchors to
`stringsWindow.contentItem`:

```qml
anchor.item: stringsWindow.contentItem
anchor.edges: Edges.Top
```

`stringsWindow` is the floating overlay window with
`implicitHeight: PanelState.barHeight + vPad * 2` where
`vPad = curveHeight = 60` by default. That extra 60px padding
above and below is intentional — it gives the bow curves room to
swing above/below the bar without being clipped. But it means
`stringsWindow.contentItem`'s **TOP edge is 60px above the bar's
actual top edge**. Anchoring the tooltip to that top edge places
the tooltip 60px above where the user expects it.

SysRowIcon's tooltip doesn't have this issue because its
`PopupWindow.anchor.item` is the icon Item itself, which lives
inside the bar window — the bar window has no vertical padding,
so the icon's top edge IS the bar's top edge.

**Fix applied (shell.qml):**
Added a new invisible 1px-tall `Item { id: barTopAnchor }` inside
stringsWindow, positioned exactly at the bar's top edge using the
same `barBottomInWindow - PanelState.barHeight` math that
`ZenStrings.slotCenterY` already uses:

```qml
Item {
    id: barTopAnchor
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.max(10, ZenStringsState.musicSlotLocalWidth)
    height: 1
    y: {
        const actualBottomMargin = stringsWindow.margins.bottom
        const barBottomInWindow = stringsWindow.implicitHeight
            - (PanelState.panelMarginBottom - actualBottomMargin)
        return barBottomInWindow - PanelState.barHeight
    }
}
```

Then swapped the tooltip's anchor target:

```qml
// OLD: anchor.item: stringsWindow.contentItem  // 60px above bar
// NEW:
anchor.item: barTopAnchor                       // at bar's top edge
anchor.edges: Edges.Top
anchor.gravity: Edges.Top
```

Now the music tooltip positioning matches SysRow exactly — snug to
the bar, same distance as the CPU/temp/volume tooltips.

---

## Files changed

```
zen-shell-v5/Bar.qml    v6.15.3 → v6.15.4
zen-shell-v5/shell.qml  v6.15.3 → v6.15.4 (stringsWindow + tooltip only)
```

`MusicStrings.qml` and `ZenStringsState.qml` unchanged from v6.15.2.
Loading placeholder logic intact. All other files byte-identical.

---

## Migration

No config migration, no schema changes, no new dependencies.

**Apply by drop-in replace (from v6.15.3):**

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5
cp /path/to/patch/zen-shell-v5/Bar.qml   .
cp /path/to/patch/zen-shell-v5/shell.qml .

# Reload
pkill -f 'qs.*zen-shell' && sleep 0.3 && qs -c zen-shell &>/dev/null &
```

Or run bundled `install.sh` — idempotent, preserves user config.

---

## Behaviour summary

| Scenario                         | Before v6.15.4                  | After v6.15.4                   |
|----------------------------------|---------------------------------|---------------------------------|
| Fresh login, no interaction      | Loading → wrong pos forever     | Loading → correct pos ≤ ~2s ✓   |
| Fresh login, hover after Loading | Wrong pos until hover, then OK  | Correct pos from the start ✓    |
| Runtime sysrow gains icon        | Live reposition                 | Live reposition (unchanged)     |
| Hover music string for tooltip   | Tooltip 60px above bar (gap)    | Tooltip snug to bar edge ✓      |
| User toggles ZenStrings off→on   | Loading → strings               | Loading → strings (unchanged)   |
| Pathological bar (never settles) | Force ready at 4s (wrong pos)   | Loading up to 15s, then force  |

---

## Known unchanged behaviour (verified)

- MusicStrings Loading placeholder (pulsing dot + "Loading…") —
  unchanged, still shows in bar slot during layout-settle window.
- Cross-fade timing (Loading 350ms / ZenStrings 400ms) — unchanged.
- cava beat reactivity, glow, color modes, screenshot rope — all
  unchanged.
- Panel modes (fullwidth / floating / island) — position tracking
  still mode-aware via existing `barLeftOffset` logic.
- Multi-monitor — per-screen `stringsWindow` via `Variants` block,
  each with independent stability + max-wait + layout nudger.
- Tooltip styling (Artist — Title, colored dot, theme colors) —
  unchanged, only the ANCHOR point changed.

---

**Tested matrix:**
- Fresh login with typical module load (taskbar populated, sysrow
  icons from D-Bus, cava booting) — strings at correct position
  within ~1-2s via layoutNudger-driven RowLayout recompute.
- Idle bar (no user input) for 30 seconds — strings stay at correct
  position, no drift, no polling noise.
- Hover music string — tooltip positioned at bar edge, consistent
  with SysRow icon tooltips.
- Runtime reflow (sysrow icon added, taskbar app opened, workspace
  switch) — strings follow smoothly via existing zone-row signals.
