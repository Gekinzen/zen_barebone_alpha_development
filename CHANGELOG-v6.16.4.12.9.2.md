# v6.16.4.12.9.2 — Modori (戻り) · hotfix 2

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.1 — Modori hotfix 1

## Summary

Pure additive content drop on top of .9.1: two new built-in
wallpapers (Modori Dark, Modori Light) and two new built-in
themes (also Modori Dark and Modori Light) designed to color-
harmonize with the wallpapers. No code logic changes.

## Wallpapers

Both wallpapers are 2560×1440 PNGs rendered procedurally with
PIL/Pillow stamping (not SVG — cairosvg can't render the noise
filters needed for proper paper grain). Composition is identical
across both variants:

- **Imperfect enso** (zen calligraphic circle) at center-right,
  open at the bottom-left. Drawn with multi-layer ink wash
  technique: a wide pale halo, a mid bleed layer, and a narrow
  dark core, each with independent brush-hair jitter and
  Gaussian blur. The brush stamps are circles (not line segments)
  so the stroke has no end-cap artifacts.
- **"Sho" calligraphic pressure curve** along the path: starts
  at 65% pressure, peaks at 100% from 5% → 30% of the stroke,
  gentle decline through 30% → 85%, then a 1.6-power lift-off
  taper for the final 15% (mimics the brush rising from the
  paper at the end of the stroke).
- **Persimmon dot** (`#e87554`) inside the enso, slightly
  off-center, with a soft outer glow. Marks the "home" being
  returned to.
- **Sho splatter** of small ink droplets near the open end (12-14
  random droplets per variant).
- **戻 kanji watermark** in the lower-right corner, very low
  opacity.
- **Star specks** scattered in the upper-left zone (dark variant
  only — atmospheric).

### Dark variant (`modori-dark.png`)
- Background: vertical gradient `#0a0d1a` → `#10162a` → `#1a1d35`
  → `#241f30` → `#2c2128` (deep night → twilight)
- Cool indigo radial glow upper-left for tonal balance
- Warm persimmon radial glow lower-right (the "horizon")
- Bone-white enso ink (`#e8e0d4`)
- Subtle grain noise (Gaussian, σ=5)

### Light variant (`modori-light.png`)
- Background: vertical gradient `#f5ede0` → `#f1e6d4` → `#ebe1d0`
  → `#efd8c2` → `#e8c8af` (warm cream washi)
- Cool indigo glow upper-left, warm persimmon glow lower-right
- Sumi ink enso (`#1a1410`)
- Paper fibers (1D scipy gaussian filter on noise) + grain for
  washi character

## Themes

Two new theme JSONs in `themes-builtin/`. Both share:

- The same persimmon `orange` (`#e87554` dark / `#c45a3e` light) —
  the canonical "home" color of the Modori palette.
- Sense of dawn/dusk indigo for `blue` (`#7a8cc4` / `#4f6492`).
- Calm, low-saturation accents — no neon. The Modori aesthetic is
  "calm return to baseline," and the colors reflect that.

### `modori-dark.json`
Background: deep midnight indigos, identical to the wallpaper's
upper gradient stops. Foreground: bone-white. Greys lean cool
(slightly purple-tinted).

### `modori-light.json`
Background: washi cream tones, identical to the wallpaper's upper
gradient. Foreground: sumi-ink near-black. Greys lean warm.

## Files added

| File | Purpose |
|---|---|
| `themes-builtin/modori-dark.json` | NEW — Modori Dark theme |
| `themes-builtin/modori-light.json` | NEW — Modori Light theme |
| `wallpapers-builtin/modori-dark.png` | NEW — Modori Dark wallpaper (2560×1440, ~5MB) |
| `wallpapers-builtin/modori-light.png` | NEW — Modori Light wallpaper (2560×1440, ~5MB) |
| `wallpapers-builtin/README.md` | NEW — context + regeneration instructions |

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.2. |
| `install.sh` | New "Built-in Modori wallpapers" install block right before the existing default-wallpaper download. Copies `modori-dark.png` and `modori-light.png` from `wallpapers-builtin/` into `~/.config/zen-shell/wallpapers/`. Existing files preserved (never clobbered on re-install). Banner version + success banner + final "Done. Enjoy" message bumped consistently. |
| `CHANGELOG-v6.16.4.12.9.2.md` | NEW (this file). |

## Switching to Modori themes/wallpapers

After `./install.sh`:

```bash
# Apply Modori Dark wallpaper
swww img ~/.config/zen-shell/wallpapers/modori-dark.png \
    --transition-type fade --transition-duration 0.6

# Apply Modori Dark theme — via the Settings panel:
#   Settings → Themes → Modori Dark
```

Or for Light:

```bash
swww img ~/.config/zen-shell/wallpapers/modori-light.png
# Settings → Themes → Modori Light
```

The themes and wallpapers are designed to be used together — same
persimmon accent ties them visually. Mixing (e.g. Dark theme on
Light wallpaper or vice-versa) works but loses the harmony.

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.2
./install.sh
```

No `pkill quickshell` needed — the additions are themes and
wallpapers, applied through the existing picker UIs without a
shell restart. Re-install is fully idempotent.

## Carry-forward from Modori .9.1

All Modori fixes preserved verbatim:

- Theme.layoutLoader stop reading stale `style` from
  bar-layout.json (settings persistence fix)
- `saveState()` debounced through 200ms Timer (slider-drag
  corruption fix)
- All Tachiagari .7.1 features

## Wala tayong babawasan

Pure additive content. Two new themes alongside the existing
catppuccin/everforest/etc. roster; two new wallpapers alongside
whatever the user already has. Existing user wallpapers and
existing user theme selection preserved (never overwritten on
re-install).
