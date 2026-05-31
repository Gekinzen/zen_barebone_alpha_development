# v7.0.0-alpha.4-hf3 — Bar-facing corner flatten (fullwidth fix)

**Channel:** alpha (hotfix 3)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this hotfix fixes

### The "bottom spacing" in fullwidth mode wasn't a margin — it was the curved corners.

**Issue reported:** When the panel mode is `fullwidth`, the StartMenu
panel still appears to have spacing at the bottom even after hf2's
sticky-to-bar (1px overlap) change.

**Root cause:** Not a margin issue. The panel had `radius: 16` on
ALL FOUR corners, including the bottom-left + bottom-right corners
which sit AT the bar-facing edge. The 16px curve cuts into the
panel's bottom-left and bottom-right, producing a visible triangular
void where the curve meets the bar's flat top edge:

```
BEFORE (hf2 — all corners curved)
                                      curve cuts into the panel,
                                      bar's top edge is flat
       ┌───────────────────┐                  ↓
       │  panel...         │              ╭─────...
       │                   │              │      
       │                   │              │      
       └─╮               ╭─┘   ←  curved bottom corners
         │               │            
═════════╪═══════════════╪═════   ← bar edge meets the curve diagonally,
         │   bar...      │            visible empty wedge between them
═════════════════════════════
```

**Fix:** Per-corner radius. The corners on the **bar-facing side** are
flattened to `0` (square), the corners on the **away side** keep the
full `16` radius (rounded). Result: the bar-facing edge of the panel
is a straight line, perfectly flush with the bar's top edge — no
triangular cutout, no visual spacing.

```
AFTER (hf3 — bar-facing corners flat)
       ┌───────────────────┐
       │  panel...         │
       │                   │
       │                   │
       │                   │   ← square bar-facing corners
       └───────────────────┘
═════════════════════════════   ← perfectly continuous edge
         bar...
═════════════════════════════
```

The corner-flattening logic adapts to all four bar positions:

| Bar position | Panel corners flattened | Panel corners rounded |
|---|---|---|
| Bottom (`isBottom`) | bottom-left, bottom-right | top-left, top-right |
| Top (`isTop`) | top-left, top-right | bottom-left, bottom-right |
| Left (`isLeft`) | top-left, bottom-left | top-right, bottom-right |
| Right (`isRight`) | top-right, bottom-right | top-left, bottom-left |

### Internal padding asymmetric trim

Also reduced the panel's internal `anchors.margin` on the bar-facing
side from 16px → 8px. The away sides keep 16px for breathing room.

This eliminates the secondary "wasted space" effect — when the panel
is sticky-anchored to the bar, having 16px of empty padding right at
the seam created visual disconnect even after the corners were
flattened.

```
                 16px              16px
              ┌─top→┌─────────────┬────┐
              │     │             │    │
              │     │             │    │
              │     │             │    │   ← left/right/top: 16px
              │     │             │    │      bottom: 8px
        16px  ←left ←content      → right
              │     │             │    │
              │     │             │    │
              ↓bottom──────────────────┘
                       8px              ← bar-facing margin trimmed
═══════════════════════════════════
              bar...
═══════════════════════════════════
```

---

## Qt requirement

Per-corner radius (`topLeftRadius`, `topRightRadius`,
`bottomLeftRadius`, `bottomRightRadius`) requires **Qt 6.7+**.
Quickshell currently ships against Qt 6.7+ on Arch (which is what
your CachyOS install uses). On Qt 6.6 or older, these properties
are silently ignored and the panel falls back to all-corners-rounded
via the `radius: _cornerRadius` line — functional, just without the
visual flatten refinement.

---

## Files modified

```
zen-shell-v5/StartMenuPanel.qml   (4 per-corner radius bindings + per-side
                                   internal margins; ~12 lines added)
zen-shell-v5/ZenVersion.qml       (bumped to v7.0.0-alpha.4-hf3)
install.sh                        (version strings)
```

Only the StartMenuPanel layout file changed — no PanelState additions,
no shell.qml changes, no service touch.

---

## Wala tayong babawasan

- `radius: _cornerRadius` retained as the base value — the per-corner
  properties layer on top, so older Qt installs still get a
  functional (if all-rounded) panel.
- Bar position detection uses the existing `PanelState.isTop /
  isBottom / isLeft / isRight` readonly properties — no new state
  fields, no migrations.
- `_cornerRadius` is itself derived from
  `Theme.styleMode === "round" ? 22 : 16` — same conditional v6 used,
  so the round/square style preference still controls the rounded
  corners on the away side.
- All hf1 and hf2 fixes preserved: avatar OpacityMask, settings
  button, power popup, context menu, sticky 1px overlap, mode-aware
  border, dynamic grid, etc.

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.4-hf3-corner-flatten.tgz
cd zen-shell-v7.0.0-alpha.4
./install.sh
qs -r
```

Auto-snapshot before overwrite. Roll back via Settings → Updates →
Restore if anything misbehaves.
