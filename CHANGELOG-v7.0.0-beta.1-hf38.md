# v7.0.0-beta.1-hf38 — String colors literal in custom mode + annotation transparency

**Channel:** beta (hotfix)
**Released:** 2026-05-16
**Branch:** `dev`

---

## What this hotfix fixes

User report from hf37 testing:

> "color nung strings ko hindi actual yun color na lumalabas prang
> iba pre and yung pag capture ko ng screenshot kunwari nag sulat ako
> ng pen ang masasave nagkakaroon ng white background dapat
> transparent lage kht mag drawing ako kunwari may circle ako sa
> screen ko etc"

Two unrelated bugs traced down:

1. **String colors in custom mode don't match picked hex values** —
   user picked `#ff6464ff` (red) and `#81f16eff` (green) but the
   actual strings rendered with half the segments noticeably darker.
2. **Screenshot annotations save with white background** — pen
   drawings, circles, rectangles, etc. should sit on the captured
   screenshot transparently but instead the entire annotation area
   shows up as a white block in the saved/copied image.

Both fixed in this hotfix. Surgical, minimal, additive.

---

## #1 — String colors respect custom hex values exactly

### Root cause

`ZenStrings.qml` (audio mode strokeColor):

```qml
// Before hf38
strokeColor: {
    var mix = colorMix(root.color1, root.color2, idx / root.segments)
    return (idx % 2 === 0) ? Qt.darker(mix, 1.5) : mix
}
```

This applies `Qt.darker(mix, 1.5)` to every even-indexed string,
making them ~67% as bright as the picked color. The intent was to
add visual rhythm — alternating brightness reads as "depth" against
the wallpaper. Reasonable for theme-derived colors where the user
hasn't explicitly chosen a hex.

But when the user picks SPECIFIC hex colors in custom mode (e.g.
`#ff6464ff` red + `#81f16eff` green), they expect those EXACT
colors to render. Darkening half the strings produces something
visibly different from what's previewed in the Settings color
swatch.

### Fix

Skip the `Qt.darker` alternation when `colorMode === "custom"`:

```qml
// After hf38
strokeColor: {
    var mix = colorMix(root.color1, root.color2, idx / root.segments)
    if (ZenStringsState.colorMode === "custom") {
        return mix
    }
    return (idx % 2 === 0) ? Qt.darker(mix, 1.5) : mix
}
```

Now:
- **Custom mode** — strings render as a clean gradient from
  `customColor1` to `customColor2`, exactly as picked in the Settings
  swatches. Each segment is `colorMix(c1, c2, idx/segments)` — no
  darkening, no surprise.
- **Theme mode** — alternating Qt.darker preserved. Theme blue +
  purple still get the rhythmic variation that reads well against
  Modori/Hikari/etc. wallpapers.
- **Synced mode** — same alternating treatment. Theme integration
  is the point of synced mode, so visual rhythm is expected.

### Visual impact

Before hf38 with `#ff6464ff` + `#81f16eff`:
- Odd strings: clean red→green gradient (correct)
- Even strings: darker burgundy→olive (looks "off")

After hf38 with same colors:
- All strings: clean red→green gradient
- No alternation, fully literal

If you actually want the rhythm back, switch colorMode to "theme"
or "synced" in Settings — those modes intentionally apply it.

### Static mode unaffected

Static mode (no music playing) already used raw `root.color1` /
`root.color2` without darkening — no bug there, no change.

---

## #2 — Screenshot annotations are transparent again

### Root cause

The screenshot capture pipeline:

```
grim region → PNG (tmpRaw.png)
   ↓
QML annotation Canvas → SVG (tmpOverlay.svg via FileView)
   ↓
ImageMagick composite: raw + overlay → finalFile.png
   ↓
wl-copy / file save
```

The ImageMagick step was:

```bash
magick 'tmpRaw.png' \( 'tmpOverlay.svg' -background none \) \
    -compose over -composite 'finalFile.png'
```

**Problem:** in ImageMagick, flags apply to the NEXT image being
read. `-background none` placed AFTER the SVG path means the SVG
has already been rasterized using the DEFAULT background color
(white) by the time IM sees the flag.

Per official ImageMagick docs (discussion #7600):

> "The rasterized SVG is drawn over the current `-background`
>  setting, which is white by default."

And the official fix recommendation (#7596):

> "Use `-background transparent` (or `-background none` which means
>  the same) BEFORE reading the SVG."

So Paul's pen strokes, circles, rectangles, etc. WERE rendered
correctly in the SVG, but the SVG canvas itself was rasterized
onto a white background, which then composited over the raw
screenshot — producing a white block matching the selection area
with the annotations on top.

### Fix

Move `-background none` BEFORE the SVG path, plus add belt-and-
suspenders:

```bash
# After hf38
magick 'tmpRaw.png' \( -background none -density 96 \
    'tmpOverlay.svg' -alpha set \) \
    -compose over -composite 'finalFile.png'
```

Explanation of each addition:

- **`-background none` before SVG**: the actual fix. Tells IM to
  use transparent background when rasterizing the SVG that follows.
- **`-density 96`**: explicit DPI for the SVG rasterization. Some
  rsvg delegate versions otherwise pick a low default density
  causing fuzzy annotation lines on high-DPI displays.
- **`-alpha set` after SVG**: forces alpha channel enablement on
  the rasterized image. Catches edge case where rsvg delegate
  returns a 3-channel PNG instead of 4-channel — without `-alpha
  set` the composite step would treat all pixels as opaque.

Same fix applied to the `convert` fallback path (for systems with
ImageMagick 6 instead of 7).

### Additional belt-and-suspenders: explicit SVG root background

`buildAnnotationSvg()` now declares the SVG root as explicitly
transparent:

```javascript
// Before
var svg = '<svg xmlns="..." width="..." height="..." viewBox="...">'

// After
var svg = '<svg xmlns="..." width="..." height="..." viewBox="..." '
        + 'style="background-color:transparent">'
```

The SVG spec says canvas is transparent by default, but some
ancient librsvg delegate versions (pre-2.40) painted white
regardless. The explicit `style="background-color:transparent"`
removes all ambiguity — even if a downstream tool reads the SVG
later (e.g. for editing in Inkscape), the canvas stays transparent.

### Test it

After hf38:

1. Super+Shift+S → drag a selection
2. Pick pen tool, scribble a circle around something
3. Click Copy
4. Paste into a chat / Brave / image editor

You should see the original screenshot with your pen circle on
top — NOT a white block with a circle in it.

Same with all 7 annotation tools: pen, highlighter, rectangle,
circle, line, arrow, text.

---

## Files changed (3)

```
zen-shell-v5/ZenStrings.qml             — custom color skip Qt.darker
zen-shell-v5/ZenScreenshotOverlay.qml   — magick -background ORDER
                                          + SVG root style attr
zen-shell-v5/ZenVersion.qml             — bumped to hf38
install.sh                               — banner + changelog entry
```

Everything else from hf32, hf35, hf36, hf37 preserved unchanged.
Hot corners (hf37 event-driven rewrite), refresh rate toggle (hf36),
native toast pipeline (hf32), login sound integrity (hf32), all
still work.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf38-string-colors-and-annotation-transparency.tgz
cd zen-shell-v7.0.0-beta.1-hf38
./install.sh
```

State files forward-compatible. No schema changes.

---

## How to verify

### String colors

1. Settings → Appearance → ZenStrings → Color mode: **Custom**
2. Pick start color `#ff0000` (pure red)
3. Pick end color `#00ff00` (pure green)
4. Play any audio (Spotify, browser)
5. Look at the strings — they should be a clean red-to-green
   gradient. No alternating dark segments.

To verify the theme/synced rhythm is still working:
1. Switch Color mode to **Theme**
2. Strings should show the alternating brightness variation
   (intentional). Confirms hf38 only changed the custom mode
   behavior.

### Screenshot annotations

1. Super+Shift+S
2. Draw a selection rectangle anywhere on screen
3. Pick the **circle** tool from the annotation toolbar
4. Drag to draw a circle around something
5. Click **Copy**
6. Open Brave / Discord / any image editor and paste

You should see the original screenshot with your circle drawn on
top. NOT a white block with a circle in it.

Repeat with all 7 tools (pen, highlighter, rect, circle, line,
arrow, text) — all should now be transparent.

### Both fixes together

If you have music playing AND want to test the screenshot:
1. Custom colors visible on bar strings (literal red-green)
2. Super+Shift+S → annotate → copy → paste — transparent overlay

---

## Wala tayong babawasan

All previous fixes preserved. Each hotfix sa series is fully
additive on top of the last. Roadmap from here:

- hf36: refresh rate toggle ✅
- hf37: hot corners event-driven ✅
- **hf38: string colors + annotation transparency ✅** (you are here)
- next: feature additions from Paul's wishlist (Focus Spaces?
  Clipboard categorization? Quick Notes? Up to user)

🍃
