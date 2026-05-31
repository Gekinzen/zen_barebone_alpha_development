# Zen Shell v7.0.0-beta.1-hf93 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical: clock 2-row fix + SysRow / tray / music vertical modes.**
Additive, explicit `vertical` flags default false, guarded so a stale
module never bricks the shell. Wala tayong babawasan.

---

## 1. Clock — proper 2-row vertical readout

The vertical clock read as four stacked numbers ("09 28 05 30"). Now
it's a clean 2-block stack: **time** (hour with no leading zero over
minutes — e.g. 9 / 29), a divider, then a small **date** (MM / DD).

- **`Clock.qml`** — vertical column rewritten; horizontal clock
  untouched.

## 2. SysRow — vertical (icons stack, arrow points up/down)

- **`SysRow.qml`**
  - Explicit `vertical` flag. Vertical → root swaps W/H (thin column that
    grows downward as it expands); horizontal → original exactly.
  - `mainRow` converted from `RowLayout` to a `GridLayout` that flips:
    1 column when vertical (icons stack one-by-one), `columns: 999` when
    horizontal (all on one row = original behavior). All children carry
    `Layout.*` / implicit sizes that GridLayout honors.
  - Expand **arrow** is now ▼ (expand) / ▲ (collapse) in vertical; the
    configured left/right arrows stay in horizontal.
- **`SysRowIcon.qml`** — height capped to `Theme.moduleHeight`. In
  horizontal that's a no-op (`parent.height` already == moduleHeight); in
  a vertical column it stops each icon from ballooning to the full column
  height.

## 3. System tray — vertical (icons stack)

- **`SystemTray.qml`** — explicit `vertical` flag; `RowLayout` →
  flipping `GridLayout`; sizes to bar thickness when vertical.

## 4. Music widget — vertical (compact glyph)

- **`MusicWidget.qml`** — explicit `vertical` flag. Vertical shows just
  the play/pause glyph (the full track text can't fit a thin bar); the
  music strings carry the visual. Horizontal pill unchanged.

All four are wired in **`BarVertical.qml`** via the guarded
`Component.onCompleted` setter (boot-safe even if a module file is
stale).

---

## Vertical music STRINGS — next, separate drop

You asked for the audio-reactive strings to work vertically when
enabled. That's the highest-risk piece (the `MusicStrings` Canvas draws
horizontal bezier curves; vertical needs the curve math AND the overlay
window re-anchored along the side edge). To avoid repeating the
"big-change-rides-along-and-regresses" mistake, it gets its OWN focused
drop next. For now the strings overlay stays suppressed on a vertical bar
(`visible: … && isHorizontal`), and the vertical MusicWidget glyph stands
in.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf93
Clock.qml        vertical 2-row time/date
SysRow.qml       vertical column + up/down arrow (GridLayout flip)
SysRowIcon.qml   height capped to moduleHeight (vertical-safe)
SystemTray.qml   vertical column (GridLayout flip)
MusicWidget.qml  vertical compact glyph
BarVertical.qml  sysrow + tray + music wired vertical (guarded)
```

Carries forward hf83–hf92.1. Horizontal bar remains the known-good
pre-hf90 version; every vertical change is opt-in via explicit flags.

---

## Next
Vertical music strings (own drop) → Window-title vertical → auto-hide /
slide-in → rounded corner decorators.
