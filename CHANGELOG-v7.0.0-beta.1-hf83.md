# Zen Shell v7.0.0-beta.1-hf83 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

Four user-requested fixes, all additive. **Wala tayong babawasan** — every
prior behavior is preserved behind a toggle; nothing was removed.

---

## 1. Auto bar height — bar hugs its icons

The bar can now size its height to fit its tallest module automatically,
instead of a fixed pixel value.

- **`PanelState.qml`**
  - New `barAutoHeight` (bool, default `false`) + `barAutoHeightPadding`
    (int, default `8`). Saved / loaded / reset alongside `barHeight`.
- **`Bar.qml`**
  - New `contentImplicitHeight` readonly = `max(leftRow, centerRow,
    rightRow)` implicitHeight, floored at 20. Each zone already reports
    its tallest child's height (per-Loader forwarding from
    v6.16.4.12.6.51), so this measures real content.
- **`shell.qml`**
  - The bar window's `implicitHeight` uses
    `contentImplicitHeight + padding*2` when `barAutoHeight` is on,
    else the fixed `barHeight`. Edge margin still added on top.
- **`PanelPage.qml`**
  - New "Auto height" switch + "Auto height padding" slider. The manual
    "Bar Height" slider is disabled/greyed while auto is on (kept, not
    removed).

Default OFF → existing installs keep their saved fixed height until they
flip the toggle.

## 2. Settings title — full-width header

The "⚙ Settings" title now spans the full width of the Settings window,
above both the sidebar and the content area.

- **`ZenSettings.qml`**
  - New `fullWidthHeader` (bool, default `true`).
  - The sidebar+content `RowLayout` is now wrapped in a `ColumnLayout`,
    with a new full-width header band on top (gear + "Settings" +
    maximize/restore + close + drag handle). Top corners follow the
    window radius.
  - The old in-sidebar header is hidden (height 0) when
    `fullWidthHeader` is on — its wiring is intact, so flipping the flag
    off restores the previous layout.

## 3. Dock reserves space — no more tiling overlap

Enabling the dock no longer overlaps Hyprland tiles. The dock now
reserves a layer-shell exclusive zone so tiled windows sit clear of it.

- **`DockState.qml`**
  - New `reserveSpace` (bool, default `true`) + `reserveGap` (int,
    default `6`). New `exclusiveZonePx` readonly =
    `height + marginEdge + reserveGap` when reserving. Saved / loaded /
    reset.
- **`shell.qml`**
  - Dock window switches from `ExclusionMode.Ignore` to
    `ExclusionMode.Normal` with an explicit `exclusiveZone` when
    `reserveSpace` is on. Flip it off for the old overlapping Mac-dock
    float.
- **`DockPage.qml`**
  - New "Reserve space" switch + "Reserve gap" stepper.

Because the dock is opt-in (`enabled` defaults false), no existing
non-dock user is affected; a freshly-enabled dock behaves as asked.

## 4. Desktop icons — single resizable widget

New optional mode that gathers every desktop icon into ONE movable,
resizable panel, with icons resolved the SAME way the taskbar resolves
app icons.

- **`DesktopIconsWidget.qml`** (NEW)
  - One panel: drag the title bar to move, drag the ◢ handle to resize
    (the grid reflows), double-click a tile to launch.
  - `resolveIcon()` mirrors the taskbar / `DesktopIcon` staged lookup
    exactly: `iconAbsPath` → inline absolute → theme by name →
    `AppLauncherService.apps` (Quickshell.DesktopEntries) Name=/id +
    substring match → theme by basename → glyph fallback. So Steam /
    Lutris launchers show their real app icons.
- **`DesktopIconsState.qml`**
  - New `widgetMode` (bool, default `false`), panel geometry
    (`widgetX/Y/W/H`, defaults 80,80,560,380), `widgetIconSize`
    (default 56), min-size clamps, and `setWidgetGeometry()` (single
    debounced commit on drag/resize release). Saved / loaded / reset.
- **`DesktopSurface.qml`**
  - Scattered icon Repeater, folder layer, and empty-state hint are now
    gated behind `!widgetMode`; the `DesktopIconsWidget` is mounted and
    self-gates on `widgetMode`. The scatter path is otherwise untouched.
- **`DesktopPage.qml`**
  - New "Single widget" switch + "Widget icon size" stepper + "Reset
    widget position" button.

Default OFF → the classic scattered free-form icons stay until the user
opts into the single-widget mode.

---

## Files touched

```
ZenVersion.qml          version bump → v7.0.0-beta.1-hf83
PanelState.qml          barAutoHeight + barAutoHeightPadding
Bar.qml                 contentImplicitHeight
shell.qml               bar auto-height binding + dock exclusiveZone
PanelPage.qml           auto-height toggle + padding slider (gates manual slider)
ZenSettings.qml         fullWidthHeader + top header band
DockState.qml           reserveSpace + reserveGap + exclusiveZonePx
DockPage.qml            reserve-space toggle + gap stepper
DesktopIconsState.qml   widgetMode + panel geometry + setWidgetGeometry()
DesktopSurface.qml      gate scatter behind !widgetMode + mount widget
DesktopPage.qml         single-widget toggle + size + reset
DesktopIconsWidget.qml  NEW — single resizable icon panel
```

Targets Hyprland 0.54+. New windowrule/layerrule syntax unaffected.
Wala tayong babawasan.
