# Zen Shell v7.0.0-beta.1-hf95.21 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Fix: minimizing the Settings / Control Center from its hyprbars title
bar made it vanish with no way back. The minimize button is removed from
that title bar (maximize + close stay).** Wala tayong babawasan.

---

## Fix

The restored mimic title bar showed a minimize button (HyprbarsService's
default `showMinimize = true`), but ZenSettings is a layer-shell popup
with no taskbar entry — so a "minimized" window can never be restored. It
just disappeared.

ZenSettings now sets `showMinimizeButton: false` on its mimic bar, so only
maximize (fullscreen toggle) and close are shown — both of which make
sense for a popup. `onMinimizeClicked` is also wired to a harmless no-op
in case the button is re-enabled. This only affects the Settings window's
title bar; the global hyprbars minimize setting for real Hyprland windows
is unchanged.

## Version

- `ZenVersion.qml` bumped `hf95.20` → `hf95.21`.

## Files touched

- `zen-shell-v5/ZenSettings.qml` — hide minimize on the Settings mimic bar
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
