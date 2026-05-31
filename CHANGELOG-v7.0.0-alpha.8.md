# v7.0.0-alpha.8 — Karui (軽い) · Pinned grid drag + scroll + search polish

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** Drag-and-drop pinned tiles + scrollable overflow
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this drop adds

User-requested polish for the StartMenu pinned grid + Settings search
icon style. Five things bundled together — was originally going to be
the "Spotlight palette" alpha.8, but the StartMenu issues were higher
priority for daily use, so we ship this first.

(Spotlight palette deferred to alpha.9.)

### 1. FloatingSettingsSearch — icon style matches StartMenu

Search icon and placeholder text now match the StartMenu's "Type to
search" bar exactly:

- Icon: `\uf002` (Nerd Font search glyph) — direct, not via
  MaterialIcons.icon() → consistent rendering regardless of which
  font is detected at runtime
- Placeholder: `"Type to search"` (was `"Search…"`)
- Color: blue accent on focus, grey0 idle (matches StartMenu)
- Smooth color transition (`Behavior on color`)

The floating bar in the top-right of Settings now visually matches
the StartMenu search bar — same glyph, same placeholder, same focus
treatment. Same component family even though they're separate files.

### 2. FloatingSearch persists when not focused

Bar is anchored to top-right via parent.right + parent.top with
explicit margins. Visibility is bound to the visibility of ZenSettings
itself, NOT to focus state. So the bar stays visible whenever
Settings is open, regardless of whether the user has clicked it.

### 3. Pinned grid scrollable

Replaced the static `Grid` (from QtQuick) with a `GridView` (from
QtQuick) — same visual look, different mechanics:

- **Static Grid** (old): no scrolling. When pinned items exceeded
  `gridCols × gridRows`, they overflowed visually into the Recent
  section below — exactly the bug user reported.
- **GridView** (new): clipped to its bounding box, with internal
  scrolling. When pinned items exceed visible cells, a thin scroll
  bar appears on the right (`ScrollBar.AsNeeded`).

```qml
GridView {
    cellWidth: tileSize + 8
    cellHeight: tileSize + 8
    width: gridCols * cellWidth
    clip: true
    interactive: contentHeight > height   // only scrollable when overflowing

    ScrollBar.vertical: ScrollBar {
        policy: contentHeight > height ? AsNeeded : AlwaysOff
        width: 5
    }
}
```

So if user has gridCols=4 + gridRows=4 = 16 visible cells, and pins
20 apps:
- First 16 visible normally
- Scrollbar appears on right
- Scroll down 1 row → reveals 4 more
- Recent section below is unaffected (no overlap anymore)

### 4. Pinned tiles draggable

Each tile is wrapped in a delegate Item with:
- A **DropArea** covering the cell (receives drops from other tiles)
- A **Drag** attached property on the inner tile rectangle (provides
  the drag payload)
- A **MouseArea** with `drag.target: tile` configured (drags the
  tile around the cursor)

Drag flow:

1. User left-presses a tile and starts dragging
2. Tile lifts (opacity 0.6 + scale 1.05) and follows cursor
3. As cursor moves over OTHER tiles, their cells highlight (border
   thickens, accent color)
4. On release over a target tile, the source ID splices into the
   target position
5. New order persists immediately via `AppLauncherService.reorderPinned()`

Quick clicks still launch the app (drag.threshold: 8 means 8px of
movement is required before drag engages — so a normal click triggers
the click handler, not the drag).

Right-click still opens the context menu (Pin/Unpin) — drag is
left-button only.

### 5. Pinned order persists across restarts

`AppLauncherService.reorderPinned(newOrder)` was already wired up in
v6.16 — it sets `pinnedIds = newOrder.slice()` and triggers the
state file write via the existing debounced save mechanism.

So when user drags Brave to position 1, then closes the StartMenu,
restarts Hyprland (or the whole machine), then re-opens the menu —
Brave is still at position 1.

State file: `~/.local/share/zen-shell/applauncher.state` (existing,
unchanged).

#### Smooth reorder animation

Added `moveDisplaced` transition to GridView so when items reorder
(via drag or external `reorderPinned()` call), they animate to their
new positions instead of teleporting:

```qml
moveDisplaced: Transition {
    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
}
```

180ms ease-out feels responsive without being twitchy.

---

## Files modified

```
zen-shell-v5/FloatingSettingsSearch.qml   (icon + placeholder match StartMenu)
zen-shell-v5/StartMenuPanel.qml            (pinned grid: Grid → GridView,
                                             added DropArea + Drag attached
                                             props + MouseArea drag config,
                                             added ScrollBar + moveDisplaced)
zen-shell-v5/ZenVersion.qml                (bumped to v7.0.0-alpha.8)
install.sh                                 (version strings)
```

No other files touched. AppLauncherService.qml, FlickableContainer
patterns, RecentFilesService, etc. all unchanged.

---

## Wala tayong babawasan

- All alpha.7-hf5 features intact (floating search, ZenCleanup,
  clipboard onboarding, Material font auto-detect)
- Pinned tile click → launch app (unchanged)
- Pinned tile right-click → context menu (unchanged)
- Drag-quick-release → no reorder (drag.threshold protects against
  accidental drags during normal clicks)
- AppLauncherService API unchanged (`reorderPinned()` was already
  there; we just call it from the new drag handler)
- State file format unchanged → no migration needed for existing
  installs
- Recent section layout unchanged — just no longer overlapped by
  pinned overflow

---

## Verified

- ✅ FloatingSettingsSearch.qml lint clean
- ✅ StartMenuPanel.qml lint clean
- ✅ Search icon: `\uf002` Nerd Font (matches StartMenu)
- ✅ Placeholder: "Type to search"
- ✅ GridView replaces static Grid
- ✅ ScrollBar wired with conditional policy
- ✅ DropArea on each delegate
- ✅ AppLauncherService.reorderPinned() called on drop
- ✅ moveDisplaced transition for smooth reorder

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.8-pinned-drag-scroll.tgz
cd zen-shell-v7.0.0-alpha.8
./install.sh
qs -r
```

After install:

1. **Open Settings** (Super+,) → floating search bar in top-right
   with `\uf002` Nerd Font icon, "Type to search" placeholder
2. **Open StartMenu** (Super) → pinned grid as before
3. **Pin many apps** (right-click apps in All Apps list → Pin) until
   you exceed the gridCols × gridRows cell count
4. **Notice** scrollbar appears on right of pinned grid; Recent
   section below is now intact (no overflow into it)
5. **Drag a tile** — left-press + move > 8px → tile lifts, cursor
   shows closed-hand cursor
6. **Drop on another tile** → reorder happens with smooth animation
7. **Close StartMenu, reopen** → new order persists
8. **Restart Hyprland** (`hyprctl reload`) → reopen StartMenu →
   order STILL persists (reads from state file)

---

## Roadmap update

```
✅ alpha.5 — LaptopMode
✅ alpha.6 — Search + Clipboard
✅ alpha.7 — Cleanup + Polish
✅ alpha.8 — Pinned drag + scroll + search polish ← we are here
🎯 alpha.9 — Spotlight command palette (Super+Space) — was alpha.8,
              now bumped to alpha.9 since alpha.8 took the StartMenu
              polish slot
   alpha.10 — Densho restyle
   alpha.11 — Zen Notification Center (drops SwayNC)
   ...
   beta.1-3 → v7.0.0 stable
```
