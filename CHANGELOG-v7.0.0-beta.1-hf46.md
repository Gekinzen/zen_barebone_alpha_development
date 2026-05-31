# v7.0.0-beta.1-hf46 — Sticky note draggable toggle

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix adds

User request:

> "sa sticky note ko dapat draggable din kasi naka stucked lang siya
> lage sa center so may toggle siya prang on screen widget siya or
> not. dun na mismo sa sticky note natin may toggle dun and please
> yun design same sa current rounded. kapag activate natin yun
> draggable din siya tas same katulad dun sa mga clock ko weather
> and cpu temp gets?"

Sticky notes were anchored to a hash-derived position with no way
to move them. This hotfix adds an in-sticky toggle that switches
the note between "anchored" and "widget" modes — when widget mode
is on, the user can drag the sticky anywhere on the screen, exactly
like the clock/weather/CPU temp desktop widgets in `DesktopWidgets.qml`.

---

## What you see

Per-sticky title bar layout (in order, left → right):

```
┌──────────────────────────────────────────────┐
│ ⭐  Title text ………………  [ ●━━━━ ]  ✕         │  ← title bar
├──────────────────────────────────────────────┤
│                                              │
│  (your note content)                         │
│                                              │
├──────────────────────────────────────────────┤
│ 42 chars                    ⤧ drag mode      │  ← footer indicator
└──────────────────────────────────────────────┘
```

- **⭐** — un-stick (closes the sticky window, note stays in library)
- **Title** — the note's first line, ellided if too long
- **Pill toggle** — drag mode on/off (the new bit)
- **✕** — same as ⭐, un-sticks the note

Pill toggle design:
- **OFF** (default): neutral grey fill, thumb on the left
- **ON**: green fill, thumb slid to the right
- 32×16 px with 12×12 thumb (compact size to fit the small sticky
  header without dominating)
- Same rounded design and 150ms OutCubic slide animation as the
  Bluetooth/WiFi/Audio toggles in Control Panel

Footer drag-mode indicator (only visible when ON):
- "⤧ drag mode" tag in green italic — tells you at a glance which
  stickies are in widget mode

---

## How dragging works

When the pill is ON:
- **Hover the title bar** → cursor becomes OpenHand 🖐
- **Click + drag the title bar** → cursor becomes ClosedHand ✊,
  sticky follows your mouse anywhere on the screen
- **Release** → new position is persisted to
  `~/.config/quickshell/zen-shell/quick-notes.json` (debounced 400ms)
- **Buttons stay clickable** during drag mode — the drag MouseArea
  sits at `z: -1` behind the star / pill / close button rectangles,
  so clicks on those still register first

Position clamping: drag is bounded to the screen so you can't drop
the sticky off-edge:
```qml
drag.minimumX: 0
drag.minimumY: 0
drag.maximumX: stickyWindow.width - card.width
drag.maximumY: stickyWindow.height - card.height
```

When the pill is OFF:
- Title bar is just a label, no cursor change, no drag behavior
- Sticky locked to its saved position (or hash-derived fallback if
  never moved)
- You can still click ⭐ / ✕ / the pill itself

---

## Implementation — drag pattern from DesktopWidgets.qml

Mirrors the clock/weather/CPU temp widgets exactly:

### Position is imperative, not bound

```qml
// In Component.onCompleted:
const saved = QuickNotesService.getStickyPosition(noteId)
if (saved) {
    card.x = saved.x
    card.y = saved.y
} else {
    card.x = _fallbackX()
    card.y = _fallbackY()
}
```

NOT this (would fight drag.target):
```qml
// BAD:
x: QuickNotesService.getStickyPosition(noteId)?.x || _fallbackX()
```

Imperative writes mean drag.target can take ownership during a drag
gesture without binding loop warnings. Same v6.11e fix from
DesktopWidgets.

### Drag-active guard on re-apply

```qml
Connections {
    target: QuickNotesService
    function onStickyPositionsChanged() {
        if (dragArea.drag.active) return   // skip mid-drag
        const saved = QuickNotesService.getStickyPosition(noteId)
        if (saved) { card.x = saved.x; card.y = saved.y }
    }
}
```

Without this guard, if any OTHER sticky's position changed during
your drag, the `stickyPositions` map reassignment would trigger
this Connections, which would forcibly reset your card.x/y mid-
drag — same exact bug DesktopWidgets v6.16.1.9 fixed with its
`_anyDragActive` readonly guard.

### preventStealing on the drag MouseArea

```qml
MouseArea {
    id: dragArea
    z: -1   // BEHIND the title bar buttons
    preventStealing: true   // hold the gesture
    drag.target: stickyWindow.isDraggable ? card : null
    ...
}
```

`preventStealing: true` ensures the gesture stays with this
MouseArea even if a parent layer tries to grab it. Critical for
Hyprland's layer-shell where focus can shuffle during fast drags.

`drag.target: null` when toggle is OFF kills the drag binding
entirely — no accidental movement when the user just wants to
click into the editor.

### Position persistence

```qml
onReleased: {
    if (stickyWindow.isDraggable) {
        QuickNotesService.setStickyPosition(noteId, card.x, card.y)
    }
}
```

Fires once on release. `setStickyPosition` reassigns the whole
`stickyPositions` map (not in-place mutation) so QML's property
change detection fires correctly and the debounced save triggers.

---

## QuickNotesService API additions

```qml
property var stickyPositions: ({})      // { noteId: {x, y} }
property var stickyDraggable: ({})      // { noteId: bool }

function setStickyPosition(id, x, y)
function getStickyPosition(id)          // returns {x, y} or null
function setStickyDraggable(id, value)
function isStickyDraggable(id)          // returns bool (default false)
```

Both maps are persisted to `quick-notes.json` along with the
existing `stickyIds` / `pinnedIds` / `currentNoteId`. Default is
empty `{}` — backward-compatible with hf45 saves (which had
neither).

---

## Files changed (3)

```
zen-shell-v5/QuickNotesService.qml   — added stickyPositions +
                                         stickyDraggable maps + API
                                         + persistence hooks
zen-shell-v5/QuickNotesSticky.qml    — full rewrite with drag pattern
                                         + pill toggle in title bar
                                         + footer drag-mode indicator
zen-shell-v5/ZenVersion.qml          — bumped to hf46
install.sh                            — banner + changelog
```

No new files. Existing sticky stickies will still load — the
service's `stickyPositions` / `stickyDraggable` properties default
to empty, so old data passes through cleanly.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf46-sticky-draggable.tgz
cd zen-shell-v7.0.0-beta.1-hf46
./install.sh
```

Then `pkill quickshell` or relogin to pick up the new code.

---

## How to verify

1. `Super+Shift+N` → Quick Notes panel opens
2. Type a quick note, click the ⭐ button next to the ★ pin button
3. Sticky note appears at its hash-derived position
4. **Look at the title bar** — you'll see a small grey pill next
   to the title (between the title and the ✕ close button)
5. **Click the pill** → it flips to green
6. **Hover the title bar** → cursor becomes OpenHand
7. **Click + drag the title bar** → sticky follows your mouse
8. **Release** → sticky stays at the new position
9. Restart shell → sticky reappears at the dragged position
10. Click pill again → green flips back to grey, drag disabled

Try with multiple stickies — each one tracks its own draggable
state and position independently.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 custom theme profiles save full state
- ✅ hf43 Quick Notes panel clipping + rounded toggle pills
- ✅ hf42 modules visible + usage docs
- ✅ hf41 collapsible Settings search + Input tab sliders
- ✅ hf40 Quick Notes keybinds + sticky notes (base)
- ✅ hf39 5 productivity features

Pure additive — sticky note now does what desktop widgets do, with
the rounded toggle design you wanted. 🍃
