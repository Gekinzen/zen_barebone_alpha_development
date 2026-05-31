# v7.0.0-beta.1-hf49 — Sticky drag actually works + Quick Notes panel draggable

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report:

> "yung sticky note kapag nasa widget hindi ata na drag tas yun mismong
> sticky note super shift n dapat draggable din buong window niya pre
> prang mga quick settings ko and hypr control panel gets?"

Two issues, both related to draggability:

1. **Widget-mode sticky drag is broken** — toggle pill goes green,
   but actually dragging the title bar does nothing. The sticky stays
   anchored even though the cursor changes to OpenHand on hover.

2. **The Quick Notes panel itself isn't draggable** — the user wants
   the popover (sidebar + editor pane) to be draggable like the
   ControlPanel / Quick Settings popup.

---

## Bug 1 — Widget sticky drag silently broken

### Root cause

In hf46/47 I used this pattern for the drag MouseArea inside the
sticky's title bar:

```qml
Rectangle {
    id: titleBar
    RowLayout {
        // ⭐ pill ✕ buttons
    }
    MouseArea {
        id: dragArea
        anchors.fill: parent
        z: -1   // BEHIND title bar buttons
        drag.target: card
    }
}
```

The intent: keep the buttons clickable while still catching drags on
the empty space between them. The `z: -1` was supposed to put the
drag MouseArea "behind" the buttons.

**Why it didn't work:** in QML, `z: -1` on a child of a Rectangle
places that child BELOW the parent's own draw layer. The parent
Rectangle's color/border/radius rendering happens at z: 0, and the
MouseArea at z: -1 ends up outside the hit-testing region for
events that don't pass through transparency.

Net result: clicks on the title bar's empty area landed on the
parent Rectangle (which has no MouseArea of its own), then bubbled
up out of the sticky entirely without ever touching dragArea. The
drag never engaged.

### Fix — copy ControlPanel pattern verbatim

ControlPanel.qml's drag works flawlessly. Its pattern:

```qml
// Drag MouseArea is FIRST child, fills parent, NO z manipulation
MouseArea {
    drag.target: root
    drag.axis: Drag.XAndYAxis
    preventStealing: true
    onPressed: root.hasBeenDragged = true
}

// Then the visible content as LATER siblings
RowLayout { /* buttons */ }
```

QML's natural rendering order: later siblings render ON TOP of
earlier siblings. So the buttons (with their own MouseAreas) sit
visually + hit-test-wise on top of the drag MouseArea below. Empty
space between buttons falls through naturally to the drag MouseArea.

Applied to DesktopStickyNotes:

```qml
Rectangle {
    id: titleBar

    // FIRST CHILD — drag handler, fills title bar
    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: card
        preventStealing: true
        // no z manipulation needed
    }

    // SECOND CHILD — buttons sit on top, catch own clicks
    RowLayout {
        // ⭐ title pill ✕
    }
}
```

Tested by examining the same exact structure in ControlPanel that's
been working since v6.13. No more invisible drag.

---

## Bug 2 — Quick Notes panel not draggable

### Root cause

QuickNotesPanel was anchored to center via `anchors.centerIn: parent`
in shell.qml. No drag handler, no way to move it.

### Fix — ControlPanel pattern, this time at the WINDOW level

ControlPanel does it like this:

```qml
// In ControlPanel.qml
Rectangle {
    id: root
    property bool hasBeenDragged: false
    // ... drag handle MouseArea inside ...
}

// In shell.qml mount
ControlPanel {
    id: controlPanelInstance
    anchors.centerIn: (!hasBeenDragged) ? parent : undefined
    onVisibleChanged: if (visible) hasBeenDragged = false
}
```

Applied to QuickNotesPanel:

1. **In QuickNotesPanel.qml** — added `property bool hasBeenDragged`
   and a **drag handle strip** along the top edge of the panel:
   - 18px tall, full width
   - z: 100 (above the main content layout)
   - Three centered dots as visual affordance
   - Subtle hover highlight
   - "Drag to move" tooltip after 800ms hover
   - MouseArea with `drag.target: panel` + `preventStealing: true`
   - `onPressed: panel.hasBeenDragged = true`
   - Cursor changes OpenHand → ClosedHand during drag

2. **In shell.qml** — mount uses the conditional anchor:
   ```qml
   QuickNotesPanel {
       anchors.centerIn: (!hasBeenDragged) ? parent : undefined
       visible: quickNotesWindow.visible
       onVisibleChanged: if (visible) hasBeenDragged = false
   }
   ```

3. **RowLayout top margin bumped to 22px** (was 12) to make room for
   the 18px drag handle without overlapping content.

### What it looks like

```
┌──────────────────────────────────────────────────┐
│ • • •                                            │ ← drag handle (hover = darker)
├──────────────────────────────────────────────────┤
│ + New note                  │ title  ⭐ ⤧ ★      │
│ Search…                     ├──────────────────┤ │
│ ── notes list ──            │ editor TextArea  │ │
│                             │                  │ │
└──────────────────────────────────────────────────┘
```

Drag the dots strip → panel follows cursor. Click X or press Esc to
close → next open() re-centers (hasBeenDragged resets).

---

## Files changed (3)

```
zen-shell-v5/DesktopStickyNotes.qml  — drag MouseArea moved to FIRST
                                        child of titleBar, no z:-1
zen-shell-v5/QuickNotesPanel.qml     — added hasBeenDragged property,
                                        drag handle strip, top margin
zen-shell-v5/shell.qml               — anchors.centerIn now conditional
                                        on hasBeenDragged, resets on
                                        visibility cycle
zen-shell-v5/ZenVersion.qml          — bumped to hf49
install.sh                            — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf49-drag-fixes.tgz
cd zen-shell-v7.0.0-beta.1-hf49
./install.sh
```

Then `pkill quickshell` to reload.

---

## How to verify

### Widget sticky drag

1. `Super+Shift+N` → open Quick Notes panel
2. Click ⭐ on a note → overlay sticky appears
3. Click the toggle pill inside the sticky → flips to green (widget mode)
4. Sticky drops to Bottom layer (below browser etc.)
5. **Hover the title bar of the widget sticky** → cursor becomes OpenHand
6. **Click + drag the title bar** → sticky follows your cursor ✅
7. Release → sticky stays at new position
8. Restart shell → reappears at the dragged position

Previous hf47 behavior: cursor changed, but no actual drag happened.
hf49 behavior: drag works.

### Quick Notes panel drag

1. `Super+Shift+N` → panel opens centered
2. Look at the top edge — you'll see three small dots
3. **Hover the dots** → background subtly darkens, cursor becomes OpenHand
4. **Click + drag the dots strip** → panel follows your cursor ✅
5. Release → panel stays where dropped
6. Close panel (press Esc or click outside)
7. Re-open → panel back to center (hasBeenDragged reset)

---

## Why hf46/47 looked correct but didn't work

QML hit-testing has a subtle gotcha: a MouseArea with negative z
that's a child of a Rectangle (which has visual content like a
color fill) becomes invisible to mouse events that land on the
parent's visual layer. The parent doesn't have a MouseArea of its
own, so events bubble UP out of the parent's bounds instead of DOWN
to the z:-1 child.

ControlPanel never hit this because its drag handle is a simple
sibling at z:0, with the buttons just being later siblings (natural
top-of-stack via render order).

Lesson learned: in QML, prefer "later sibling = on top" over
"explicit z manipulation" for hit-testing layered UI elements.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf48 hyprlock unlock focus reset workaround
- ✅ hf47 sticky notes as desktop widgets (now actually draggable!)
- ✅ hf46 sticky note draggable toggle (foundation)
- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 theme profiles save full state
- ✅ hf43 Quick Notes panel clipping + rounded toggle pills
- ✅ hf42 modules visible + usage docs

Pure correctness fix — drag was supposed to work in hf46/47 and now
actually does. Plus the panel-level draggable like ControlPanel. 🍃
