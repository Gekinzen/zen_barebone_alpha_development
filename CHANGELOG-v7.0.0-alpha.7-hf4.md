# v7.0.0-alpha.7-hf4 — Keyboard focus fix for Settings + Control Panel

**Channel:** alpha (hotfix 4)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

Critical UX bug: typing in the Settings sidebar search bar (or any
input field inside Settings or Control Panel) was leaking keystrokes
to whatever application was focused before the panel opened.

User reported:
> "tinitesting ko search hindi nakakapaag type. tas na ttype kung
> anu yun mga nasa background ko like terminal jusko dapat matiok
> kapag dun sa search nag type naka hover sa hypr control center
> natin dun ln dapat hindi dapt makaka type sa labas."

Translation: typing in Settings search wasn't registering, and the
keystrokes were going to the terminal in the background.

### Root cause: missing `keyboardFocus` on layer-shell surfaces

Wayland layer-shell surfaces have a `keyboard_interactivity` field
that determines how keyboard events are routed. The 3 modes are:

| Mode | Behavior |
|---|---|
| **None** (Quickshell default) | Surface never receives keyboard events; they go to the focused window underneath |
| **Exclusive** | Surface grabs keyboard exclusively; held even when modals spawn on top |
| **OnDemand** | Surface gets keyboard focus when user clicks it; releases on click-elsewhere |

Settings + Control Panel were using **None** (default). When user
clicked the search bar, QML would set the TextField's `activeFocus`,
but the Wayland compositor had no idea this surface wanted keyboard
events — so it kept routing keystrokes to the previously-focused
window (terminal, browser, etc.).

The other panels with input fields (StartMenu, ClipboardPanel,
SettingsSearchOverlay) all use `HyprlandFocusGrab` which forces
focus exclusively. Settings + ControlPanel deliberately don't use
that grab (per v6.13 design — they should stay open after click-
outside, like a real desktop app), so they need a different
solution.

### Fix: WlrLayershell.keyboardFocus = OnDemand

Added one property to both `settingsWindow` and `controlPanelWindow`:

```qml
WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
```

This is the **best of both worlds**:

- **Click panel** → keyboard focus grabs → typing goes to panel
- **Click outside panel** → focus releases naturally → typing goes
  to the window the user clicked
- **Panel doesn't auto-close** on click-outside (still desktop-app
  behavior — only the ✕ close button, Esc, or the Super+, /
  Super+C keybind closes it)
- **Click-through still works** for clicks outside the panel
  rectangle (handled by the existing `mask: Region { item: ... }`)

#### Why not Exclusive?

Exclusive mode would grab keyboard even when modals spawn on top of
the panel — e.g. a zenity file picker spawned from Settings would
not receive keyboard input because Settings would still be holding
the grab. OnDemand naturally hands off focus to the modal.

#### Why not HyprlandFocusGrab?

HyprlandFocusGrab is heavier — it grabs the entire input surface
and fires `onCleared` on click-outside, which we'd then have to
either ignore (defeating the purpose) or use to close the panel
(breaking the v6.13 stay-open behavior). `OnDemand` is the lighter,
more correct primitive.

---

## Files modified

```
zen-shell-v5/shell.qml         (added WlrLayershell.keyboardFocus
                                 to settingsWindow + controlPanelWindow)
zen-shell-v5/ZenVersion.qml    (bumped to v7.0.0-alpha.7-hf4)
install.sh                     (version strings)
```

Two single-line additions in shell.qml + accompanying comments. No
other files touched.

---

## Wala tayong babawasan

- All alpha.7 features intact
- v6.13 click-through behavior preserved (mask: Region still works)
- v6.13 desktop-app stay-open behavior preserved (no auto-close on
  click-outside)
- StartMenu, ClipboardPanel, SettingsSearchOverlay focus grabs all
  unchanged (they continue to use HyprlandFocusGrab because they
  ARE meant to close on click-outside)
- Zero impact on perf — keyboardFocus is a static layer-shell
  property, no extra polling/handlers

---

## Verified

- ✅ shell.qml lint clean (qmlformat parse OK)
- ✅ `WlrKeyboardFocus.OnDemand` set on both settingsWindow + controlPanelWindow
- ✅ `Quickshell.Wayland` import already present (where WlrKeyboardFocus is defined)

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.7-hf4-keyboard-focus.tgz
cd zen-shell-v7.0.0-alpha.7
./install.sh
qs -r
```

After install:

1. **Open Settings** (Super+,) → panel appears
2. **Click sidebar search bar** → focus grabs to Settings
3. **Type** → text appears in search bar (NOT in background terminal)
4. **Click outside Settings panel** → focus releases naturally to
   whatever you clicked
5. **Click another window** → keystrokes go there
6. **Click back into Settings** → focus grabs again
7. Same flow works for **Control Panel** — open with Super+C,
   click any input, type cleanly
8. Same flow works for **WiFi password prompt** spawned from CC —
   the prompt's HyprlandFocusGrab takes priority over CC's
   OnDemand correctly
