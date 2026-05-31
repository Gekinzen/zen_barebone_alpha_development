# v6.16.4.12.9 — Modori (戻り)

**Channel:** alpha
**Release date:** 2026-05-06
**Branch:** `alpha-v6.16.4.12.9`
**Predecessor (functional):** v6.16.4.12.7.1 — Tachiagari hotfix 1
**Predecessor (chronological):** v6.16.4.12.8.3 — Tategaki hotfix 3 (rolled back)

## Codename — Modori (戻り)

"Return / coming back / rollback." Fits the headline action of this
drop: the Tategaki vertical-bar rendering line (v6.16.4.12.8 →
.8.1 → .8.2 → .8.3) hit three startup-blocking parser errors in
sequence and was stabilised only by removing duplicate code, not
by validating the underlying changes against a real shell run.
The vertical-bar work was too ambitious for one session without
test infrastructure on this side. Modori restores the stable
Tachiagari .7.1 base — proven horizontal bar, 4-direction popup
logic, all the v6.16.4.12.7 features — and adds back ONLY the
narrowly-scoped, low-risk fixes from the Tategaki hotfix line that
solved real user-reported bugs:

1. **Settings persistence fix** (Theme.layoutLoader stop reading
   stale styleMode from bar-layout.json — issue first surfaced in
   user testing of .7.1, fixed during .8.1).
2. **Slider-drag corruption fix** (debounced saveState — same
   user-testing context).
3. **Title-bar user pill** (avatar + username on right side of
   Settings header — UX request from user during .8.1 work).

Vertical bar rendering (Left/Right panel position with rotated
bar + module flow) is **deferred to a future drop** with proper
runtime validation. Selecting Left/Right in Settings → Panel
applies the 4-direction popup logic (popups grow rightward on Left
bar, leftward on Right bar) but the bar itself stays horizontal —
same partial-support state as Tachiagari .7.1, with the same
yellow notice in the Settings UI explaining it.

## Files changed (vs. v6.16.4.12.7.1)

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9, codename Modori. |
| `zen-shell-v5/Theme.qml` | `layoutLoader` (the FileView that reads `bar-layout.json`) no longer applies `d.style` to `root.styleMode`. PanelState owns `styleMode` exclusively. Stale `style` field in old `bar-layout.json` files is silently ignored. |
| `zen-shell-v5/PanelState.qml` | `saveState()` is now debounced through a 200ms Timer. Renamed the actual save body to `_doSaveState()`; new `saveStateImmediate()` escape hatch for sync-save needs. Prevents corrupt JSON writes when sliders are dragged rapidly. |
| `zen-shell-v5/ZenSettings.qml` | New compact user pill in the title bar (24px avatar + username, clickable → User Profile page). Auto-hides on narrow windows where the title bar is tight. Mirrors the sidebar bottom row but minus `@hostname` to save horizontal space. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message all bumped consistently. (The final message was a long-standing stale "Hikari" string — fixed here.) |
| `CHANGELOG-v6.16.4.12.9.md` | NEW (this file). |

## Detail — what got rolled back

Everything in this list was added during Tategaki .8 / .8.1 / .8.2 /
.8.3 and is **not present** in Modori. Listed here so future work
on vertical-bar rendering knows what NOT to repeat verbatim:

- `Bar.qml` — outer container + leftRow/centerRow/rightRow rewritten
  as `GridLayout` with dynamic `flow` direction. **Status: shipped
  empty bar in user's test screenshot. Approach unsafe.**
- `Workspaces.qml` — Loader-driven Row/Column flow swap. **Status:
  user reported workspace numbers broken.**
- `SysRow.qml`, `Taskbar.qml`, `SystemTray.qml`, `ZenSysMonitor.qml`,
  `ZenWeather.qml`, `Battery.qml`, `PowerBadge.qml`, `MusicWidget.qml`,
  `WindowTitle.qml`, `Clock.qml` — orientation-aware sizing + 90°
  text rotation transforms. **Status: untested at runtime.**
- `shell.qml` — barWindow 4-direction anchoring + dimension swap;
  stringsWindow 4-direction anchoring + dimension swap; ZenStrings
  90° rotation. **Status: introduced parse-time errors in .8.2 and
  .8.3, and showed only the audio-reactive curves with empty bar
  in user's test of .8.3.**
- `PanelState.qml` — `panelMarginLeft` / `panelMarginRight`
  duplicated declarations (caused the .8.2 → .8.3 crash). **Status:
  stale duplicate from cross-session edits.**
- `ZenStringsState.qml` — added `barWindowTop`. **Status: only
  consumed by the rolled-back stringsWindow vertical math; no
  longer needed in Modori.**
- `PanelPage.qml` — green-✓ confirmation notice for vertical bars.
  **Status: replaced by the previous yellow partial-support
  notice (still accurate in Modori).**

## Detail — Theme.layoutLoader fix (kept)

Pre-Modori `Theme.qml` had this `onLoaded` body for `bar-layout.json`:

```qml
onLoaded: {
    try {
        const d = JSON.parse(this.text())
        if (d.layout) root.barLayout = d.layout
        if (d.style) root.styleMode = d.style    // ← removed
    } catch (e) {}
}
```

Why this caused the "settings revert on restart" symptom: PanelState
saves `styleMode` (along with `barOpacity` / `barRadius`) to its OWN
file `panel-state.json`. But `bar-layout.json` is mutated by
helper scripts under `~/.local/bin/` whenever the user toggles
modules in Settings → Bar Modules, AND the older shell versions
also wrote `style` to that file. So:

1. User picks Pill → `Theme.styleMode = "pill"`, then PanelState's
   `saveState()` writes `styleMode: "pill"` to `panel-state.json`.
2. User toggles a module from Bar Modules → `Theme.reloadBarLayout()`
   fires → `layoutLoader.reload()` re-reads `bar-layout.json`.
3. That file still has the stale `"style": "round"` from older
   versions.
4. `onLoaded` fires → `root.styleMode = "round"` → user's pill
   choice is silently overwritten in memory.
5. If the user then moves any slider → `saveState()` reads
   CURRENT `Theme.styleMode` (now "round") and writes that wrong
   value back to `panel-state.json`. From this point, every
   restart shows Round.

Removing `if (d.style) ...` from layoutLoader makes PanelState the
sole owner of styleMode. Old `bar-layout.json` files with the
`style` field remain readable; the field is just ignored.

## Detail — Debounced saveState (kept)

`PanelPage.qml` sliders for Bar Height / Bar Opacity / Bar Corner
Radius / etc. all call `PanelState.saveState()` on every
`onValueChanged`. On a smooth 60fps drag, that's ~30-60 fires per
second — each fires a `bash -c "cat > ... << 'ZSEOF' ... ZSEOF"`
via the shared `Process { id: stateSaver }`. Reusing the same
Process Item means a new `running = true` mid-write truncates the
heredoc and leaves a corrupt JSON file. On next start, `applyState`'s
`JSON.parse` throws → caught silently → defaults restored.

Fix: route every `saveState()` through a 200ms `Timer`. Each call
calls `saveDebounce.restart()`, which resets the timer. Only the
LAST call within a 200ms window actually triggers the file write
via `_doSaveState()` (the renamed save body).

## Detail — Title-bar user pill (kept)

User asked during .8.1 testing for the avatar+username to also be
visible from the right side of the main content area, not only
from the sidebar bottom (which was added in v6.16.4.12.7
Tachiagari). Modori adds a compact 24px-avatar + username pill on
the right side of the Settings title bar, between the gear+text
zone and the Maximize button.

Click → jumps to User Profile page (same affordance as the sidebar
version). Auto-hides on narrow windows (`root.width <= 540` when
not fullscreen) so the title bar doesn't get cramped.

`@hostname` is omitted from the title-bar version to save
horizontal space; the sidebar bottom row carries it for users who
want it.

## Detail — what's preserved from Tachiagari .7.1

Every Tachiagari .7.1 feature is fully present:

- 4-direction popup helpers (`PanelState.popupAnchorEdges` /
  `popupAnchorGravity`) — popups grow correctly on top/bottom/left/
  right bars
- 4-card Panel Position picker in Settings → Panel
- Yellow notice block under the picker explaining that Left/Right
  is popup-only for now (vertical bar rendering deferred)
- All Tachiagari .7 features: pill module shape (proper flat-top
  look), sidebar user row, Smart Gaming Detection toggle + watcher
  daemon, Start Button border tint + width slider, monitor-fix v2
  merged into install.sh
- All popup widgets bound to `PanelState.popupAnchorEdges/Gravity`:
  SysRowIcon, Taskbar (×2), MusicStrings, ZenClock (×2),
  CalendarButton

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

If you were running v6.16.4.12.8 / .8.1 / .8.2 / .8.3 (any of the
Tategaki line, including the broken ones that wouldn't start),
just re-install Modori. Saved `panel-state.json` from any prior
version loads cleanly. The `panelPosition: "left"` or `"right"`
value if previously set will continue to work — popups will follow
the position, but the bar itself returns to horizontal rendering.

## Vertical bar — future work plan

The vertical-bar rendering will return in a properly-staged drop.
Current thinking on the safer approach:

1. **Validate one module at a time.** The Tategaki attempt
   converted ~12 modules in one drop. Better: convert Workspaces
   alone first, ship, validate, then SysRow alone, etc.
2. **Keep Bar.qml as RowLayout for horizontal, ColumnLayout for
   vertical** (separate elements via Loader), not GridLayout flow
   tricks. The flow-swap approach apparently doesn't size children
   the way RowLayout does in this Quickshell build, hence the
   empty-bar symptom in user's test.
3. **No 90° text rotation transforms inside the bar.** Vertical
   bars in mainstream desktop environments (KDE, Waybar) keep text
   horizontal and just stack icons; rotation is a stylistic choice
   that adds risk.
4. **MusicStrings stays auto-hidden on vertical** for now.
   Rotation transform on PanelWindow surfaces is complex; revisit
   only after the bar itself is solid.

## Wala tayong babawasan

Modori is a SUBTRACTION in scope (vertical bar rendering removed)
but ADDITIVE in fixes (settings persistence, debounced save, title
pill all retained). The result is a clean, low-risk release that
restores horizontal-bar reliability while keeping the user-visible
fixes that solved real bugs.
