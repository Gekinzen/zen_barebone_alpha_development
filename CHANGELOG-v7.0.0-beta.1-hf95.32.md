# Zen Shell v7.0.0-beta.1-hf95.32 — Karui (軽い)

Release date: 2026-06-01
Channel: beta · Codename: Karui (軽い)

**Dock icons now have an adjustable size slider, and the dock's dropdowns
("Add module", "Show on monitor") open UPWARD so they don't spill outside
the Settings window where they can't be clicked.** Wala tayong babawasan.

---

## 1. Dock icon size (resizable)

New **Settings → Dock → Icon size** (60–200%, default 100%). This scales
the dock app icons independently of the bar:

- Applied as a base scale on the dock content; the crowding fit-scale
  (hf95.31) still applies on top, down to the Minimum icon scale floor.
- The dock surface height grows with the icon size (capped at 1.6×) so
  big icons aren't clipped.
- Natural-width math accounts for the scale, so overflow arrows trigger
  correctly at the chosen size.

## 2. Dropdowns open upward near the window bottom

The dock's "Add module" and "Show on monitor" dropdowns sit low in the
Settings window. Opening downward spilled the list outside the window
(over the desktop / control panel behind it), where it couldn't be
clicked.

`ZenDropdown` gained a `preferAbove` property; when set, it opens upward
whenever there's room above. Enabled on both of those dock dropdowns, so
the list now stays inside the Settings window and is selectable.

## Version

- `ZenVersion.qml` bumped `hf95.31` → `hf95.32`.

## Files touched

- `zen-shell-v5/ZenDropdown.qml` — `preferAbove` open-up option
- `zen-shell-v5/DockState.qml` — `iconSizeScale` + persistence
- `zen-shell-v5/ZenDock.qml` — apply base icon scale (× fit), grow surface height
- `zen-shell-v5/DockPage.qml` — Icon size slider + preferAbove on dropdowns
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
