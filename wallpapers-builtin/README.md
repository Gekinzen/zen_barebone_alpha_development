# Modori built-in wallpapers

Two paired wallpapers for the **Modori (戻り)** codename release of Zen
Shell. The codename means *"return / coming back / rollback"* — fitting
for a release that restored stability after the Tategaki vertical-bar
crash cycle.

## Files

| File                | Variant | Pairs with theme   |
|---------------------|---------|--------------------|
| `modori-dark.png`   | Dark    | `modori-dark.json` (under `themes-builtin/`) |
| `modori-light.png`  | Light   | `modori-light.json` |

## Composition

Both wallpapers share the same composition: an **imperfect enso (zen
circle)** opens at the bottom-left, with a small **persimmon dot**
inside marking the "home" being returned to. The dark variant places
this against a deep night-into-dawn gradient with subtle stars; the
light variant uses warm washi paper texture with sumi-ink black for
the enso. The persimmon accent (`#e87554`) is identical in both —
giving them a sense of being the same scene at different times of
day.

A faint **戻** kanji watermark sits in the lower-right corner on both.

## Installation

`install.sh` copies these into `~/.config/zen-shell/wallpapers/` on
every install (existing files are preserved — never clobbered). After
install, switch to one of them via:

- The Wallpaper picker in the Settings → Wallpapers page, or
- Directly via swww: `swww img ~/.config/zen-shell/wallpapers/modori-dark.png`

## Regenerating

These PNGs are rendered procedurally by `render_wallpapers.py` (in the
release source tree, not shipped in the tarball). To re-render with
modifications:

```bash
pip install pillow numpy scipy --break-system-packages
python3 render_wallpapers.py
```

The script uses PIL stamping (not SVG) to draw the enso with proper
calligraphic pressure curves, multi-layer ink wash, and brush-hair
jitter.

## Resolution

Both PNGs are **2560×1440** (16:9). swww scales to fit any monitor
size without quality loss for typical resolutions (1080p, 1440p, 4K).
