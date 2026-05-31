# Zen Shell v7.0.0-beta.1-hf95.11 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**The SDDM greeter now follows the user's SELECTED theme — its colours
are mapped live from the active scheme instead of being fixed
Tokyo-Night, and re-sync automatically whenever the theme is applied.**
Wala tayong babawasan.

---

## SDDM greeter colours are now dynamic

Previously the Zen Tokyo greeter shipped fixed Tokyo-Night colours in
`theme.conf`. Now `zen-sddm-sync.sh` reads the user's active scheme from
`~/.config/hypr-control-center/current-theme.json` (the same file
`ThemeService` writes) and maps it into the greeter, with the same colour
roles the QML uses:

| theme.conf key   | scheme colour |
|------------------|---------------|
| colorBackground  | bg0           |
| colorSurface     | bg2           |
| colorText        | fg            |
| colorTextDim     | grey1         |
| colorAccent      | blue          |
| colorAccentText  | bg0           |
| colorSuccess     | green         |
| colorError       | red           |
| colorBorder      | bg3           |

Each key falls back to its existing value if the scheme omits it (only
`#hex` values are written), so a partial theme can't blank the greeter.

Verified by mapping Dracula, Nord and Gruvbox through the logic — each
produces its own correct palette.

## Auto re-sync on theme apply

`ThemeService` now fires a fire-and-forget `sddmThemer` at all three
theme-apply paths (custom-profile save, normal apply, matugen apply). It
runs `zen-sddm-sync.sh` via pkexec (allowed without a prompt by the
polkit rule from `zen-sddm-install.sh`). It is a complete no-op when the
SDDM theme isn't installed (`-x` guard), so users who never set up the
greeter are unaffected — including the per-user install, which is
unchanged.

So the flow is now: pick a theme in Settings → the desktop, terminals,
notifications AND the login greeter all retheme together.

## Notes

- Colours come from the scheme's base palette. If you later want the
  greeter to also follow matugen wallpaper-derived colours specifically,
  that already works too — matugen overwrites `current-theme.json`, which
  is exactly what the sync reads.
- Run `sudo ./sddm/zen-sddm-install.sh` once so the sync binary + polkit
  rule are in place; after that, theme changes propagate automatically.

## Version

- `ZenVersion.qml` bumped `hf95.10` → `hf95.11`.

## Files touched

- `sddm/scripts/zen-sddm-sync.sh` — map active scheme → theme.conf colours
- `sddm/zen-tokyo/theme.conf` — header note (now dynamic)
- `zen-shell-v5/ThemeService.qml` — `sddmThemer` + triggers at 3 apply sites
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
