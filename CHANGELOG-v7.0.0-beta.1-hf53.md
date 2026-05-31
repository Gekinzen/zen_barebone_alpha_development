# v7.0.0-beta.1-hf53 — Hyprbars floating-only + status feedback + Zen popup mimic

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes + adds

User report after hf52:

> "try ko wala nangyari tas if ever enable hyprbars kapag naka float
> ln dpat naka enable ah kapag fullscreen disable. and pre take note
> yung hypr control center natin, quick settings may hyprbars din kapag
> naka enable. gets?"

Three issues:

1. **Wala nangyari sa install** — hf52's installPlugin() fired hyprpm but
   without UI feedback. User couldn't tell if the install was running,
   succeeded, or failed silently.

2. **Floating-only rule wanted** — bars should appear ONLY on floating
   non-fullscreen windows. Tiled windows + fullscreen apps stay clean.

3. **Quick Settings + Hyprland Control Center should also have title bars**
   when hyprbars is enabled — for visual consistency between regular
   Hyprland windows and Zen Shell popups.

---

## Bug 1 — Silent install failure

### Root cause

hf52's `installProc` had no stdout/stderr capture. The bash command ran,
but exit code + output were invisible to the user. If the install failed
(missing build deps, network down, permission issue), nothing surfaced
in the UI.

### Fix

```qml
Process {
    id: installProc
    property string _opName: "install"
    stdout: StdioCollector {
        onStreamFinished: {
            const out = this.text.trim()
            root.statusMessage = out.split("\n").slice(-3).join(" | ")
        }
    }
    stderr: StdioCollector {
        onStreamFinished: {
            const err = this.text.trim()
            if (err) root.lastError = err.split("\n").slice(-2).join(" | ")
        }
    }
    onExited: function(exitCode) {
        root.busy = false
        if (exitCode === 0) {
            _notify("Hyprbars", _opName + " complete", 1)
        } else {
            _notify("Hyprbars", _opName + " failed: " + lastError, 2)
        }
    }
}
```

New state properties:
- `busy: bool` — true while a hyprpm command is running
- `statusMessage: string` — latest stdout snippet for UI display
- `lastError: string` — latest stderr snippet

UI additions:
- Spinner animation visible while `busy` is true
- Status message text appears below the install/update buttons
- Toast notification fires on every operation completion via
  `NotificationService.postInternal()` — same pipeline as power profile /
  battery alerts

Plus the install script itself is now broken into clearly-labeled steps:

```bash
echo '[Hyprbars] Step 1/4: hyprpm add'
hyprpm add ... 2>&1 | tail -5
echo '[Hyprbars] Step 2/4: hyprpm enable'
hyprpm enable hyprbars 2>&1 | tail -3
echo '[Hyprbars] Step 3/4: hyprpm reload'
hyprpm reload 2>&1 | tail -3
echo '[Hyprbars] Step 4/4: write config + source line'
```

Each step's output is captured. The user sees the most recent step
progress in real time.

---

## Feature — floating-only rule

### Logic

Per Hyprland windowrule v2 syntax, `floating` and `fullscreen` are
dynamic properties (re-evaluated whenever the window state changes).
We emit two windowrules at the end of the generated config:

```hypr
# v7.0.0-beta.1-hf53 — floating-only rules
windowrule = hyprbars:no_bar, floating:0
windowrule = hyprbars:no_bar, fullscreen:1
```

Combined effect:
- **Tiled window** → matches `floating:0` → no bar
- **Fullscreen window** → matches `fullscreen:1` → no bar
- **Floating non-fullscreen window** → matches neither → bar appears ✅

Because `floating` is dynamic, this updates LIVE:
- Press your float-toggle keybind → bar appears instantly
- Tile it back → bar disappears instantly
- Fullscreen the floating window → bar disappears
- Exit fullscreen → bar reappears

No reload needed for these transitions. Hyprland handles them per-frame.

### Toggle UI

A new `Hf52ToggleRow` in the Buttons section of HyprbarsSettingsPage:

```
[ Show bars only on floating windows ]                    [pill]
    Tiled and fullscreen windows have no bar (recommended).
    Adds windowrule = hyprbars:no_bar, floating:0 + fullscreen:1.
```

Default ON. When OFF, bars appear on all windows (which is the upstream
hyprbars default).

---

## Feature — HyprbarsMimic for Zen Shell popups

### Why we need it

The hyprbars plugin runs INSIDE Hyprland and applies only to regular
Hyprland windows (XDG/X11 toplevels). Quickshell layer-shell surfaces
(ControlPanel popup, ZenSettings panel) are NOT Hyprland-managed windows
— they live on layer-shell. So hyprbars never renders on them naturally.

Without intervention, the user sees:
- Brave / VS Code / terminal: nice hyprbars title bar ✅
- Quick Settings popup: no title bar (looks inconsistent)
- Settings panel: no title bar (looks inconsistent)

### Solution — HyprbarsMimic.qml (NEW, 265 lines)

In-shell component that mimics hyprbars rendering. Drives all visual
properties from `HyprbarsService` state, so colors / button side /
button visibility / height / blur all stay synced:

```qml
HyprbarsMimic {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    title: "Quick Settings"
    showMinimizeButton: false   // popups don't minimize
    onCloseClicked: parent.closeRequested()
}
```

The component auto-hides when `HyprbarsService.enabled` is false. So
it's zero-cost when the plugin is off (no rendering, no extra surfaces).

### Mounted on

- **ControlPanel** (Quick Settings popup) — title "Quick Settings",
  shows only close button (panels don't minimize/maximize)
- **ZenSettings** (Hyprland Control Center) — title "Settings", shows
  close + maximize (maximize toggles between centered + fullscreen via
  the existing `toggleFullscreen()` signal)

Both surface their close handlers as `closeRequested()` signals already
— hf53 just wires the mimic into those existing signals.

### Visual parity

The mimic uses identical:
- Color palette (from ThemeService when syncWithTheme is ON)
- Button side / order (mirrors HyprbarsService.buttonSide)
- Button visibility (mirrors per-button toggles)
- Button glyphs (✕ \uf00d, □ \uf2d0, _ underscore)
- Bar height (mirrors HyprbarsService.barHeight)
- Blur opacity (0.92 when blur on, 1.0 when off)

So when you toggle Left/Right in Settings, both the real hyprbars on
Brave AND the mimic on Quick Settings flip simultaneously. Same with
theme color changes.

---

## Files

### New (1)

```
zen-shell-v5/HyprbarsMimic.qml   265 lines — in-shell title bar
                                              component for popups
```

### Modified (5)

```
zen-shell-v5/HyprbarsService.qml      — status/busy/error properties,
                                          improved Process handlers,
                                          notifications, floatingOnly
                                          property, config writer
                                          emits windowrules
zen-shell-v5/HyprbarsSettingsPage.qml — floating-only toggle,
                                          spinner + status display
zen-shell-v5/ControlPanel.qml         — HyprbarsMimic mounted at top
zen-shell-v5/ZenSettings.qml          — HyprbarsMimic mounted at top
zen-shell-v5/ZenVersion.qml           — bumped to hf53
install.sh                             — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf53-hyprbars-floating-mimic.tgz
cd zen-shell-v7.0.0-beta.1-hf53
./install.sh
```

`pkill quickshell` to reload.

---

## How to test

### Status feedback

1. Settings → APPEARANCE → Hyprbars
2. Click "Install / reinstall"
3. Watch for:
   - Spinner appears next to status text
   - "Installing… this may take 30-60 seconds" message
   - Step-by-step output as hyprpm progresses
   - Toast notification when done

### Floating-only

1. Make sure hyprbars is enabled
2. Open Brave (likely tiles by default) → no title bar ✅
3. Press your float-toggle keybind (`Super+V` in default Hyprland configs)
4. Brave becomes floating → title bar appears instantly ✅
5. Fullscreen Brave (`Super+F`) → title bar disappears ✅
6. Exit fullscreen → title bar reappears ✅

### Mimic on Quick Settings + Settings

1. With hyprbars enabled, open Quick Settings (Super+C)
2. **Title bar appears at the top of the popup** matching your hyprbars
   colors and button side ✅
3. Click ✕ → popup closes
4. Open Settings (Super+,)
5. **Title bar appears at the top** with close + maximize buttons
6. Click □ → settings panel goes fullscreen (existing toggleFullscreen)
7. Disable hyprbars plugin → mimic bars disappear from both popups

### Cross-feature: theme + button side

1. Hyprbars enabled, sync ON
2. Settings → Themes → switch from Gruvbox to Tokyo Night
3. Both real hyprbars (Brave) AND mimic bars (Quick Settings) recolor
   simultaneously
4. Settings → Hyprbars → button side: Left
5. All bars (real + mimic) flip buttons to the left ✅

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf52 hyprbars plugin integration foundation
- ✅ hf51 sticky editor focus-loss safety
- ✅ hf50 click-through + close + widget input/drag/live-sync
- ✅ hf49 sticky drag pattern + panel-level draggable
- ✅ hf48 hyprlock unlock focus reset
- ✅ hf47 sticky as desktop widgets
- ✅ hf46 draggable toggle foundation
- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 theme profiles save full state

Three fixes:
- Install actually shows progress now
- Floating-only is one toggle away
- Zen Shell popups get title bars too when hyprbars is on

🍃 The whole window-management story is now visually unified.
