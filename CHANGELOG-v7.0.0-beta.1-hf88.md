# Zen Shell v7.0.0-beta.1-hf88 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

Answers from the picker, implemented. Additive. Wala tayong babawasan.

---

## 1. Uniform module height (you said: yes, all uniform)

All bar modules now share ONE height = `Theme.moduleHeight` (which the
music widget already used), so everything lines up and stays centered
when you adjust the bar — matching the music-strings feel.

- **`Taskbar.qml`** — `btnSize` + root height now track
  `Theme.moduleHeight` (was 48 / 40·_fit). Buttons fill the pill; the
  whole strip reflows.
- **`SysRow.qml`** / **`Workspaces.qml`** — `implicitHeight` now
  `Theme.moduleHeight` (was `parent.height`, which made them as tall as
  the whole bar). Now they're the same height as every other module and
  vertically centered.

`Theme.moduleHeight` already folds in `barContentScale` (fit-contents +
manual Module-size from hf84/hf86), so uniform height scales too.

## 2. Quick Settings position — top / center / bottom

The Control Center (quick settings) popup can now anchor to the top or
bottom edge, not just center — so it sits near a top/bottom bar.

- **`PanelState.qml`** — `controlPanelPosition` ("center" | "top" |
  "bottom", default center) + `controlPanelEdgeMargin` (12), saved /
  loaded / reset.
- **`shell.qml`** — the popup anchors center / top / bottom accordingly
  (dragging still breaks the anchor and frees it).
- **`PanelPage.qml`** — new "Quick Settings position" dropdown.

## 3. Draggable widgets + desktop icons — confirmed

Checked the drag wiring for the "same as music strings" ask: the
desktop widgets (clock / weather / sysmon), sticky notes, the scattered
desktop icons, AND the single-widget desktop-icons panel are **already
drag-movable** (each has a `drag.target` MouseArea). No change needed —
they all move. If you meant dragging individual icon tiles *inside* the
single-widget panel (it reflows as a grid today), tell me and I'll add
per-tile reordering there.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf88
Taskbar.qml      btnSize + height → Theme.moduleHeight
SysRow.qml       implicitHeight → Theme.moduleHeight
Workspaces.qml   implicitHeight → Theme.moduleHeight
PanelState.qml   controlPanelPosition + controlPanelEdgeMargin
shell.qml        control-panel position anchoring
PanelPage.qml    Quick Settings position dropdown
```

Carries forward hf83–hf87 (incl. hf87's ZenButton migration: 25
converted, 19 custom-styled left as-is).

---

## Still queued
- **Vertical music strings** + vertical bar/dock (dots-hyprland
  approach) — the dedicated Tategaki drop.
