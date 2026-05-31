# v7.0.0-beta.1-hf51 — Sticky editor focus-loss safety

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report:

> "okay sa desktop widget siyempre kapag hindi nako naka select dun
> dapat alisin mo na yun select dun kasi baka mag kamali unexpected
> typing sa notes gets"

When the user clicks away from a sticky widget (to switch to a browser,
terminal, etc.), the sticky's TextArea was keeping its selection
highlight AND potentially still treating itself as the focused item
internally. Risk: keystrokes intended for the new active app could
leak into the sticky note OR a stray click back near the sticky
could continue an interrupted text selection.

---

## Fix — auto-release on focus loss

Added `onActiveFocusChanged` handler to BOTH:
- DesktopStickyNotes (widget-mode sticky editor)
- QuickNotesPanel (main popover editor)

```qml
TextArea {
    id: stickyEditor
    selectByMouse: true
    property bool _syncingFromService: false   // existing from hf50

    onActiveFocusChanged: {
        if (_syncingFromService) return         // ignore sync writes
        if (!activeFocus) {
            deselect()       // clear text selection highlight
            focus = false    // release QML focus chain
        }
    }
    // ... rest of editor logic ...
}
```

What this does:
1. Watch when the TextArea stops being the active focus item
2. Skip if the change came from our own imperative sync (those don't
   count as real focus changes)
3. Otherwise: `deselect()` clears the visual selection highlight,
   and `focus = false` releases the QML focus chain so the surface
   is fully passive

### Why this matters for widget mode specifically

The widget-mode sticky lives on `WlrLayer.Bottom` with
`WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand` (added in
hf50). Without the focus-release on click-away, the compositor could
keep treating our Bottom-layer surface as the keyboard target even
after the user clicked into a different app. With OnDemand semantics
properly cleared (via `focus = false`), Hyprland routes keys
correctly to whichever window the user actually wants.

---

## Bonus visual — active editor border highlight

Added a `_editorHasFocus` property on the sticky card Rectangle.
The editor's `onActiveFocusChanged` sets it; the card's border
binds to it:

```qml
Rectangle {
    id: card
    property bool _editorHasFocus: false
    border.color: _editorHasFocus ? "#5288c9" : "#c9b96c"   // blue / tan
    border.width: _editorHasFocus ? 2 : 1
    Behavior on border.color { ColorAnimation { duration: 150 } }
}

TextArea {
    onActiveFocusChanged: {
        card._editorHasFocus = activeFocus
        // ... rest of handler ...
    }
}
```

Result: when you click into the sticky to edit, the border tints
blue and thickens to 2px. Click away → smooth 150ms fade back to
muted tan + 1px. Clear visual "this is the sticky receiving keys."

---

## Files changed (3)

```
zen-shell-v5/DesktopStickyNotes.qml  — onActiveFocusChanged handler,
                                         card._editorHasFocus property,
                                         reactive border color
zen-shell-v5/QuickNotesPanel.qml     — same onActiveFocusChanged
                                         handler on main editor
zen-shell-v5/ZenVersion.qml          — bumped to hf51
install.sh                            — banner + changelog
```

Pure safety hotfix — no UX changes for the active path, just
cleanup for the click-away path.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf51-sticky-focus-safety.tgz
cd zen-shell-v7.0.0-beta.1-hf51
./install.sh
```

`pkill quickshell` to reload.

---

## How to verify

1. Pop out a note as widget (toggle pill green)
2. Click into the widget's text area → border turns blue, cursor
   appears, can type
3. Click on a different app (Brave, terminal, anywhere outside the
   sticky) → border fades back to tan, selection cleared, cursor
   blink stops
4. Type something in the new app → keys go to that app, NOT the sticky ✅
5. Click back into the sticky → border turns blue again, can resume
   typing where you left off (cursor position preserved)

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf50 click-through + close + widget input/drag/live-sync
- ✅ hf49 sticky drag pattern + panel-level draggable
- ✅ hf48 hyprlock unlock focus reset workaround
- ✅ hf47 sticky notes as desktop widgets
- ✅ hf46 sticky draggable toggle foundation
- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 theme profiles save full state
- ✅ hf43 panel clipping + rounded toggle pills

🍃 Sticky widgets now know when they're not the active surface.
