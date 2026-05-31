# Zen Shell v7.0.0-beta.1-hf95.8 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**The vertical music string is now SHORT and gets its own space, so it no
longer sprawls over the modules around it — and it shortens by itself as
the bar scales.** Wala tayong babawasan.

---

## What changed

- **Compact, dynamic length.** New `ZenStringsState.verticalStringLength`
  caps the vertical string to ~4 module heights (and never longer than
  the configured `stringLength`). Because it tracks `Theme.moduleHeight`,
  it also shrinks when the bar content scales — "umiiksi kusa".
- **Reserved space (like the horizontal bar).** `BarVertical`'s music
  slot now reserves that length as its HEIGHT when strings are enabled —
  mirroring the horizontal bar, where the music slot is as WIDE as the
  string. The string therefore fills its OWN space in the column instead
  of overlapping the neighbouring modules.
- **One shared value.** The overlay's `vLen` and the slot's reserved
  height both read `verticalStringLength`, so they always match and the
  string stays centered on its slot.
- Still composes with hf95.7's global scale-to-fit: if reserving the
  string's space pushes the column over the bar height, everything
  (string included) scales down together.

## Version

- `ZenVersion.qml` bumped `hf95.7` → `hf95.8`.

## Files touched

- `zen-shell-v5/ZenStringsState.qml` — `verticalStringLength`
- `zen-shell-v5/BarVertical.qml` — music slot reserves the string length
- `zen-shell-v5/shell.qml` — overlay uses the shared compact length
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. Horizontal bar untouched.
