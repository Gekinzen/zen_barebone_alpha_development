# Zen Shell v7.0.0-beta.1-hf86 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

Three shipped items + one planned (vertical bar/dock — scoped, not
shipped; see roadmap). Additive; defaults preserve current behavior.
Wala tayong babawasan.

---

## A. Module size — manual control (+ the existing dynamic toggle)

Answer to "pwd ba ma-adjust ang laki ng modules?" — yes, two ways now:
- **Dynamic** = the hf84 "Fit contents to bar" toggle (icons scale with
  bar height).
- **Manual** = NEW **"Module size"** slider (60–200%), applied on top of
  (or instead of) the dynamic scale.

- **`PanelState.qml`** — new `barModuleScale` (real, default `1.0`),
  saved / loaded / reset.
- **`Theme.qml`** — `barContentScale` now = `barModuleScale ×
  (fitContents ? barHeight/60 : 1)`, clamped 0.6–2.4. Every module that
  already reads `Theme.iconSize`/`fontSize`/`moduleHeight` or the per-
  module `_fit` (Taskbar/SysRow/Workspaces, hf84) scales for free.
- **`PanelPage.qml`** — "Module size" slider.

## B. Modern buttons — `ZenButton`

New **`ZenButton.qml`** — a theme-aware push button to replace the flat
platform `Button {}` that looked "basic" (e.g. the Animations page
"Open"). Rounded (styleMode-aware), hairline border, hover-lift +
press-sink, accent / subtle / danger variants, optional Nerd Font icon.

Applied so far:
- **`ControlCenterBanner.qml`** — the "Open" button (shared banner reused
  across many settings pages → one swap, broad effect).
- **`DesktopPage.qml`** — Refresh (accent) / Reset positions / Reset
  panel / Reset all (danger).
- **`UserManagementPage.qml`** — Create (accent).

`ZenButton` is a drop-in (`text` + `onClicked`); remaining plain
`Button {}` instances across pages can migrate to it incrementally.

## C. Settings sidebar — rounded vs square hover

New setting for the left-panel nav hover highlight shape.

- **`PanelState.qml`** — `settingsHoverStyle` ("rounded" | "square",
  default rounded), saved / loaded / reset.
- **`ZenSettings.qml`** — nav-item hover `radius` bound to it (8 vs 2).
- **`GeneralPage.qml`** — new "Settings UI → Sidebar hover style"
  dropdown.

---

## D. Vertical bar + dock (PLANNED — not in this drop)

Studied your `dots-hyprland` `ii/verticalBar` reference. The approach,
captured for the dedicated implementation pass (roadmap "Tategaki
Redux", now enriched):

- **Window:** `PanelWindow` anchored to one vertical edge
  (`anchors.left` xor `anchors.right`), `anchors.top` + `anchors.bottom`
  true (full height), fixed `implicitWidth = barThickness`,
  `exclusiveZone = barThickness` (push windows) — mirrors the hf83 dock
  reserve-space pattern, just on the vertical edge.
- **Content:** swap `Bar.qml`'s `RowLayout` for a `ColumnLayout` with
  top / center(`fillHeight`) / bottom sections, modules
  `Layout.alignment: Qt.AlignHCenter`. Resources/clock/media render
  vertically (circular progress, stacked glyphs).
- **Dock:** same — `ColumnLayout` body, edge-anchored, optional
  reserve-space.

This is an XL change (and Tategaki was rolled back once), so it gets its
own focused drop rather than riding along here and risking your daily
driver. Plan is in the roadmap.

---

## Files touched

```
ZenVersion.qml          → v7.0.0-beta.1-hf86
PanelState.qml          barModuleScale + settingsHoverStyle
Theme.qml               barContentScale folds in barModuleScale
PanelPage.qml           Module size slider
ZenSettings.qml         nav hover radius ← settingsHoverStyle
GeneralPage.qml         Settings-UI hover-style dropdown
ZenButton.qml           NEW — modern button component
ControlCenterBanner.qml Open → ZenButton
DesktopPage.qml         buttons → ZenButton
UserManagementPage.qml  Create → ZenButton
```

Carries forward hf83–hf85. Wala tayong babawasan.
