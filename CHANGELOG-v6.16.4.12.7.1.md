# v6.16.4.12.7.1 — Tachiagari (立ち上がり) · hotfix 1

**Channel:** alpha
**Release date:** 2026-05-06
**Branch:** `alpha-v6.16.4.12.7.1`
**Predecessor:** v6.16.4.12.7 — Tachiagari

## Summary

Follow-up hotfix on the Tachiagari drop. User asked for left/right
panel-position support too — same logic as the top/bottom popup
adaptation, extended to all four cardinal directions.

This drop **does NOT yet rotate the bar to render vertically**. The
bar's RowLayout still draws horizontally regardless of position.
What this drop DOES is teach every popup, overlay window, and
positioning helper about left/right so that:

1. The vertical-bar rendering work (next drop) only has to touch
   Bar.qml + the bar modules. All popup/overlay code is already
   ready.
2. Users who pick Left or Right today get a clean experience: the
   horizontal bar still renders normally, but if they could place
   it conceptually vertical, popups would already grow rightward
   (Left bar) or leftward (Right bar).

A friendly notice in Settings → Panel → Panel Position explains the
partial-support state so users picking Left/Right know what to
expect.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.7.1, codename unchanged (still Tachiagari — this is hotfix 1 within the cycle). |
| `zen-shell-v5/PanelState.qml` | `panelPosition` now accepts `"left"` and `"right"` in addition to `"top"`/`"bottom"`. New readonly flags: `isBottom`, `isLeft`, `isRight`, `isVertical`, `isHorizontal`. `panelMarginBottom` / `panelMarginTop` clauses tightened to only fire on their exact position (was checking != opposite). `popupAnchorEdges` / `popupAnchorGravity` extended from binary ternary to 4-way switch returning Edges.Top (1) / Bottom (2) / Left (4) / Right (8) per position. Persistence loader accepts all 4 values. |
| `zen-shell-v5/SysRowIcon.qml` | Tooltip popup `anchor.edges` / `anchor.gravity` rebound to the new 4-way `PanelState.popupAnchorEdges` helper (was `PanelState.isTop ? Edges.Bottom : Edges.Top`). |
| `zen-shell-v5/Taskbar.qml` | Both popups (window-list, context menu) rebound to the 4-way helper. |
| `zen-shell-v5/MusicStrings.qml` | Tooltip popup rebound to the 4-way helper. |
| `zen-shell-v5/ZenClock.qml` | Both popups (peekPopup, calPopup) rebound to the 4-way helper. |
| `zen-shell-v5/CalendarButton.qml` | Manual `anchor.rect.x/y` rewritten to a full 4-direction layout. New `_popupW` / `_popupH` / `_gap` readonly properties so the math is in one place and matches the `implicitWidth` / `implicitHeight` declarations. Comment block walks through the geometry for each case. |
| `zen-shell-v5/shell.qml` | `calendarWindow` and `startMenuWindow` anchor logic extended from `bottom/top + left` to full 4-direction matrix. `stringsWindow.visible` now AND-gated on `PanelState.isHorizontal` (auto-hide MusicStrings on vertical bars — fundamentally horizontal overlay). |
| `zen-shell-v5/PanelPage.qml` | Panel Position picker extended from 2 cards to 4 cards. Each card has an orientation-aware mini-preview (horizontal bar mini for Top/Bottom, vertical bar mini for Left/Right). New yellow notice rectangle below the picker explaining the partial-support state when Left or Right is selected. Refactored from `parent.parent.parent.isSelected` walks to a clean `id: posCard` reference. |
| `install.sh` | Top banner + success banner version strings bumped. |
| `CHANGELOG-v6.16.4.12.7.1.md` | NEW (this file). |

## Detail — PanelState position flags

Pre-Tachiagari hotfix 1, only `isTop` was exposed:

```qml
readonly property bool isTop: panelPosition === "top"
```

Now:

```qml
readonly property bool isTop:        panelPosition === "top"
readonly property bool isBottom:     panelPosition === "bottom"
readonly property bool isLeft:       panelPosition === "left"
readonly property bool isRight:      panelPosition === "right"
readonly property bool isVertical:   isLeft || isRight
readonly property bool isHorizontal: isTop  || isBottom
```

Why all six instead of just the four cardinals: `isVertical` and
`isHorizontal` come up SO often in consumer code (deciding whether
to use horizontal-flow logic vs vertical-flow logic) that having
named accessors keeps every consumer one identifier short of the
ternary. Without these the calendar-window code, for example, would
read `(PanelState.isLeft || PanelState.isRight) ? ... : ...` in
five different places — five chances to forget to OR them properly
the next time we add a new position case.

`panelMarginBottom` and `panelMarginTop` were also tightened. They
used to gate on `if (panelPosition === "top") return 0` (i.e. only
zero out when at the OPPOSITE position). With four positions that's
ambiguous: `panelMarginBottom` should be 0 for top/left/right, not
just top. Fixed to `if (panelPosition !== "bottom") return 0` and
mirror for top.

## Detail — Popup edge helpers (4-way)

Pre-hotfix:

```qml
readonly property int popupAnchorEdges:    isTop ? 2 : 1
readonly property int popupAnchorGravity:  isTop ? 2 : 1
```

After:

```qml
readonly property int popupAnchorEdges: {
    if (isTop)    return 2   // Edges.Bottom
    if (isLeft)   return 8   // Edges.Right
    if (isRight)  return 4   // Edges.Left
    return 1                  // Edges.Top (default — bottom bar)
}
readonly property int popupAnchorGravity: { /* same */ }
```

Mapping intent (popup grows AWAY from the bar):

| Bar position | Popup attaches to module's | Popup grows |
|---|---|---|
| Bottom (default) | Top edge | Up |
| Top              | Bottom edge | Down |
| Left             | Right edge | Right |
| Right            | Left edge | Left |

Edges constants from Quickshell are a bitflag enum. We expose them
as `int` so consumers can `import Quickshell` and bind directly
without re-deriving:
- `Edges.Top    = 1`
- `Edges.Bottom = 2`
- `Edges.Left   = 4`
- `Edges.Right  = 8`

## Detail — calendarWindow 4-direction anchoring

Pre-hotfix, calendarWindow always anchored bottom (or top) + right.
That made the calendar pop up at the bottom-right corner regardless
of bar position — fine when the bar was at the bottom/top, but
visually wrong if the bar was at the left or right of the screen
(calendar would float away from the clock module that triggered it).

After hotfix:

| Bar | calendarWindow anchors | bar-side margin |
|---|---|---|
| bottom | bottom + right | margins.bottom = barHeight + 12 + panelMarginBottom |
| top    | top    + right | margins.top    = barHeight + 12 + panelMarginTop |
| left   | top    + left  | margins.left   = barHeight + 12 |
| right  | top    + right | margins.right  = barHeight + 12 |

Vertical bars anchor the calendar to the TOP of the perpendicular
edge, not centered on the clock — partly because the clock-tracking
math (`clockRightEdgeX`) is only meaningful on horizontal bars
(where the clock has a well-defined screen-X), and partly because
the calendar's natural reading direction grows DOWN, so anchoring
top gives the most predictable result on first open.

The clock-tracking margin code path is gated on `isHorizontal` so
it doesn't run (and doesn't fight vertical-bar margin logic) when
the bar is at left/right.

## Detail — startMenuWindow 4-direction anchoring

Same treatment. The start button is geometrically the leftmost
module on horizontal bars, but the topmost on vertical bars (we
plan to keep the start button at the top of the column when the
bar rotates next drop). So:

| Bar | Anchor edges |
|---|---|
| bottom / top | bottom-or-top + left, aligned to startButtonCenterX |
| left  | top + left  (open menu just RIGHT of the bar, at screen top) |
| right | top + right (open menu just LEFT  of the bar, at screen top) |

The `startButtonCenterX` clamping logic only applies on horizontal
bars (for verticals we don't yet have a Y-axis equivalent — that's
part of the vertical-bar drop). On verticals, the menu top-aligns
with a small 8px gap from the screen top, which is the cleanest
behaviour without that report.

## Detail — MusicStrings auto-hide

The music strings overlay is fundamentally a horizontal effect:
audio-reactive curves drawn left-to-right across the bar's width.
On a vertical bar there is no horizontal music slot to overlay,
so the visible binding gains an `&& PanelState.isHorizontal` clause:

```qml
visible: isBarMonitor
         && PanelState.isHorizontal
         && ZenStringsState.enabled
         && ZenStringsState.musicSlotLocalX >= 0
         && ZenStringsState.musicSlotLocalWidth > 10
```

The MusicWidget (icon + small label, the alternative when
ZenStringsState.enabled is false) still renders inside the bar via
the normal cMusic component path — so users on vertical bars still
get music status, just without the rope curves.

## Detail — Settings UI

Panel Position picker before:

```
[ Top ] [ Bottom ]
```

After:

```
[ Top ] [ Bottom ] [ Left ] [ Right ]
```

Each card has an orientation-aware mini-preview rectangle so users
can see at a glance which option is which without reading. Below
the cards, a yellow notice appears whenever Left or Right is
selected:

> ℹ Vertical bar layout (rotated bar with column-stacked modules)
> is coming in a follow-up drop. For now, selecting Left/Right
> applies the 4-direction popup logic — popups will grow rightward
> (Left bar) or leftward (Right bar) — but the bar itself still
> renders horizontally. MusicStrings auto-hides on vertical.

This is deliberately upfront so users picking Left/Right know what
state they're in. Without it, the partial-support behavior would
look like a bug.

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.7.1
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

Saved `panel-state.json` from any prior version loads cleanly. New
position values (`"left"`, `"right"`) only take effect when the user
explicitly selects them in Settings — no auto-migration risk.

## Carry-forward from Tachiagari .7

All Tachiagari behaviour preserved verbatim:

- Pill module shape (proper flat-top look)
- Settings sidebar user row (avatar + name + @hostname)
- Smart Gaming Detection toggle + watcher daemon
- Start Button border tint + width
- Top-bar popup adaptation
- Monitor fix v2 merged into install.sh

## Wala tayong babawasan

Every change layers on top of existing logic. The 4-way popup
helpers REPLACE the binary ternary, but the binary ternary's two
states (top, bottom) remain semantically identical — `popupAnchorEdges`
returns 2 for top and 1 for bottom, exactly as before. New Left
and Right cases are additive. No data migration. Old saved state
loads cleanly.
