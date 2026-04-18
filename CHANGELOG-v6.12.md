# Zen Shell v6.12 — Changelog

**Target:** Hyprland 0.54+ / CachyOS / Arch Linux
**Quickshell:** QML-based shell (Zen Shell beta)

---

## v6.12 — Fixes + Settings Draggable + Wallpaper Slideshow + Hyprland 0.54

### Desktop Widgets Not Showing — Fixed

**Root cause:** `WlrLayershell.layer` was `WlrLayer.Background` — the
Background layer sits *behind* the wallpaper (swww/swaybg/awww), so
widgets rendered but were completely hidden underneath.

**Fix:** Changed to `WlrLayer.Bottom` in `shell.qml`. Bottom layer sits
above wallpaper but below all application windows.

### Taskbar Right-Click Menu (Pin/Unpin/Close) — Fixed

**Root cause:** `HyprlandFocusGrab` with `windows: [barWindow]` — the
`PopupWindow` context menu is a separate Wayland surface not in the grab
list. Clicking any menu item triggered `onCleared` → reset `ctxAppId`
→ popup vanished before `MouseArea.onClicked` could register.

**Fix:** Removed `HyprlandFocusGrab`. Replaced with background
`MouseArea` (z: -1) for bar-level click-outside dismiss. All context
menu items (Pin, Unpin, New Window, Close All) now work.

### Taskbar Overflow Auto-Collapse

When too many apps are open (pinned + running > ~10), taskbar caps
width at 440px and shows `❮` / `❯` chevron scroll buttons.

- Smooth animated scroll (200ms OutCubic), 2 icons per step
- Left/right chevrons auto-hide at scroll boundaries
- `clip: true` viewport, scroll offset auto-clamps on window close
- Minimalist — no scrollbar, just subtle chevron pills

### Settings Panel — No Auto-Close on Click Outside

**Root cause:** `HyprlandFocusGrab` + backdrop `MouseArea` both closed
the panel when clicking dropdowns, color pickers, popups, or anywhere
outside the panel.

**Fix:** Removed BOTH. Panel now stays open until explicitly closed via:
1. ✕ close button
2. Super+, toggle (same keybind that opens it)
3. Esc key

### Settings Panel — Draggable

Settings panel is now draggable by the sidebar header ("⚙ Settings"
text area). Drag handle covers the gear icon + title only — close ✕
and maximize buttons remain independently clickable.

- Uses `drag.target: root` with `preventStealing: true`
- `hasBeenDragged` flag breaks `anchors.centerIn` on first drag
- Resets to centered on every reopen or fullscreen toggle
- Disabled during fullscreen mode

### Settings Panel — Always Centered on Open

**Root cause:** Previous imperative centering (`_centerSelf()`) used
`settingsWindow.width` which was 0 before compositor sizing, or used
`modelData.width` which gave wrong values on multi-monitor.

**Fix:** Uses `anchors.centerIn: parent` (QML's native centering) with
a conditional ternary that breaks the anchor when drag starts:
```qml
anchors.centerIn: (!fullscreen && !hasBeenDragged) ? parent : undefined
```
Bulletproof — works on any screen size, any resolution, any monitor.

### Wallpaper Grid — Strict 4-Row Cap

**Root cause:** `wallpapersPerPage` was hardcoded to 8 in
`WallpaperServiceV5.qml`. With 5 columns in Settings → Wallpaper,
items spilled into a 5th row.

**Fix:** Both `WallpaperPicker.qml` (Super+W popup) and
`WallpaperPage.qml` (Settings → Wallpaper) now set
`wallpapersPerPage = columns × 4` on load. WallpaperPage uses
`5 × 4 = 20` items max (exactly 4 rows of 5). WallpaperPicker
dynamically adjusts based on its own column count.

### Wallpaper Slideshow Toggle — Actually Stops Now

**Root cause (triple bug):**
1. **Declarative `running:` binding** — timer had
   `running: root.slideshowEnabled && ...` which QML re-evaluated
   after `stop()`, potentially restarting the timer before the
   property change propagated.
2. **FileView reload race** — `FileView` with `blockLoading: false`
   auto-reloads when the state file changes. `saveState()` writes
   the file → FileView detects → `applyState()` fires → could read
   stale state and re-enable slideshow.
3. **Timer not synced on login** — `applyState()` set
   `slideshowEnabled` but never started/stopped the timer.

**Fix:**
- Removed declarative `running:` binding — timer starts as
  `running: false`, controlled only imperatively via `.stop()` /
  `.restart()` in `setSlideshow()`
- Added `_saving` guard — `applyState()` returns immediately while
  `saveState()` is writing, preventing race condition
- `applyState()` now explicitly calls `slideshowTimer.restart()` or
  `.stop()` based on loaded state, so logout/login preserves the
  toggle correctly

### Flameshot GUI — Opens on Focused Monitor

**Root cause:** `flameshot gui` launched without display targeting,
defaulting to the first monitor instead of the focused one.

**Fix:** `zen-screenshot.sh` now passes `--region WxH+X+Y` to
`flameshot gui` using focused monitor geometry from
`hyprctl monitors -j`. Added Hyprland 0.54 window rules for
flameshot: `float`, `no_anim`, `pin`, `stay_focused`.

### Flameshot Bind — Toggle Mode

`Super+Alt+F12` now uses `pkill flameshot || flameshot gui` — kills
if running, starts GUI if not. Updated in both `binds.conf` and
`keybinds-update.conf`.

### Hyprland 0.54 Syntax Migration

Rewrote `hyprland-layer-rules.conf` entirely. All `windowrulev2`
(deprecated) and old `layerrule { }` block syntax converted to new
0.54 anonymous one-liner format:

```
# OLD (errors on 0.54):
windowrulev2 = float, title:^(flameshot)
layerrule { name = x  match:namespace = y  blur = true }

# NEW:
windowrule = float true, match:title ^(flameshot)
layerrule = blur on, ignore_alpha 0.5, match:namespace zen-shell-bar
```

### QT_QPA_PLATFORM Environment Variable

Installer auto-injects `env = QT_QPA_PLATFORM,wayland` into
`~/.config/hypr/hyprland.conf` if not already present.

### Keybind Notes

| Keybind | Action |
|---|---|
| Super+, | Toggle settings panel |
| Super+/ or Super+F2 | Keybind cheatsheet popup |
| Super+Alt+F12 | Toggle flameshot GUI |
| Super+J | Toggle split direction (dwindle) |
| Super+P | Pseudo-tile (dwindle) |

**Note:** `Super+J` (togglesplit) and `Super+P` (pseudo) require
`general { layout = dwindle }` in hyprland.conf. Check with:
`hyprctl getoption general:layout`

---

## Modified Files

- zen-shell-v5/shell.qml (WlrLayer fix, settings draggable + centered, no auto-close)
- zen-shell-v5/ZenSettings.qml (drag handle on sidebar header, hasBeenDragged property)
- zen-shell-v5/Taskbar.qml (HyprlandFocusGrab removed, overflow chevrons)
- zen-shell-v5/WallpaperPicker.qml (dynamic 4-row cap via columns × 4)
- zen-shell-v5/WallpaperPage.qml (enforces 5 × 4 = 20 items per page)
- zen-shell-v5/WallpaperServiceV5.qml (slideshow timer fix, _saving guard, wallpapersPerPage writable)
- hypr-config/hyprland-layer-rules.conf (Hyprland 0.54 syntax, flameshot windowrule)
- hypr-config/binds.conf (flameshot toggle, dwindle comments)
- hypr-config/keybinds-update.conf (flameshot toggle)
- scripts/zen-screenshot.sh (flameshot gui --region for focused monitor)
- install.sh (v6.12 banner, QT_QPA_PLATFORM env, version strings)

## Install

    tar -xzf zen-shell-v6_12-complete.tar.gz
    cd zen-shell-v6_12-complete
    ./install.sh

Arch Linux / CachyOS. Installer uses paru > yay > pacman.
Existing quickshell process is killed automatically before restart.

## Test Checklist

**Desktop Widgets**
- [ ] Widgets visible on login (clock, weather, sysmon)
- [ ] Widgets above wallpaper, below windows

**Taskbar**
- [ ] Right-click → context menu → Pin/Unpin/Close all work
- [ ] 12+ apps → ❯ chevron appears → scrolls → ❮ scrolls back
- [ ] Close windows → chevrons disappear when no overflow

**Settings Panel**
- [ ] Super+, → opens centered on screen
- [ ] Click outside panel → panel stays open (no auto-close)
- [ ] Grab "⚙ Settings" text → drag panel around screen
- [ ] Reopen → panel centers again (drag position resets)
- [ ] ✕ button works in both windowed and fullscreen mode
- [ ] Esc closes panel
- [ ] Super+, closes panel (toggle)

**Wallpaper**
- [ ] Settings → Wallpaper → exactly 4 rows of thumbnails
- [ ] Super+W → WallpaperPicker → 4 rows max
- [ ] Toggle slideshow OFF → wallpapers stop immediately
- [ ] Close settings → wallpapers stay stopped
- [ ] Logout → login → wallpapers still stopped
- [ ] Toggle slideshow ON → cycling resumes
- [ ] Check log: `tail -f /tmp/zen-shell.log | grep WallpaperV5`

**Flameshot & Screenshots**
- [ ] Super+Alt+F12 → flameshot GUI on focused monitor
- [ ] Super+Alt+F12 again → kills flameshot (toggle)
- [ ] Super+F12 → grim region select on focused monitor

**Hyprland Config**
- [ ] `hyprctl reload` → no red error bar
- [ ] hyprland.conf has `env = QT_QPA_PLATFORM,wayland`

**Keybinds**
- [ ] Super+/ → cheatsheet popup shows all current binds
- [ ] Super+J → togglesplit works (requires dwindle layout)
