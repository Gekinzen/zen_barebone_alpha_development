# Zen Shell v7.0.0-beta.1-hf84 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

Follow-up to hf83. Fixes the real ask behind "auto fit yung mga nasa
loob": the **contents** of the bar (icons + text) now scale to the bar
height — not just the bar hugging its contents.

Additive. Default OFF → identical to hf83 until the toggle is flipped.
Wala tayong babawasan.

---

## Fit contents to bar (NEW)

New **Panel → Background & Shape → "Fit contents to bar"** toggle. When
on, bar module content scales with the bar height: taller bar → bigger
icons, shorter bar → smaller icons.

### How it works
- **`Theme.qml`**
  - New `barContentScale` (readonly): `1.0` unless
    `PanelState.barFitContents` is on, in which case it tracks the
    `barHeight` slider relative to a 60px baseline (clamped 0.7–2.2).
    Guarded with `typeof PanelState` so early evaluation is safe.
  - `fontSize` / `iconSize` / `moduleHeight` are now readonly bindings =
    `*Base × barContentScale`. The new `fontSizeBase` (14),
    `iconSizeBase` (20), and `moduleHeightBase` (40) hold the
    user/theme preference. Every module that reads `Theme.iconSize` /
    `Theme.fontSize` / `Theme.moduleHeight` (Clock, StartMenu,
    NotificationIcon, PowerBadge, MusicWidget, battery, …) scales for
    free — no per-module change.
- **`ThemeService.qml`**
  - Theme snapshot + load now read/write `fontSizeBase` / `iconSizeBase`
    (so the saved value is the unscaled preference).

### Modules with hardcoded sizes — now wired to the scale
These didn't read `Theme.iconSize`, so they needed an explicit hook
(each multiplies by a local `_fit = Theme.barContentScale`, = 1.0 when
the toggle is off, so behavior is byte-identical to hf83 by default):
- **`Taskbar.qml`** — `btnSize`/`btnSpacing`/`chevronWidth`, root height,
  row height, app-button size, and app-icon image all scale. Because
  `btnSize` drives every slot position, the whole taskbar reflows
  cleanly. (These are the app icons in the bottom-left cluster.)
- **`SysRowIcon.qml`** — the per-icon glyph (volume / wifi / temp / …)
  scales. Tooltip popup text left unscaled.
- **`SysRow.qml`** — the three always-/expanded main-row glyphs
  (chevron, sound chip, end separator) scale.
- **`Workspaces.qml`** — workspace dot size + label font scale (on top
  of the existing dot-size settings).

`StartMenu` keeps using its explicit **Start Button Icon** setting (you
set it deliberately), so it is intentionally NOT double-scaled.

- **`PanelState.qml`** — new `barFitContents` (bool, default `false`),
  saved / loaded / reset.
- **`PanelPage.qml`** — the "Fit contents to bar" switch.

---

## Files touched

```
ZenVersion.qml     → v7.0.0-beta.1-hf84
Theme.qml          barContentScale + base sizes + derived iconSize/fontSize/moduleHeight
ThemeService.qml   read/write *Base sizes
PanelState.qml     barFitContents
PanelPage.qml      Fit-contents toggle
Taskbar.qml        _fit scaling (btnSize-driven reflow)
SysRowIcon.qml     _fit glyph scaling
SysRow.qml         _fit main-row glyph scaling
Workspaces.qml     _fit dot + label scaling
```

Carries forward all of hf83 (auto bar height, full-width Settings
header, dock reserve-space, single-widget desktop icons).
Wala tayong babawasan.
