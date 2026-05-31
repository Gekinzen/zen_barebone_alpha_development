# Zen Shell v7.0.0-beta.1-hf95.5 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Music Strings now render on a vertical bar too. When strings are
enabled and the bar is vertical, the same ZenStrings visual appears
rotated 90° — running top-to-bottom and bowing sideways — centered on the
music slot.** Wala tayong babawasan. (v1 — positioning may need tuning.)

---

## Background

The horizontal strings overlay is deliberately suppressed on vertical
bars (it draws left-to-right across a horizontal music slot). On a
vertical bar there was simply no string. This adds a vertical sibling
overlay that reuses the existing `ZenStrings` visual via a 90° rotation,
so all the bezier / cava-reactive / color logic is shared — nothing in
the horizontal path changes.

## 1. ZenStringsState — vertical slot tracking (new)

Added `musicSlotLocalY` and `musicSlotLocalHeight`. The horizontal
fields only tracked X/width; the vertical overlay needs the slot's Y +
height to center the rotated string. The vertical bar window is
full-height at the screen edge, so `musicSlotLocalY` doubles as the
slot's screen-space Y.

## 2. BarVertical — music host loads MusicStrings + reports Y

`cMusicV` is now a thin host that:

- loads `MusicStrings.qml` (the invisible cava + track poller) when
  `ZenStringsState.enabled`, exactly like Bar.qml's horizontal `cMusic`,
  and the normal `MusicWidget { zenVertical: true }` play/pause icon when
  disabled (original behaviour preserved);
- reports its Y + height to `ZenStringsState` via a parent-chain walk to
  `barRootV` (the same robust approach Bar.qml uses for X), with a 2px
  write threshold, `Component.onCompleted`, signal hooks, and a 700ms
  safety poll.

The slot is kept thin (bar thickness) so MusicStrings' 200px implicit
width can't widen the bar.

## 3. shell.qml — vertical strings overlay (new)

A new `WlrLayer.Top` overlay (`zen-shell-strings-v`), gated on
`PanelState.isVertical && ZenStringsState.enabled && a real slot Y`. It
sits on the bar's edge, is sized thin (bar thickness + sideways bow) ×
tall (string length), and positions `margins.top` to center on the music
slot. Inside, `ZenStrings` is instantiated with `width = stringLength`,
`height = bowSpan`, `rotation: 90` — turning the horizontal string into a
vertical one. Click-through via `mask: Region {}`. The horizontal
overlay is untouched and the two are mutually exclusive (isHorizontal vs
isVertical).

## Known: positioning is a v1

Like the horizontal strings (which took many iterations to position
correctly), the vertical placement — the exact `margins.top` offset, the
sideways bow centering/direction on left vs right bars — may need
tuning against your actual screen. If it sits too high/low, bows the
wrong way, or clips, tell me what you see and I'll adjust.

## Version

- `ZenVersion.qml` bumped `hf95.4` → `hf95.5`.

## Files touched

- `zen-shell-v5/ZenStringsState.qml` — `musicSlotLocalY` / `musicSlotLocalHeight`
- `zen-shell-v5/BarVertical.qml` — `cMusicV` host (MusicStrings load + Y reporting)
- `zen-shell-v5/shell.qml` — `stringsWindowV` vertical overlay
- `zen-shell-v5/ZenVersion.qml` — version string

`ZenStrings.qml` is reused unchanged (rotated at the call site). No
feature, setting, or file removed.
