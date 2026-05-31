# Zen Shell v7.0.0-beta.1-hf95.15 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**The Super+Shift+T quick terminal now pops up at TOP-CENTER (horizontally
centered, anchored near the top edge).** Wala tayong babawasan.

---

## Quick terminal → top-center

- `move 50%-550 40` — horizontally centered (offset by half the 1100px
  width, since `move` positions the top-left corner), 40px from the top
  edge. Replaces the full-center `center 1` from hf95.14.
- Still `size 1100 600`, `animation popin 90%`, Super+Shift+T, separate
  `--class zen-quickterm` + `~/.config/alacritty-quick/` config. Normal
  Alacritty untouched.

Note: if you change the width, also update the `-550` offset to half the
new width (e.g. width 1400 → `move 50%-700 40`).

## Version

- `ZenVersion.qml` bumped `hf95.14` → `hf95.15`.

## Files touched

- `hypr-config/hyprland-layer-rules.conf` — top-center position
- `scripts/zen-quickterm.sh` — header comment
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
