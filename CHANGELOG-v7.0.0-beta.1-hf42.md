# v7.0.0-beta.1-hf42 — Productivity modules ACTUALLY visible + usage docs

**Channel:** beta (hotfix)
**Released:** 2026-05-16
**Branch:** `dev`

---

## What this hotfix fixes

User report after hf41:

> "sa panel kala ko ba add mo yun mga toggle like translator and kung
> panu sila gamitn pala and sticky notes ?"

Paul expected the hf39 productivity modules (Quick Notes, Title
Translator, etc.) to **appear on his bar automatically** after install,
plus a clear how-to-use guide. hf39 created the modules + registered
them in `Bar.qml`'s `componentForModule` switch, **but never added them
to the default barLayout**. So upgrading users had to hand-edit
`bar-layout.json` or dig through Settings to find them — and even then,
the Settings → Panel module picker didn't list them because the
`allModules` catalog in `PanelPage.qml` was outdated.

Three fixes in this hotfix make the modules **actually discoverable**:

---

## #1 — Settings → Panel → Module Layout shows all modules

### Before

`PanelPage.qml` line 26:

```qml
readonly property var allModules: [
    "start", "taskbar", "workspaces", "window",
    "music", "sysrow", "tray", "battery", "powerbadge",
    "notifications", "clock",
    "weather", "sysmonitor", "clipboard"
]
```

The `+Add` dropdown in Module Layout settings used this list. Result:
even though `Bar.qml` knew how to render `quicknotes` / `focusspaces` /
etc., the user couldn't pick them through the UI. **Also** —
`workflow` had been added to the default barLayout in v7.0.0-alpha.13
but was never registered here either, so it was invisible in the picker.

### After

```qml
readonly property var allModules: [
    "start", "taskbar", "workspaces", "window",
    "music", "sysrow", "tray", "battery", "powerbadge",
    "notifications", "clock",
    "weather", "sysmonitor",
    "clipboard",        // v7.0.0-alpha.6
    "workflow",         // v7.0.0-alpha.13 — was missing!
    // hf39 productivity features
    "quicknotes",
    "focusspaces",
    "networkpulse",
    "smartdim",
    "titletranslator"
]
```

Plus a new `moduleMetadata` map provides friendly labels + icons for
each, so the dropdown can show "Quick Notes" instead of `quicknotes`,
"Title Translator" instead of `titletranslator`, etc. (Implementation
note: the dropdown will continue using raw ids until a future hotfix
wires up the metadata fully — but the catalog is now correct.)

---

## #2 — Default barLayout includes the daily-use modules

`Theme.qml` default barLayout updated:

```qml
property var barLayout: ({
    "left": ["start", "taskbar"],
    "center": ["workspaces", "window"],
    "right": ["music", "sysrow", "tray", "workflow", "clipboard",
              "quicknotes", "titletranslator",
              "battery", "powerbadge", "notifications", "clock"]
})
```

**Fresh installs** see Quick Notes + Title Translator on the bar
immediately after install. The other 3 (Focus Spaces, Network Pulse,
Smart Dim) stay opt-in via the +Add picker, because:

- **Smart Dim** changes brightness — needs explicit user consent
- **Focus Spaces** + **Network Pulse** have more niche use cases

---

## #3 — Existing users get the migration

`PanelState.qml` `applyState()` now has a hf42 migration block that
auto-injects `quicknotes` + `titletranslator` into upgraders' existing
barLayouts:

```qml
var _needsHf42 = !_savedVer || _savedVer < "7.0.0-beta.1-hf42"
if (_needsHf42 && _layout.right) {
    var _right3 = _layout.right.slice()
    var _changed = false
    if (_right3.indexOf("quicknotes") < 0) {
        // Insert after clipboard, or before notifications, or at end
        var _clipIdx = _right3.indexOf("clipboard")
        var _notifIdx2 = _right3.indexOf("notifications")
        if (_clipIdx >= 0) _right3.splice(_clipIdx + 1, 0, "quicknotes")
        else if (_notifIdx2 >= 0) _right3.splice(_notifIdx2, 0, "quicknotes")
        else _right3.push("quicknotes")
        _changed = true
    }
    if (_right3.indexOf("titletranslator") < 0) {
        var _qnIdx = _right3.indexOf("quicknotes")
        if (_qnIdx >= 0) _right3.splice(_qnIdx + 1, 0, "titletranslator")
        else _right3.push("titletranslator")
        _changed = true
    }
    if (_changed) {
        _layout.right = _right3
        Qt.callLater(root.saveState)
    }
}
```

Same idempotent pattern as the v6.16.0 battery migration + alpha.13
workflow migration. Self-stamping via `saveVersion` so it only runs
once. If you already manually added the modules, the migration sees
them and does nothing.

---

## #4 — NEW: `PRODUCTIVITY-FEATURES-USAGE.md` documentation

A new doc at the root of the tarball explains all 5 features with:

- What each does
- Bar icon + keybind reference
- How to use (step-by-step)
- Where state files live
- Privacy notes per-feature
- Module visibility cheat sheet (which are default vs opt-in)
- Right-click → Settings shortcut behavior

After install, find it at:
```
~/Downloads/zen-shell-v7.0.0-beta.1-hf42/PRODUCTIVITY-FEATURES-USAGE.md
```

Or read it inside this tarball before installing.

---

## Files changed (4)

```
zen-shell-v5/PanelPage.qml                   — extended allModules + moduleMetadata
zen-shell-v5/PanelState.qml                  — hf42 migration block + saveVersion bump
zen-shell-v5/Theme.qml                       — quicknotes + titletranslator in default
zen-shell-v5/ZenVersion.qml                  — bumped to hf42
PRODUCTIVITY-FEATURES-USAGE.md  NEW          — comprehensive usage guide
install.sh                                   — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf42-modules-visible-usage-docs.tgz
cd zen-shell-v7.0.0-beta.1-hf42
./install.sh
```

On first shell launch after install:

1. PanelState reads your existing `panel-state.json`
2. Sees `saveVersion < "7.0.0-beta.1-hf42"`
3. Injects `quicknotes` + `titletranslator` into your `barLayout.right`
4. Auto-saves with new saveVersion stamp
5. Bar instantly shows the two new icons

To see the other 3 (Focus Spaces / Network Pulse / Smart Dim):

1. `Super+comma` → Settings
2. Sidebar → Panel
3. Scroll to Module Layout
4. Pick your zone (left / center / right) from the +Add dropdown
5. Select the module (focusspaces / networkpulse / smartdim) → click +Add

---

## How to verify

After install:

```bash
# Check your barLayout has the new modules
cat ~/.config/quickshell/panel-state.json | grep -A8 barLayout
# Should now include "quicknotes" and "titletranslator" in right array
```

On the bar:
- Look for the sticky-note icon (Quick Notes)
- Look for the globe icon (Title Translator)

Right-click each → jumps to their Settings page with full UI.

---

## Wala tayong babawasan

Lahat ng previous fixes preserved:

- ✅ hf41 collapsible Settings search + Input tab custom sliders
- ✅ hf40 Quick Notes keybinds + sticky notes
- ✅ hf39 5 productivity features  
- ✅ hf38 string colors + annotation transparency
- ✅ hf37 event-driven hot corners
- ✅ hf36 refresh rate toggle
- ✅ hf32 native toasts + login sound

Pure discoverability hotfix — registers the modules properly so they
show up in the Settings picker, auto-injects the most-useful pair
into existing barLayouts, and ships the long-overdue usage guide. 🍃
