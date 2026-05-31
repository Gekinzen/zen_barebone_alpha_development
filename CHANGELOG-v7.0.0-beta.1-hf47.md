# v7.0.0-beta.1-hf47 — Sticky notes integrated as desktop widgets

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix adds

User request:

> "dapat draggable tas san yun toggle pre buo dapat sticky ma tag na
> din sa widget sa desktop ko mismo prang heto mga clock gets?
> draggable nadin tas yan super shift n daapt draggable din yan tas
> kapag toggle on niya widget modee automatically magiging katulad
> nung mga clock widget ko and please take note dapat maalala niya
> if san last position siya na setup nun dapat so kapag super shift n
> dapat mag vibrate yun notes if naka widget mode siya highlights
> isya gets? if toggle of normal"

Translation: sticky notes should integrate into the desktop widgets
system (clock, weather, CPU temp). When widget-mode toggle is ON,
the sticky becomes a true desktop widget — below regular windows,
draggable anywhere, position remembered. When toggle is OFF, it's
a normal anchored sticky overlay. Pressing `Super+Shift+N` should
shake/glow/bounce the widget-mode stickies so you can spot them.

Plus a "pop out" button in the Quick Notes panel so the user can
turn a note into a widget with one click from the editor.

---

## Architecture

Before hf47: ONE sticky implementation (QuickNotesSticky.qml). All
stickies lived on `WlrLayer.Overlay`. Drag worked but the surface
floated above everything — couldn't be a "real" desktop widget.

After hf47: TWO sticky implementations, mutually exclusive per
note ID.

```
                    QuickNotesService.stickyIds
                       │
              ┌────────┴────────┐
              │                 │
     toggle OFF                toggle ON
              │                 │
              ▼                 ▼
   QuickNotesSticky      DesktopStickyNotes
   (Overlay layer)       (Bottom layer)
   anchored               draggable
   floats above           below windows
   ALL windows            (like clock/weather/CPU)
```

The `visible` bindings on both gate on `isStickyDraggable(noteId)`:

```qml
// QuickNotesSticky (overlay)
visible: stickyIds.indexOf(noteId) >= 0
      && !isStickyDraggable(noteId)

// DesktopStickyNotes Repeater filter
widgetStickyIds: stickyIds.filter(id => isStickyDraggable(id))
```

So flipping the toggle pill is instantaneous — the overlay panel
hides, the widget appears (or vice versa). Same note ID, same
saved position, just rendered in a different parent surface.

---

## Files

### NEW — `DesktopStickyNotes.qml` (470 lines)

Sibling of `DesktopWidgets.qml`. Mounted by shell.qml in the SAME
per-screen `WlrLayer.Bottom` PanelWindow.

Key bits:

- **Repeater** over `widgetStickyIds` — one Loader per sticky in
  widget mode. When a sticky exits widget mode, the Loader unloads
  and reclaims memory.
- **Drag system** = exact copy of DesktopWidgets.qml v6.11e
  pattern:
  - Imperative x/y on card Rectangle (not bound)
  - `_anyDragActive` guard on parent dsn Item
  - `preventStealing: true` on the dragArea MouseArea
  - `z: -1` on dragArea so title-bar buttons capture clicks first
  - Position persisted on `onReleased`
- **Highlight animation** — connected to
  `QuickNotesService.highlightWidgetStickies()` signal. Plays shake
  (3 cycles, ±6px, 60ms each) + bounce (3 phases, 120ms each) +
  glow (2 loops green border pulse) simultaneously. Triggered by
  Super+Shift+N when at least one widget sticky exists.

### MODIFIED — `QuickNotesSticky.qml` (292 lines, was 412)

Stripped down to render ONLY normal-mode (toggle off) stickies.
The widget-mode logic was extracted to DesktopStickyNotes. The
toggle pill in the title bar is still here — clicking it flips
`setStickyDraggable(id, true)` which causes this instance to
hide and DesktopStickyNotes to render the widget.

Same look + same visible buttons (⭐ / title / pill / ✕) so the
user sees no visual difference at the moment of the toggle —
just a subtle re-layering.

### MODIFIED — `QuickNotesService.qml`

Two additions:

```qml
signal highlightWidgetStickies()
function pulseHighlight() { highlightWidgetStickies() }
function widgetStickyCount() {
    let n = 0
    for (const id of stickyIds) if (isStickyDraggable(id)) n++
    return n
}
```

The IPC handler uses `widgetStickyCount()` to skip the highlight
if no widget-mode stickies exist (no point shaking nothing).

### MODIFIED — `shell.qml`

- IPC `quicknotes_toggle` now fires `pulseHighlight()` when
  `widgetStickyCount() > 0`, before flipping panel visibility.
- DesktopStickyNotes mounted alongside DesktopWidgets in the
  per-screen Bottom-layer PanelWindow.

### MODIFIED — `QuickNotesPanel.qml`

New "Pop out as widget" button (⤧ icon) in the editor header,
between the existing ⭐ sticky toggle and ★ pin button.

One click:
- If note is NOT yet sticky → makes it sticky
- THEN enables widget mode → note appears as desktop widget
- Button turns green when widget mode is active
- Click again to disable widget mode (back to overlay)

---

## How to use

### Make a note into a desktop widget

1. `Super+Shift+N` → open Quick Notes panel
2. Select a note (or create a new one)
3. Type your content
4. Click the **⤧ button** (third icon in the header, after ⭐ and ★)
5. Note immediately appears on your desktop as a yellow widget,
   alongside your clock/weather/CPU temp
6. Drag it anywhere — position auto-saves
7. Click the green pill toggle inside the widget to switch back
   to overlay mode

### Find your widget stickies fast

If you have multiple widget stickies and they're hard to spot
among other windows:

1. Press `Super+Shift+N`
2. All widget-mode stickies will shake + glow green + bounce
3. They stay highlighted for ~1.4 seconds
4. Easy to spot, easy to grab

### Position memory

Drag your sticky to (300, 200) in widget mode. Toggle widget mode
off. Toggle widget mode on again. The widget reappears at
(300, 200) — position is shared between modes and survives shell
restart.

---

## Files changed (6)

```
zen-shell-v5/DesktopStickyNotes.qml   NEW (470 lines)
zen-shell-v5/QuickNotesService.qml    +highlightWidgetStickies signal,
                                       pulseHighlight(),
                                       widgetStickyCount()
zen-shell-v5/QuickNotesSticky.qml     rewrite — normal mode only
zen-shell-v5/QuickNotesPanel.qml      +Pop out button
zen-shell-v5/shell.qml                +DesktopStickyNotes mount,
                                       +pulseHighlight on Super+Shift+N
zen-shell-v5/ZenVersion.qml           bumped to hf47
install.sh                             banner + changelog
```

Total: 1 new file, 5 edits.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf47-sticky-as-widget.tgz
cd zen-shell-v7.0.0-beta.1-hf47
./install.sh
```

Then `pkill quickshell` or relogin so the per-screen PanelWindow
re-mounts with DesktopStickyNotes child.

---

## How to verify

### Toggle test

1. `Super+Shift+N` → panel opens
2. Click ⭐ on a note → overlay sticky appears
3. Hover the sticky's title bar — see the grey toggle pill
4. **Click the toggle** → green
5. Sticky moves from Overlay (top-of-everything) to Bottom
   (below regular windows). If you have a browser open over the
   sticky position, the sticky will go BEHIND the browser.
6. The drag handle in the title bar now works — drag the sticky
   to a new spot
7. Open Brave/your browser — sticky sits behind it like
   clock/weather/CPU temp widgets

### Super+Shift+N highlight test

1. Make at least one sticky in widget mode (drag pill = green)
2. Close the Quick Notes panel
3. Press `Super+Shift+N` once
4. All widget-mode stickies should:
   - Shake left-right (3 cycles)
   - Bounce down-up
   - Glow with green border (2 pulses)
5. Panel ALSO opens (the highlight runs alongside the normal toggle)

### Pop out button test

1. Open Quick Notes panel
2. Select any note
3. Click the **⤧ button** (third button in editor header)
4. Note immediately appears as widget on the desktop
5. Button turns green
6. Click ⤧ again → widget disappears, note becomes overlay sticky
   (button back to neutral)
7. Click ⭐ → un-sticky entirely (note stays in library)

### Position memory test

1. Make a sticky a widget, drag it to a specific spot
2. Restart shell (`pkill quickshell`)
3. Sticky reappears at the dragged position ✅
4. Click toggle → switches to overlay mode → appears at SAME
   position (just in a different layer)
5. Click toggle again → back to widget → still same position

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf46 sticky note draggable toggle (foundation for hf47)
- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 theme profiles save full state
- ✅ hf43 Quick Notes panel clipping + rounded toggle pills
- ✅ hf42 modules visible + usage docs
- ✅ hf41 collapsible Settings search + Input tab sliders
- ✅ hf40 Quick Notes keybinds + sticky notes
- ✅ hf39 5 productivity features

DesktopWidgets.qml itself is **NOT modified** — DesktopStickyNotes
is a sibling, not a child. So all your existing widget positions
(clock, weather, CPU temp) are completely safe. 🍃
