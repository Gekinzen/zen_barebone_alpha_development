# Zen Shell v7.0.0-beta.1-hf95.20 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Three Settings title-bar fixes (when hyprbars is on): the
"Zen-Shell-Hypr-Control-Center" title is now CENTERED (not right-aligned),
the search bar drops down to align with the "Settings" header instead of
overlapping the title, and the title bar is now DRAGGABLE.** Wala tayong
babawasan.

---

## 1. Title centered

`HyprbarsMimic` gained a `centerTitle` option that centers the title
across the whole bar regardless of button side. ZenSettings sets it, so
"Zen-Shell-Hypr-Control-Center" sits dead-center. Default is off, so
normal hyprbars windows keep their side-aware title.

## 2. Search bar aligns with the Settings header

The floating search (mounted in shell.qml) rested at a fixed
`panel.y + 12`, i.e. the very top — overlapping the centered title. It now
adds the mimic bar's height when the bar is showing, so it lines up with
the "Settings" header band below the title bar. ZenSettings exposes the
bar via `property alias hyprbarsMimic` for this.

## 3. Title bar is draggable

`HyprbarsMimic` gained a `dragTarget` property; when set, its drag area
moves that window directly (same MouseArea drag pattern as the native
header: `drag.target`, `XAndYAxis`, `preventStealing`). ZenSettings wires
`dragTarget: root` (disabled while fullscreen), so you can drag the
window by the title bar. When `dragTarget` is null it just emits
`dragRequested()` as before.

## Version

- `ZenVersion.qml` bumped `hf95.19` → `hf95.20`.

## Files touched

- `zen-shell-v5/HyprbarsMimic.qml` — `centerTitle` + `dragTarget`
- `zen-shell-v5/ZenSettings.qml` — center title, drag target, mimic alias
- `zen-shell-v5/shell.qml` — search bar rests below the mimic bar
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
