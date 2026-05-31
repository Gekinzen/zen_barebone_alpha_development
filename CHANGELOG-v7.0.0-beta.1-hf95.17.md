# Zen Shell v7.0.0-beta.1-hf95.17 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Three fixes: the quick terminal now actually appears TOP-CENTER, it no
longer shows a hyprbars title bar, and the Settings / Control Center grows
a themed hyprbars-style title bar ("Zen-Shell-Hypr-Control-Center") when
hyprbars is enabled.** Wala tayong babawasan.

---

## 1. Quick terminal → really top-center

A window on a Hyprland special workspace is auto-centered and IGNORES a
`move` windowrule — which is why it kept landing dead-center despite the
rule. `zen-quickterm.sh` now repositions it explicitly after showing it,
computed against the FOCUSED monitor (multi-monitor + scale aware):
horizontally centered, ~40px from the top, via `movewindowpixel` /
`resizewindowpixel`.

## 2. No hyprbars on the quick terminal

Added `windowrule = plugin:hyprbars:bar_height 0, match:class
^(zen-quickterm)$` so the transient pop-up has no title bar wasting
vertical space.

## 3. Settings / Control Center title bar (when hyprbars is on)

The Settings window is a layer-shell surface, so the real hyprbars plugin
can't decorate it. The `HyprbarsMimic` (removed in hf64) is restored —
but ONLY when `HyprbarsService.enabled`:

- Title: **Zen-Shell-Hypr-Control-Center**.
- Colours + button side come from `HyprbarsService` (so it matches your
  theme and your left/right alignment choice automatically).
- Close → closes Settings; maximize → toggles fullscreen.
- Content top-margin clears the bar height when shown.
- When hyprbars is OFF, the bar stays hidden and the native header shows
  exactly as before — nothing changes for non-hyprbars users.

## Version

- `ZenVersion.qml` bumped `hf95.16` → `hf95.17`.

## Files touched

- `scripts/zen-quickterm.sh` — explicit top-center reposition (monitor/scale aware)
- `hypr-config/hyprland-layer-rules.conf` — disable hyprbars on quick terminal
- `zen-shell-v5/ZenSettings.qml` — themed HyprbarsMimic title bar, gated on hyprbars
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
