# Zen Shell v7.0.0-beta.1-hf95.14 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**The Super+Shift+T quick terminal is now CENTERED floating instead of a
top drop-down.** Wala tayong babawasan.

---

## Quick terminal → centered

Changed the `zen-quickterm` window rules:

- `size 1100 600` + `center 1` — fixed-size, centered on screen.
- `animation popin 90%` — pops in at center (was `slide top`).

Everything else is unchanged: still `Super+Shift+T`, still its own
`--class zen-quickterm` instance with the separate
`~/.config/alacritty-quick/` config, still toggled via the
`special:quickterm` workspace, and your normal Alacritty is still
untouched.

## Version

- `ZenVersion.qml` bumped `hf95.13` → `hf95.14`.

## Files touched

- `hypr-config/hyprland-layer-rules.conf` — centered rules
- `scripts/zen-quickterm.sh` — header comment
- `hypr-config/alacritty-quick/alacritty.toml` — fallback dimensions
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
