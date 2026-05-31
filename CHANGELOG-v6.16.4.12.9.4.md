# v6.16.4.12.9.4 — Modori (戻り) · hotfix 4

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.3 — Modori hotfix 3

## Summary

Substantial drop on top of .9.3, focused on long-term theme
quality:

1. **Smart-contrast theme engine** — `ThemeService.qml` runs
   every loaded theme through a WCAG luminance check and
   auto-adjusts foreground tones (`fg`, `grey0`, `grey1`,
   `grey2`) to meet readable contrast ratios against `bg0`.
   Themes that already have good contrast pass through
   unchanged. The fix protects custom user themes and Matugen-
   generated themes equally well.

2. **Default wallpaper switched to Modori Dark** — fresh
   installs now apply `modori-wallpaper-dark.png` automatically
   via swww if no existing user wallpaper is detected. Fetched
   from `Gekinzen/images-demo` if curl is available; offline
   installs fall back to the bundled copy in
   `wallpapers-builtin/`.

3. **Comprehensive README rewrite** — the README hadn't been
   updated since Tachiagari .7 (it still claimed Tachiagari
   was the current release). Now reflects the full Modori line
   including the Tategaki rollback, smart-contrast engine, and
   a forward-looking alpha roadmap section. Old historical
   sections (Hiraki, Hikari, Tsubasa, Kintsugi, Koke) are
   preserved verbatim — wala tayong babawasan.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.4. |
| `zen-shell-v5/ThemeService.qml` | New `_autoContrast()` pass run as part of `applyJson()`. New helpers: `_hexToRgb`, `_rgbToHex`, `_luminance` (WCAG relative-luminance formula on linearized sRGB), `_contrastRatio`, `_lerpRgb`, `_ensureContrast` (binary search for the smallest lerp that meets a target ratio). Targets: 4.5:1 for `fg`/`grey0`, 3.5:1 for `grey1`, 2.5:1 for `grey2`. Accent colors deliberately not corrected. |
| `install.sh` | `ZEN_DEFAULT_WP_NAME` and `ZEN_DEFAULT_WP_URL` switched to `modori-wallpaper-dark.png` (from `Gekinzen/images-demo/main/wallpapers/`). Banner version + success banner + final "Done. Enjoy" message bumped. `appliedBy` stamp in `wallpaper-state.json` updated. |
| `README.md` | Top section rewritten: hero text, version banner, "What's new in Modori" feature table, codename history table (extended through Modori .9.4), a new "Smart contrast theme engine — how it works" section explaining the WCAG math, a "Modori built-in wallpapers + themes" section with showcase image links to `Gekinzen/images-demo/zen_6_16_4_12_9_3/`, and a comprehensive "Upcoming alpha roadmap" section describing the planned Tategaki redux (staged this time), wallpaper picker online browser, theme importer with smart-contrast preview, Matugen polish, plugin system v2, and beta channel preparation. Existing historical sections (Hiraki, Hikari, Tsubasa, Kintsugi, Koke, video demos, legacy archive) preserved verbatim. |
| `BETA-BLOCKERS.md` | NEW — tracking document for what needs to land before the alpha-to-beta promotion. |
| `CHANGELOG-v6.16.4.12.9.4.md` | NEW (this file). |

## Detail — smart-contrast theme engine

### The trap

Themes ship with hex colors picked by the designer against the
`bg0` they were working on. If a designer picks `grey0: #aaa` while
working on a dark theme (`bg0: #1a1b26`), it looks fine — contrast
~7:1, perfectly readable. But import the same `grey0` value into
a light theme (`bg0: #f5ede0`) and the contrast collapses to ~1.4:1.
Secondary text becomes effectively invisible. WCAG AA requires 4.5:1
for body text; below ~3:1, text is unreadable for most users.

### The fix

`_autoContrast()` runs as part of `applyJson()`. For each foreground
tone, it:

1. Computes luminance of both the tone and `bg0` using the WCAG
   relative-luminance formula on linearized sRGB.
2. Computes the current contrast ratio.
3. If the ratio meets the target, passes through unchanged.
4. Otherwise binary-searches the smallest lerp (toward black if
   `bg0` is light, toward white if dark) that brings the ratio up
   to target. Stops AT the threshold — doesn't overshoot.

### What gets corrected

| Tone | Used for | Target |
|---|---|---|
| `fg` | Body text, primary labels | 4.5:1 (WCAG AA) |
| `grey0` | Secondary text, subtitles | 4.5:1 |
| `grey1` | Tertiary text, placeholders | 3.5:1 (between AA-large and AA) |
| `grey2` | Borders, dividers, dim states | 2.5:1 (above pure decoration) |

### What does NOT get corrected

- All `bg*` tones (they ARE the anchor — modifying them defeats
  the purpose).
- All accent colors (`red`, `orange`, `yellow`, `green`, `aqua`,
  `blue`, `purple`). Those are decorative-fill not body-text. The
  hue is part of the theme's identity. Forcing them toward
  black/white would mute the theme's character — and they're
  rarely used as text-on-bg anyway.

### Edge cases handled

- Themes WITHOUT `bg0` skip the pass entirely (nothing to anchor
  against).
- Themes with already-good contrast pass through with zero
  modification — every tone stays at its designer-specified value.
- The binary search has a fixed iteration count (14), giving
  sub-pixel precision on the lerp parameter. Worst case it does
  ~14 contrast computations per tone = ~56 per theme load, which
  is microseconds.

### Custom themes

Users importing custom themes via Settings → Themes → Import get
the same correction pass automatically. There's no opt-out flag in
this drop — readability is non-negotiable for body text. If a
designer wants near-invisible secondary text for stylistic
reasons, they can use `bg2` or `bg3` slots instead (those pass
through unchanged).

A future drop may add `"smart_contrast": false` to skip the pass
for individual themes (tracked in BETA-BLOCKERS.md).

## Detail — default wallpaper switch

Previous default was `123824383_p0 (Edited) compressed.png` (a
community wallpaper from the same `Gekinzen/images-demo` repo).
Modori .9.4 switches to `modori-wallpaper-dark.png` — designed
specifically to color-harmonize with the Modori themes shipped in
.9.2.

The fetch path stays identical (same repo, same `raw.githubusercontent.com`
host); only the filename changes. Existing user wallpapers are NEVER
overwritten on re-install — the `_is_fresh_wallpaper` check still
gates the apply step.

Offline-install protection: the Modori wallpapers are bundled in
`wallpapers-builtin/` and copied to `~/.config/zen-shell/wallpapers/`
BEFORE the curl-fetch step (see "Built-in Modori wallpapers" block
in install.sh). So even if `curl` fails or isn't installed, the
local copy is already there and can be applied via swww manually.

## Detail — README

The README hadn't been touched since Tachiagari .7. Modori's full
arc — including the Tategaki vertical-bar attempt and rollback —
wasn't documented anywhere a casual visitor would see. That's now
fixed.

Specifically retained verbatim from earlier README:

- Tachiagari .7 detail section (still accurate for that release)
- Hiraki .52 / .53 detail sections
- Hikari .51 plugin system overhaul writeup
- Tsubasa .40 Hyprland plugins page section
- "What v6.16.4.12.6 Hikari · Frosted ships" — full feature list
- Kintsugi v6.16.4.12.5 / v6.16.4.11.2 sections
- Koke (legacy archive) section
- All video demo links

Added at the top:

- Hero image: `zen_6_16_4_12_9_3/hero_desktop.png`
- "What's new in Modori" feature table
- Extended codename history table (showing the failed Tategaki
  cycle openly — readers shouldn't have to guess what happened
  between .7.1 and .9)
- "Smart contrast theme engine — how it works" section
- "Modori built-in wallpapers + themes" section with showcase
  images
- "Upcoming alpha roadmap" section (Tategaki redux, wallpaper
  picker online browser, theme importer with smart-contrast
  preview, Matugen polish, plugin system v2, vertical bar
  Tategaki II, beta channel preparation)

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.4
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

If you have an existing wallpaper, it stays. If you don't (fresh
install), Modori Dark gets applied. Custom themes auto-migrate
through the smart-contrast pass on next theme load — no user
action needed.

## Carry-forward from Modori .9.3

All Modori fixes preserved:

- Theme.layoutLoader stop reading stale `style` from
  bar-layout.json (settings persistence)
- `saveState()` debounced through 200ms Timer (slider-drag
  corruption fix)
- Built-in Modori Dark / Modori Light wallpapers + themes
- Sidebar bottom user row (paul @cachyos-x8664)
- Left/Right panel position cards hidden + L/R-to-Bottom
  migration safety net
- All Tachiagari .7.1 features

## Wala tayong babawasan

Smart-contrast pass is purely additive — themes with already-good
contrast are byte-for-byte identical after the pass. The default
wallpaper switch is gated on fresh-install detection — users with
existing wallpapers see no change. README rewrite preserves every
historical section verbatim.
