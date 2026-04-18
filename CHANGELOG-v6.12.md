# Zen Shell v6.12 — Changelog

**Target:** Hyprland 0.54+ / CachyOS / Arch Linux
**Quickshell:** QML-based shell (Zen Shell beta)

## v6.12 — Widget Visibility Fix + Context Menu Fix + Taskbar Overflow + Hyprland 0.54 Compat

### v6.12b — Priority 1 Quick Fixes

**Wallpaper grid 5th row spillover — Fixed.**
`wallpapersPerPage` was hardcoded to 8. With wider windows (5+ columns),
only 2 rows showed — but on narrower windows or when the picker shrinks,
items spilled into a 5th row. Now dynamic: `columns × 4` rows max.
The picker pushes its column count back to `WallpaperServiceV5` on
resize so the paged list always slices to exactly 4 rows.

**Settings panel exits on internal click — Fixed.**
Same root cause as the v6.12 taskbar context menu fix: `HyprlandFocusGrab`
with `windows: [settingsWindow]` killed the panel when clicking any
dropdown, color picker, or popup inside ZenSettings (those are separate
Wayland surfaces not in the grab list). Removed the `HyprlandFocusGrab`.
Click-outside dismiss now handled solely by the transparent backdrop
`MouseArea` which sits behind ZenSettings.

**Flameshot bind — toggle mode.**
`Super+Alt+F12` now uses `pkill flameshot || flameshot gui` — kills
flameshot if running, starts GUI if not. Updated in both `binds.conf`
and `keybinds-update.conf`.

**`togglesplit` bind — dwindle comment restored.**
`Super+J` dispatches `togglesplit` (dwindle layout splitter). Added
`# dwindle` comment for clarity alongside `pseudo`.

### Desktop Widgets Not Showing — Fixed

**Root cause:** `WlrLayershell.layer` was set to `WlrLayer.Background`.
The Background layer sits *behind* the wallpaper (swww/swaybg/awww),
so widgets were rendering but completely hidden underneath.

**Fix:** Changed to `WlrLayer.Bottom` in `shell.qml`. The Bottom layer
sits above the wallpaper but below all application windows — exactly
where desktop widgets should live.

### Hyprland Config Error: layerrule:noanim — Fixed

**Root cause:** `noanim` is not a valid `layerrule` property — it only
exists for `windowrulev2`. The invalid rule caused config parse errors
on every Hyprland reload.

**Fix:** Removed the invalid `noanim` layerrule entirely. Widgets don't
need animation suppression at the layer level.

### Flameshot GUI Opens on Wrong Monitor — Fixed

**Root cause:** `flameshot gui` (Super+Alt+F12) launched without any
display targeting, so flameshot defaulted to the first monitor instead
of the focused one. On multi-monitor setups (e.g. ultrawide + portrait),
the GUI would appear on the wrong screen.

**Fix:** `zen-screenshot.sh` now passes `--region WxH+X+Y` to
`flameshot gui` using the focused monitor's geometry from
`hyprctl monitors -j`. Also added `windowrulev2` rules for flameshot:
`noanim`, `float`, `pin`, `stayfocused`, `suppressevent fullscreen`.
Auto-creates `~/.config/flameshot/flameshot.ini` with Wayland defaults
on first run.

### Taskbar Right-Click Menu — Fixed

**Root cause:** `HyprlandFocusGrab` in `Taskbar.qml` was set with
`windows: [barWindow]`. But `PopupWindow` (context menu) is a separate
Wayland surface not included in that list. When clicking any menu item
(Pin, Unpin, New Window, Close All), the focus grab detected a click
outside its window list → fired `onCleared` → reset `ctxAppId = ""` →
popup vanished *before* the `MouseArea.onClicked` inside could register.

**Fix:** Removed `HyprlandFocusGrab` entirely. Replaced with a
background `MouseArea` (z: -1) on the taskbar root that dismisses
popups when clicking the bar background. Context menu items now have
full click-through — Pin, Unpin, New Window, Close All all work.

### Taskbar Overflow Auto-Collapse

When too many apps are open (pinned + running > ~10), the taskbar now
caps its width at 440px and shows `❮` / `❯` chevron scroll buttons.

- Smooth animated scroll (200ms OutCubic) stepping 2 icons per click
- Left chevron hidden when at start, right hidden when at end
- `clip: true` viewport hides overflowed icons cleanly
- Scroll offset auto-clamps when windows close (app list shrinks)
- Minimalist look preserved — no scrollbar, just subtle chevron pills

### QT_QPA_PLATFORM Environment Variable

Installer now auto-injects `env = QT_QPA_PLATFORM,wayland` into
`~/.config/hypr/hyprland.conf` if not already present. Skips if the
env is already set.

### Screenshot Dependencies

`flameshot`, `grim`, `slurp`, and `wl-clipboard` are checked as
recommended dependencies. Already existing packages are skipped
via `--needed` flag on the package manager call (paru/yay/pacman).

### Hyprland 0.54 Syntax Migration

**Root cause:** Hyprland 0.53+ completely overhauled both `windowrule`
and `layerrule` syntax. `windowrulev2` is fully deprecated (errors on
0.54). Old `layerrule { name = ... }` block syntax with separate
`match:namespace =` lines also produces errors.

**Fix:** Rewrote `hyprland-layer-rules.conf` entirely using the new
0.54 anonymous one-liner syntax:

```
# OLD (deprecated, errors on 0.54):
layerrule {
    name = zen-bar-blur
    match:namespace = zen-shell-bar
    blur = true
    ignore_alpha = 0.5
}
windowrulev2 = float, title:^(flameshot)

# NEW (Hyprland 0.54+):
layerrule = blur on, ignore_alpha 0.5, match:namespace zen-shell-bar
windowrule = float true, match:title ^(flameshot)
```

All 5 layerrules and 5 windowrules converted. Zero config errors on
`hyprctl reload`.

### Installer Updates

- Version banner updated to v6.12
- Success banner shows v6.12
- `--needed` flag on `paru -S` / `yay -S` ensures existing deps skip
- `env = QT_QPA_PLATFORM,wayland` auto-added to hyprland.conf

## Modified Files

- zen-shell-v5/shell.qml (WlrLayer fix, settings HyprlandFocusGrab removed)
- zen-shell-v5/Taskbar.qml (HyprlandFocusGrab removed, overflow added)
- zen-shell-v5/WallpaperPicker.qml (dynamic 4-row cap via columns × 4)
- zen-shell-v5/WallpaperServiceV5.qml (wallpapersPerPage now writable)
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

- [ ] Desktop widgets visible on login (clock, weather, sysmon)
- [ ] Widgets show above wallpaper, below windows
- [ ] Right-click taskbar icon → context menu appears
- [ ] Click "Pin to taskbar" → app pins, menu closes
- [ ] Click "Unpin" → app unpins, menu closes
- [ ] Click "New window" → new window launches, menu closes
- [ ] Click "Close" / "Close all" → windows close, menu closes
- [ ] Open 12+ apps → taskbar shows ❯ chevron on right
- [ ] Click ❯ → taskbar scrolls smoothly to reveal hidden icons
- [ ] Click ❮ → taskbar scrolls back
- [ ] Close windows until <10 → chevrons disappear, normal layout
- [ ] hyprland.conf has `env = QT_QPA_PLATFORM,wayland` after install
- [ ] Existing deps not re-downloaded on install (--needed)
- [ ] No regressions: drag widgets, settings, wallpaper picker, themes
- [ ] No Hyprland config errors on reload (check `hyprctl reload`)
- [ ] Super+Alt+F12 → flameshot GUI opens on focused monitor
- [ ] Flameshot GUI works on ultrawide when cursor is on ultrawide
- [ ] Flameshot GUI works on portrait monitor when cursor is there
- [ ] Super+F12 → grim region select works on focused monitor
