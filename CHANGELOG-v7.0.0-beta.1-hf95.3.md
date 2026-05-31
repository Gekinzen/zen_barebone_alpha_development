# Zen Shell v7.0.0-beta.1-hf95.3 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical-bar polish: MusicWidget play/pause is now clickable + shows a
hover tooltip with the current track, and SysRow stays open when you
expand it instead of auto-collapsing the moment the mouse leaves.** Wala
tayong babawasan.

---

## 1. MusicWidget — clickable play/pause + hover tooltip

**Click fix.** In the vertical bar the module is loaded through
`BarVertical`'s `VerticalModuleHost → Loader`, which sizes itself to the
item. MusicWidget only set `implicitWidth` (no explicit `width`), so the
click `MouseArea` ended up with no reliable hit area and play/pause taps
were swallowed. `Clock.qml` already sets an explicit `width`/`height` for
exactly this reason — MusicWidget now mirrors it (`width: implicitWidth`).
In a horizontal `RowLayout` the layout overrides this, so horizontal
behaviour is unchanged.

**Hover tooltip (new).** On a vertical bar only the play/pause glyph fits,
so hovering the icon now reveals what is actually playing — full,
untruncated — plus the click controls:

- Click: play / pause
- Right-click: next
- Middle-click: previous

It uses the same `PopupWindow` pattern that already works for SysRow's
tooltips (`anchor.item` + `PanelState.popupAnchorEdges/Gravity`), not a
bare module-anchored popup. Shows in both orientations — in horizontal it
surfaces the full title that the inline label truncates at 35 chars. All
existing click logic, MPRIS bindings and visibility rules are untouched.

## 2. SysRow — sticky click-to-expand

The cluster auto-collapsed as soon as the pointer left it, even right
after you clicked the arrow to open it. Now clicking the arrow **pins** it
open; moving the mouse away no longer closes it. Click the arrow again to
collapse and unpin. Mechanism:

- New `property bool pinned`.
- Arrow click sets `pinned = expanded` (pin on open, unpin on close).
- The hover `MouseArea` only restarts the collapse timer when **not**
  pinned.
- `collapseTimer.onTriggered` only collapses when **not** pinned.

The configurable hover auto-collapse (`SysRowState.collapseDelay`) is
preserved for any non-pinned expansion — nothing removed, just made to
respect explicit user intent.

## 3. Version

- `ZenVersion.qml` bumped `hf95.2` → `hf95.3`.

## Files touched

- `zen-shell-v5/MusicWidget.qml` — explicit width + hover tooltip + header
- `zen-shell-v5/SysRow.qml` — `pinned` sticky-expand logic + header
- `zen-shell-v5/ZenVersion.qml` — version string

Carried over: hf95.2 smart `install.sh` (self-heal + Workspaces clobber
fix) and hf95.1 `sync-config.sh` verify fix.

No feature, setting, or file removed.
