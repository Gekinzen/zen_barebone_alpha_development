# Zen Shell v6.13 — Changelog

**Target:** Hyprland 0.54+ / CachyOS / Arch Linux
**Quickshell:** QML-based shell (Zen Shell beta)
**Total QML files:** 50

---

## v6.13 — Control Panel + SysRow Expand + Calendar + Rice Export

Priority 2 complete: bar system tray rewrite, control panel, connectivity
layer, notification settings, calendar popup, and rice export/import.
All Python/GTK dependencies replaced with pure QML + bash.

---

## SysRow — Waybar-Style Expandable Tray

Bar right-side system tray, ported from Zen Alpha waybar `group/expand`.

- Default: `❮` expand arrow only
- Click/hover → smooth expand (300ms) showing all modules
- Auto-collapse 800ms after mouse leaves

**Modules with distinct colors:**

| Module | Icon | Color | Click |
|--------|------|-------|-------|
| Sound | `\uf028` | aqua | pavucontrol toggle |
| CPU | `\uf2db` | blue | btm in alacritty toggle |
| RAM | `\uefc5` | green | btm toggle |
| Temp | `\uf2c9` | orange | btm toggle |
| Network | `󰤯-󰤨` 5-tier | purple | Control Panel (Super+C) |
| Bluetooth | `\uf293` | yellow | blueman-manager toggle |

**Hover tooltips:** Separate PanelWindow overlay (`zen-shell-tooltip`)
above the bar — Wayland-correct since PanelWindow clips children.

**Customization (Settings → System Tray):**
- Per-module visibility toggles
- Display mode: icon+bargraph (`▅`) or icon+text (`42%`)
- Custom per-module colors (empty = theme-reactive auto)
- Export/import rice configs as JSON

---

## ConnectivityService

Pure QML singleton polling WiFi/BT/Audio/LAN every 3s via single bash.
Sources: `nmcli`, `bluetoothctl`, `wpctl`, `ip link`.

---

## ControlPanel (Super+C)

Draggable quick settings: PipeWire volume sliders, WiFi/BT/LAN toggles,
CPU/GPU/RAM stats, expand arrow for network list + BT devices.

---

## Calendar Popup

Click clock → calendar overlay (separate PanelWindow, bottom-right).
Month grid, today highlight, `◀ ▶` navigation, focus-grab dismiss.

---

## NotificationPage — SwayNC Position

**Fixed in latest iteration:**

Root cause of position not applying was **three bugs:**

1. **Heredoc in bash -c string** — `<< 'ZSEOF'` inside a concatenated
   JS string broke the bash command at the heredoc delimiter. Everything
   after `ZSEOF` never executed. **Fix:** use `printf` for state file,
   no heredoc.

2. **`&;` syntax error** — `setsid swaync &;` is invalid bash (can't
   have `;` after `&`). **Fix:** removed stray semicolons.

3. **Race condition** — two Process objects (`stateSaver` + `swayncWriter`)
   fired simultaneously. The swaync restart could happen before the config
   was written. **Fix:** separated into two Process objects with a 200ms
   Timer delay between save and patch.

**Current approach (matches Alpha Python code exactly):**
1. `_saveZenState()` — writes zen notification-state.json via `printf`
2. 200ms delay via Timer
3. `_patchAndRestart()` — uses `python3` to `json.load → patch → json.dump`
   (same as `notifications.py`), then `swaync-client --reload-config`,
   then `pkill -9 swaync + setsid swaync` restart, then test notification

**State persistence:** Position saved to `notification-state.json`,
loaded on Settings open via FileView. Survives restart.

---

## Rice Export/Import

`SysRowState.exportRice(name)` saves full config:
- PanelState (bar mode, height, borders, fonts, etc.)
- SysRowState (toggles, colors, display mode)
- Theme ID + bar layout
- Meta (timestamp, version)

Import: clipboard paste or load from saved exports list.

---

## Settings Sidebar

- Added: System Tray, Sound & Network, Notifications
- Removed: Appearance (legacy)
- Fixed: Themes icon → palette `󰔎`, theme preview → 2×2 color swatch

---

## Icon Fixes

| Icon | Codepoint | Notes |
|------|-----------|-------|
| RAM | `\uefc5` | Confirmed in JetBrainsMono Nerd Font |
| CPU | `\uf2db` | U+F2DB microchip |
| Temp | `\uf2c9` | U+F2C9 thermometer |
| Sound | `\uf028` | U+F028 volume |
| Themes | `\udb80\udd0e` | U+F050E palette |

---

## Keybinds

| Keybind | Action |
|---------|--------|
| Super+C | Control Panel |
| Super+, | Settings |
| Super+W | Wallpaper picker |
| Super+A | Start menu |
| Super+/ | Keybind cheatsheet |
| Clock click | Calendar popup |

---

## Layer Rules

```conf
layerrule = blur on, ignore_alpha 0.3, match:namespace zen-shell-controlpanel
layerrule = blur on, ignore_alpha 0.3, match:namespace zen-shell-calendar
layerrule = blur on, ignore_alpha 0.3, match:namespace zen-shell-tooltip
```

---

## Files

**New (14):** ConnectivityService, ControlPanel, ConnToggleRow, StatChip,
ConnectivityPage, NotificationPage, SysRow, SysRowIcon, SysRowState,
SysRowPage, ZenCalendar, ZenClock (rewrite)

**Modified (5):** ZenSettings, shell.qml, ThemesPage,
keybinds-update.conf, hyprland-layer-rules.conf

---

## Install

```bash
tar -xzf zen-shell-v6_13-complete.tar.gz
cd zen-shell-v6_13-complete
./install.sh
```

## Test Checklist

- [ ] SysRow `❮` expands with colored icons (aqua/blue/green/orange/purple/yellow)
- [ ] Hover icon → tooltip appears ABOVE bar
- [ ] Click CPU/RAM → btm toggle, Sound → pavucontrol, Network → Control Panel
- [ ] Clock click → calendar popup bottom-right
- [ ] Super+C → Control Panel with volume/WiFi/BT
- [ ] Settings → Notifications → click position → test notification at new position
- [ ] Settings → Notifications → position persists after restart
- [ ] Settings → System Tray → toggle modules, switch modes, custom colors
- [ ] Settings → System Tray → Export rice → file created
- [ ] Theme switch → SysRow colors + swaync CSS update
