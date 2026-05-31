# Zen Shell v7.0.0-beta.1-hf95.18 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Fix: the "invalid field type plugin:hyprbars:bar_height" config error
from hf95.17. The invalid windowrule is gone; quick-terminal bar
suppression now lives in HyprbarsService where it's safely gated on the
plugin being loaded. Backward-compatible with Hyprland 0.54/0.55.** Wala
tayong babawasan.

---

## Root cause

hf95.17 added `windowrule = plugin:hyprbars:bar_height 0` to the static
`hyprland-layer-rules.conf`. That field doesn't exist as a core
windowrule, and ANY `hyprbars:*` / `plugin:hyprbars:*` rule errors on
Hyprland 0.54/0.55 when the plugin isn't loaded ("invalid field type" /
"config option does not exist"). Since that file is always parsed,
Hyprland threw the error on every reload — even though your hyprbars
plugin is commented out.

This is exactly the trap HyprbarsService already documents (it gates all
`hyprbars:no_bar` rules behind a verified-loaded check for this reason).

## Fix

1. Removed the invalid windowrule from `hyprland-layer-rules.conf`. The
   quick terminal now uses only CORE windowrule fields (float, size,
   move, rounding, border_size, opacity, pin, suppress_event) — all valid
   on 0.54/0.55.
2. Moved quick-terminal bar suppression INTO `HyprbarsService`, emitted
   with the proven block syntax (`hyprbars:no_bar = true`,
   `match:class = ^(zen-quickterm)$`) and ONLY when `pluginLoaded` — so it
   can never cause a parse error when hyprbars is off, and correctly hides
   the bar when hyprbars is on.

A floating special-workspace pop-up also gets no bar by default, so with
the plugin off there's nothing to suppress anyway.

## Version

- `ZenVersion.qml` bumped `hf95.17` → `hf95.18`.

## Files touched

- `hypr-config/hyprland-layer-rules.conf` — removed invalid plugin windowrule
- `zen-shell-v5/HyprbarsService.qml` — quick-term no_bar, gated on pluginLoaded
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
