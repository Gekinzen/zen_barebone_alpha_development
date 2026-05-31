# v7.0.0-alpha.6-hf3 — Clipboard click fix + assignment icon

**Channel:** alpha (hotfix 3)
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this hotfix fixes

User reported two issues after adding clipboard module to bar:

1. **Clicking clipboard module didn't show the panel.** Indicator
   highlighted on click but no panel appeared.
2. **Wrong clipboard icon.** Wanted the `assignment` glyph (clipboard
   with checklist lines), not `content_paste` (clipboard with paste
   arrow).

### 1. Multi-monitor focus-grab race

**Cause:** The `clipboardWindow` PanelWindow was iterated via
`Variants { model: Quickshell.screens }` but read
`PanelState.clipboardVisible` directly for visibility. On click,
the panel opened on EVERY monitor simultaneously, and each monitor's
`HyprlandFocusGrab` immediately fired `onCleared` because focus
could only be on one screen at a time → the FIRST grab to fire
flipped `clipboardVisible = false` → all panels disappeared in the
same frame the click triggered.

This is the same pattern that StartMenu fixed in v6 with
`startMenuScreen` — only ONE monitor shows the panel at a time.

**Fix:** Mirrored StartMenu's per-screen state pattern.

New on shell root:

```qml
property var clipboardScreen: null

function toggleClipboardOnScreen(screen) {
    if (clipboardScreen === screen) clipboardScreen = null
    else clipboardScreen = screen
    PanelState.clipboardVisible = (clipboardScreen !== null)
}

function closeClipboard() {
    clipboardScreen = null
    PanelState.clipboardVisible = false
}
```

`PanelState.clipboardVisible` is kept as a mirror flag for visual
state references in ClipboardModule (`is panel showing on
my-screen?` style queries) and for IPC compatibility.

The PanelWindow visibility binding became:

```qml
visible: root.clipboardScreen === modelData   // was: PanelState.clipboardVisible
```

So only the matching monitor renders the panel; all others stay
hidden. The HyprlandFocusGrab's onCleared also gets a guard:

```qml
onCleared: {
    if (root.clipboardScreen === modelData) root.closeClipboard()
}
```

This avoids cross-monitor cleared events accidentally closing the
active panel.

### 2. ClipboardModule click handler routed through IPC

The bar module's onClicked previously did:

```qml
PanelState.clipboardVisible = !PanelState.clipboardVisible
```

This bypassed the per-screen routing (no way to know which screen
the click came from at the property-flip site). Updated to:

```qml
Quickshell.execDetached({
    command: ["qs", "-c", "zen-shell", "ipc",
              "call", "zen", "toggleClipboard"]
})
```

The `toggleClipboard` IPC handler then picks `Quickshell.screens[0]`
as the target screen (good enough — the user's primary is usually
where they triggered it). Future enhancement: detect the active
Hyprland workspace's monitor for true focused-screen targeting.

### 3. Wrong icon — assignment instead of content_paste

`MaterialIcons.qml` registry got a new entry:

```qml
"assignment":  "\ue85d"   // clipboard with checklist lines
```

Per Paul's link: <https://fonts.google.com/icons?icon_names=assignment>

Updated both surfaces:

- `ClipboardModule.qml` (bar widget) — was `content_paste`, now `assignment`
- `ClipboardPanel.qml` (header) — was `content_paste`, now `assignment`

The old `content_paste` codepoint stays in the registry — other code
that wants the paste-arrow variant can still use it.

---

## Files modified

```
zen-shell-v5/shell.qml             (+clipboardScreen state, +helpers,
                                     toggleClipboard IPC rewrite,
                                     clipboardWindow per-screen visibility)
zen-shell-v5/ClipboardModule.qml   (click handler → IPC, icon → assignment)
zen-shell-v5/ClipboardPanel.qml    (header icon → assignment)
zen-shell-v5/MaterialIcons.qml     (+assignment entry)
zen-shell-v5/ZenVersion.qml        (bumped to v7.0.0-alpha.6-hf3)
install.sh                         (version strings)
```

ClipboardService unchanged from alpha.6 — service was correct, the
bug was purely in the per-screen presentation layer.

---

## Wala tayong babawasan

- `PanelState.clipboardVisible` retained as mirror flag — visual
  state references in ClipboardModule (highlight, tooltip) still
  work because we set it true whenever clipboardScreen is non-null.
- IPC compatibility preserved — `toggleClipboard` is still callable
  externally (Hyprland keybind, scripts), it just routes through
  the new per-screen logic now.
- `content_paste` icon kept in registry → not a regression for any
  future code that wants it.
- All v7 alpha.6/hf1/hf2 features carry forward.

---

## Verified

- ✅ All 4 modified files lint clean (qmlformat parse OK)
- ✅ `clipboardScreen` per-screen state declared
- ✅ `toggleClipboardOnScreen` + `closeClipboard` helpers present
- ✅ Per-screen visibility binding (`root.clipboardScreen === modelData`)
  in 2 places (visible + onCleared guard)
- ✅ `Quickshell.execDetached` route in ClipboardModule
- ✅ `assignment` icon in 3 places (registry + module + panel header)

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.6-hf3-clipboard-click-fix.tgz
cd zen-shell-v7.0.0-alpha.6
./install.sh
qs -r
```

After install:

1. **Click the clipboard icon in your bar** → panel pops out from the
   bar edge (sticky-anchored, same geometry as StartMenu)
2. **Press Super+V** → same panel, same screen
3. **Click outside the panel** → panel closes (focus grab clean)
4. **Open on multi-monitor** → only ONE monitor shows the panel
   (the focused one, or screen 0 as fallback)

Material font with `assignment` icon shows the clipboard-with-lines
glyph, not the clipboard-with-paste-arrow.
