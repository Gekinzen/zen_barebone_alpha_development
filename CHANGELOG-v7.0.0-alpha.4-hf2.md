# v7.0.0-alpha.4-hf2 — StartMenu polish (avatar circle + border + sticky)

**Channel:** alpha (hotfix 2)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this hotfix fixes

Three issues in alpha.4-hf1, all reported in user testing:

### 1. Avatar still rendering as a square

**Issue:** Despite `radius: 16` + `clip: true` on the wrapper Rectangle,
the avatar image rendered as a square (filling the full bounding box
without circle clipping).

**Cause:** `clip: true` clips children to the parent's RECTANGULAR
bounds, not its rounded shape. The radius affects the parent's own
rendering only, not how children are clipped to it. This is a known
Qt Quick limitation across Qt 5/6 — not a Quickshell-specific issue.

**Fix:** Replaced with the canonical **OpacityMask** circular pattern,
identical to ZenSettings.qml sidebar avatar + UserProfilePage avatar.
Three components:

```
Image (id: avatarImg)        ← visible: false  — pixel source
Rectangle (id: avatarMask)   ← visible: false  — circular alpha shape
OpacityMask                  ← composites image through the circle mask
```

Required adding `import Qt5Compat.GraphicalEffects` at the top.
Pattern is GPU-accelerated and works on every Quickshell build that
ships GraphicalEffects (which is all of them since Qt 6.0).

The fallback letter glyph still shows when `Image.status !==
Image.Ready` or the source URL is empty.

### 2. StartMenu border feature (Off / Match Bar / Thick)

**Issue:** Panel border was hardcoded to a fixed alpha-rgba color +
1px width. No way to disable, no way to match the bar's actual
border for a unified look.

**Fix:** New `PanelState.startMenuBorderMode` property with three
modes, surfaced in **Settings → Bar Modules → Start Menu → Panel
border**:

| Mode | Width | Color |
|---|---|---|
| **Off** | 0 | transparent |
| **Match Bar** (default) | `PanelState.borderWidth` (1px default) | `PanelState.borderColor` if bar border on, else subtle ThemeService fallback |
| **Thick** | `2 × PanelState.borderWidth` (2px default) | same color sources as Match Bar |

When the bar's `borderEnabled` is on (e.g. you've turned on bar
borders in Settings → Panel), the panel uses the **literal same
color and width** so visually the two surfaces look continuous.
When bar border is off, panel falls back to the existing subtle
ThemeService outline so the panel is still visually defined.

### 3. Sticky-to-bar (continuous border)

**Issue:** A 2px gap (`barHeight + 2`) sat between the bar and the
StartMenu panel. The panel's border was floating in space above the
bar; the two never visually connected.

**Fix:** Changed to `barHeight - 1` — a 1px **OVERLAP** instead of a
gap. The panel's border now draws right on top of the bar's border
at the shared edge. Combined with **Match Bar** mode (same color +
width), the two borders merge into a single continuous visual line.

Result: bar + panel look like one unified surface, the way Win11's
taskbar+startmenu does. No more floating panel.

This applies in all four bar orientations (top, bottom, left, right
— the corresponding margin in shell.qml changed accordingly).

---

## Visual before / after

```
BEFORE (hf1)              AFTER (hf2 + Match Bar mode)

┌─────────────────┐       ┌─────────────────┐
│  StartMenu      │       │  StartMenu      │
│                 │       │                 │
└─────────────────┘       └─────────────────┤   ← borders merged
   ↕ 2px gap                                │
┌─────────────────┐       ┌─────────────────┤
│  Bar            │       │  Bar            │
└─────────────────┘       └─────────────────┘
                                            ↑
                                    one continuous line
```

---

## Files modified

```
zen-shell-v5/StartMenuPanel.qml   (avatar OpacityMask + mode-aware border)
zen-shell-v5/PanelState.qml       (+1 property: startMenuBorderMode + persistence)
zen-shell-v5/BarModulesPage.qml   (+1 row: Panel border combo)
zen-shell-v5/shell.qml            (margin barHeight+2 → barHeight-1, all 4 sides)
zen-shell-v5/ZenVersion.qml       (bumped to v7.0.0-alpha.4-hf2)
install.sh                        (version strings)
```

---

## Wala tayong babawasan

- `borderEnabled` / `borderWidth` / `borderColor` (existing bar
  properties from v6) untouched. They remain the source of truth for
  bar styling; the panel just READS them when `startMenuBorderMode`
  is "match-bar" or "thick".
- Default `startMenuBorderMode = "match-bar"` so existing installs
  get the new continuous-border look immediately on first run, but
  the user can flip to "off" or "thick" anytime.
- Avatar OpacityMask pattern is identical to what's in ZenSettings
  sidebar + UserProfilePage — so all three avatar surfaces now
  render the exact same way.
- Public panel signals (closeRequested, appLaunched,
  powerActionRequested) + property (uploadInProgress) preserved.
- All v7 alpha.1-3 features carry forward.

Roll back via Updates Panel snapshot or .bak-* directory if needed.
