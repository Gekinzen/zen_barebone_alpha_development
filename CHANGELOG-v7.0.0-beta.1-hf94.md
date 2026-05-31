# Zen Shell v7.0.0-beta.1-hf94 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical: window-title vertical text + workspaces/host robustness.**
Additive, explicit `vertical` flags default false, guarded. Wala tayong
babawasan.

---

## 1. Window title — vertical now renders (rotated text)

The `window` module showed nothing in the vertical bar (its width came
from horizontal title text, which the host clamped to ~nothing).

- **`WindowTitle.qml`** — explicit `vertical` flag. Vertical → app icon
  on top, then the title as **90°-rotated text** (reads bottom-to-top),
  clamped so it never runs past the bar. Sizes to the bar thickness.
  Horizontal pill unchanged.
- **`BarVertical.qml`** — mounted with `vertical: true`.

## 2. Workspaces & host robustness

Workspaces (and other center-zone modules) could collapse to nothing on
first layout because the vertical module host clipped height and read a
not-yet-resolved implicit size.

- **`BarVertical.qml`** — `VerticalModuleHost` reworked: no more height
  clip; the loaded module is centered and its implicit size is forwarded
  with a `Math.max(1, …)` floor so a module never collapses to 0 while
  its real size resolves. Width is still clamped to the bar thickness so
  nothing stretches the bar.

## 3. Title translator — already vertical-safe

`TitleTranslatorModule` is a `Theme.moduleHeight` square and only
`visible` when `TitleTranslatorService.enabled`. It needs no vertical
change — when it wasn't showing, the service was simply off. Enable it in
Settings and it renders as a square icon in the vertical bar like any
other small module.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94
WindowTitle.qml  vertical rotated-text mode
BarVertical.qml  window wired vertical; VerticalModuleHost robustness
```

Carries forward hf83–hf93 (vertical Taskbar / Workspaces / Clock /
SysRow / tray / music). Horizontal bar remains the known-good pre-hf90
version; all vertical behavior is opt-in via explicit flags.

---

## Next
Vertical music STRINGS (own focused drop — the audio-reactive curves
along the side edge) → auto-hide / slide-in → rounded corner decorators.
