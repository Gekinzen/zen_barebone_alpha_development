# v7.0.0-beta.1-hf50 — Click-through + close button + widget input/drag/live-sync

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report:

> "kapag naka super shift n dapat nakakapag click click padin ako sa
> background and may close button din siya and yung widget ko sticky
> nmake it sure kapag may update ako sa sticky note ko matic live din
> and pwd din ako maka type dun sa widget enabled and draggable kasi
> nung test ko hindi ko na ddrag and hindi ako nanakapag type"

Four distinct problems, all fixed:

1. **Quick Notes panel modal** — outside clicks swallowed; can't use apps below
2. **No close button** on the panel — only Super+Shift+N toggle to close
3. **Widget mode TextArea can't receive typing** — keyboard input dead
4. **Widget mode drag still broken even after hf49** — root cause was deeper than the z-order fix
5. **Live sync** between panel editor and widget editor not happening reliably

---

## Bug 1+2 — Quick Notes panel: click-through + close button

### Before

```qml
PanelWindow {
    id: quickNotesWindow
    // ...
    HyprlandFocusGrab {                          // ← auto-close on outside click
        active: quickNotesWindow.visible
        onCleared: PanelState.quickNotesVisible = false
    }
    QuickNotesPanel { ... }                      // no mask, no close button
}
```

Two issues from this setup:
- No `mask: Region` → the entire full-screen PanelWindow caught ALL clicks
  including ones intended for browser/IDE/etc behind it
- `HyprlandFocusGrab` auto-closed the panel as soon as any click landed
  outside, fighting the click-through goal

### After (ControlPanel pattern)

```qml
PanelWindow {
    id: quickNotesWindow
    // ...
    // mask: only the panel rect blocks clicks; outside falls through
    mask: Region { item: quickNotesPanelInstance }
    // NO HyprlandFocusGrab — panel stays open until X / Esc / Super+Shift+N
    QuickNotesPanel {
        id: quickNotesPanelInstance
        onCloseRequested: PanelState.quickNotesVisible = false
    }
}
```

Inside `QuickNotesPanel.qml`:

```qml
Item {
    id: panel
    signal closeRequested()
    Keys.onEscapePressed: panel.closeRequested()
    focus: visible

    Rectangle {
        id: dragHandle
        // 22px tall strip at top, full width
        // Contains: three dots (drag affordance) + ✕ close button
        MouseArea {
            id: dragMa
            anchors.rightMargin: 32   // reserve space for close button
            drag.target: panel
        }
        Rectangle {
            id: closeBtn
            // red ✕ button, hover highlights, click → closeRequested()
        }
    }
}
```

### Result

- Clicks on the desktop / Brave / VS Code / any app outside the panel
  rect now register on those apps ✅
- Panel stays open while you work elsewhere
- Close via: red ✕ in top-right of drag handle, Esc key, or
  Super+Shift+N toggle

---

## Bug 3 — Widget mode TextArea: can't type

### Root cause

The widgets-layer PanelWindow in `shell.qml` had:

```qml
PanelWindow {
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "zen-shell-widgets"
    // NO WlrLayershell.keyboardFocus declared
    DesktopWidgets { ... }       // clock / weather / CPU
    DesktopStickyNotes { ... }   // sticky widgets (hf47)
}
```

Without an explicit `keyboardFocus`, Quickshell defaults to **None**.
Compositor never routes keyboard events to this surface, no matter
what's clicked inside. Clock/weather/CPU widgets didn't care (they
have no text input) — but the hf47 sticky TextArea inside
DesktopStickyNotes silently couldn't receive any typing.

### Fix

```qml
WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
```

OnDemand semantics: the surface declares it CAN receive keyboard
focus, but only when an interactive child element actually claims it
(by being clicked / focused). TextArea click → focus request → keys
route through. Clock/weather widgets never request focus, so their
behavior is identical to before.

---

## Bug 4 — Widget mode drag broken (root cause was the Loader)

### Story so far

- **hf46:** introduced drag MouseArea with `z: -1` → silently broken
- **hf49:** moved drag MouseArea to be FIRST child of titleBar (no z) →
  thought I fixed it
- **User tested hf49: still broken**

### Actual root cause

Looking at the structure I had since hf47:

```qml
Repeater {
    model: dsn.widgetStickyIds

    Loader {                            // ← THIS WAS THE BUG
        active: true
        sourceComponent: stickyCardComponent
        property string noteId: modelData
        // NO anchors, NO width/height — Loader is 0×0
    }
}

Component {
    id: stickyCardComponent
    Rectangle {
        id: card
        width: 280; height: 220
        // ...
    }
}
```

The Loader had **no width or height set** (defaults to 0×0). Even
though the card Rectangle inside got its 280×220 dimensions and
rendered visually, mouse hit-testing in QML operates on the **Item's
bounding box** — and the Loader's bounding box is 0×0.

Result: **the card was visible but completely untouchable for mouse
events**. Clicks landed on the parent dsn Item (which has no MouseArea),
dragArea.drag.target had no input to operate on, drag never engaged.

Same exact phenomenon for clicking the toggle pill, close button,
TextArea — none of them registered clicks.

### Fix — drop the Loader entirely

```qml
Repeater {
    id: stickyRepeater
    model: dsn.widgetStickyIds
    delegate: stickyCardComponent       // ← direct Component delegate
}

Component {
    id: stickyCardComponent
    Rectangle {
        id: card
        readonly property string noteId: modelData || ""   // ← direct access
        width: 280; height: 220
        // ...
    }
}
```

Repeater's delegate Rectangle now has proper bounds (280×220) and
hit-testing works. Drag works, clicks on buttons work, TextArea
clicks register and (combined with the keyboardFocus fix above) can
receive typing.

---

## Bug 5 — Live sync without cursor-jump

### The QML TextArea binding trap

Naive approach:

```qml
TextArea {
    text: card.note.body || ""           // declarative binding
    onTextChanged: saveBody(text)        // sync to model
}
```

What goes wrong:
1. Initial load: `text` binds to `card.note.body` → reads model
2. User types "A" → `text` becomes "A" → BINDING BREAKS (Qt's
   intentional behavior — typing into a TextArea disconnects it from
   declarative bindings to prevent fighting between user input and
   model)
3. `onTextChanged` fires → `saveBody("A")` → model.body = "A"
4. **If we had two TextAreas bound the same way**: only one would
   update; the other would not see the change because its binding
   is already broken.
5. If we re-bind explicitly on note change, the cursor jumps to end
   on every keystroke (the binding re-fires).

### Fix — imperative sync with focus guard

```qml
TextArea {
    id: editor
    property bool _syncingFromService: false

    // Initial value set once
    Component.onCompleted: {
        _syncingFromService = true
        text = card.note.body || ""
        _syncingFromService = false
    }

    // External updates via Connections (not binding)
    Connections {
        target: QuickNotesService
        function onNotesChanged() {
            const newBody = card.note.body || ""
            if (newBody === editor.text) return         // no-op
            if (editor.activeFocus) return              // user typing here — skip
            editor._syncingFromService = true
            editor.text = newBody
            editor._syncingFromService = false
        }
    }

    // Save on user input only — not on our own sync writes
    onTextChanged: {
        if (_syncingFromService) return
        if (text !== card.note.body) saveBody(text)
    }
}
```

Result:
- Type in panel editor → widget editor reflects live ✅
- Type in widget editor → panel editor reflects live ✅
- Neither side gets cursor-jumped when the other is typing
- Bind loops impossible (the guard flag suppresses sync-triggered
  saves)

Applied to both `QuickNotesPanel.qml` editor AND each
`DesktopStickyNotes` card's editor.

---

## Files changed (4)

```
zen-shell-v5/QuickNotesPanel.qml      — close button + Esc handler,
                                          imperative editor sync
zen-shell-v5/DesktopStickyNotes.qml   — Repeater delegate (no Loader),
                                          imperative editor sync
zen-shell-v5/shell.qml                — mask:Region, removed
                                          HyprlandFocusGrab,
                                          WlrLayershell.keyboardFocus:
                                          OnDemand on widget surface
zen-shell-v5/ZenVersion.qml           — bumped to hf50
install.sh                             — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf50-clickthrough-close-input-sync.tgz
cd zen-shell-v7.0.0-beta.1-hf50
./install.sh
```

`pkill quickshell` to reload (the per-screen widget PanelWindow has
to be re-instantiated to pick up the new keyboardFocus setting).

---

## How to verify

### Click-through
1. `Super+Shift+N` → Quick Notes panel opens
2. Try clicking on an app behind it (Brave, terminal, etc.)
3. App should focus normally; panel stays open ✅

### Close button + Esc
1. Open Quick Notes panel
2. Hover top-right of drag handle → ✕ button turns red
3. Click ✕ → panel closes
4. Re-open via Super+Shift+N
5. Press Esc → panel closes

### Widget drag (the real fix)
1. Open a note, click ⤧ "pop out as widget" button
2. Widget appears on desktop
3. Hover the title bar → cursor becomes OpenHand 🖐
4. Click + drag the title bar → widget follows ✅
5. Release → widget stays at new position
6. Restart shell → widget reappears at dragged position

### Widget typing
1. Click inside the widget's text area
2. TextArea receives keyboard focus
3. Type characters → they appear ✅
4. Open Quick Notes panel — same note's editor reflects what you
   typed in the widget ✅

### Live sync (bidirectional)
1. Make a note a widget (toggle pill green)
2. Open Quick Notes panel — same note selected
3. Type in panel editor → widget editor updates live ✅
4. Type in widget editor → panel editor updates live ✅
5. Cursor position preserved on both sides during cross-update

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf49 sticky drag pattern + Quick Notes panel draggable (the
       drag pattern from hf49 was correct, but the Loader was eating
       all the hits — both pieces together now make drag actually work)
- ✅ hf48 hyprlock unlock focus reset workaround
- ✅ hf47 sticky notes as desktop widgets (now actually functional)
- ✅ hf46 sticky note draggable toggle (foundation)
- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 theme profiles save full state
- ✅ hf43 Quick Notes panel clipping + rounded toggle pills

Four distinct user-reported failures, four distinct root causes,
all addressed. 🍃
