# Zen Barebone Alpha

**A Quickshell-native desktop environment for Hyprland.**

Zen Shell (formerly "Zenith") is a complete desktop shell built entirely in QML using [Quickshell](https://github.com/quickshell-mirror/quickshell) — replacing the previous mixed stack of GTK4/Libadwaita, Python, C++, and Waybar with a unified, lightweight QML architecture.

![Zen Shell Desktop](https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/preview.png)

## Current Release — Beta v12.6.14

**50 QML files • 9 shell scripts • 16 themes • Zero GTK/Python dependencies**

### What's New in v6.14 (Bugfix)

- **Tooltip fix** — SysRow hover tooltip now uses `PopupWindow` (same as Taskbar), aligns directly above each icon in all bar modes
- **SwayNC position fix** — Settings → Notifications position changes now actually apply
- **Process reuse fix** — Rapid settings clicks no longer silently ignored
- **Better daemon restart** — SIGTERM-first sequence for clean Wayland teardown

### What's New in v6.13 (Control Panel + SysRow)

- **Control Panel** (Super+C) — Draggable quick settings: PipeWire volume, WiFi/BT/LAN toggles, CPU/GPU/RAM stats
- **ConnectivityService** — Pure QML singleton polling WiFi/BT/Audio/LAN every 3s via nmcli, bluetoothctl, wpctl
- **SysRow** — Waybar-style expandable system tray with colored icons (Sound, CPU, RAM, Temp, Network, Bluetooth)
- **Calendar popup** — Click clock → month grid with navigation
- **Notifications settings** — SwayNC position grid (6 positions) with live preview
- **Rice export/import** — Save/load full config as JSON

---

## What Changed — The QML Rewrite

The old Zenith was a Frankenstein:

| Component | Old Stack | New Stack |
|---|---|---|
| Bar / Panel | Waybar (JSON + CSS) | **QML** (Bar.qml + modules) |
| Desktop Widgets | Python GTK4 + Layer Shell | **QML** (DesktopWidgets.qml) |
| Settings / Control Center | Python GTK4 + Libadwaita | **QML** (ZenSettings.qml) |
| Start Menu | Python GTK4 | **QML** (StartMenuPanel.qml) |
| Wallpaper Picker | Python GTK4 | **QML** (WallpaperPicker.qml) |
| Theme Engine | Python + JSON + GTK CSS | **QML** (ThemeService.qml) |
| System Monitor | Python psutil | **QML** (SystemMonitorService.qml) |
| Weather | Python requests | **QML** (WeatherService.qml) |
| Control Panel | Python GTK4 | **QML** (ControlPanel.qml) |
| System Tray | Waybar modules | **QML** (SysRow.qml) |
| Connectivity | NetworkManager GUI | **QML** (ConnectivityService.qml) |

## Features

**Control Panel (Super+C)** — *New in v6.13*
- PipeWire volume sliders
- WiFi / Bluetooth / LAN toggle switches
- CPU / GPU / RAM live stats
- Expand arrow for network list + BT devices
- Draggable panel

**System Tray (SysRow)** — *New in v6.13*
- Waybar-style expandable tray with `❮` arrow
- 6 modules: Sound (aqua), CPU (blue), RAM (green), Temp (orange), Network (purple), Bluetooth (yellow)
- Icon + bargraph or icon + text display modes
- Per-module visibility and color customization
- PopupWindow tooltips anchored above each icon

**Desktop Widgets**
- Clock — 120px bold, gradient glow, array-based multi-timezone
- Weather — emoji icons, 7-day forecast, Open-Meteo API (no key needed)
- System Monitor — CPU/GPU/RAM/Network with Canvas sparkline graphs
- All draggable with position persistence

**Bar / Panel**
- 3 modes: Full-width, Floating, Island
- Drag-reorder modules between left/center/right zones
- 11 modules: start, taskbar, workspaces, window title, music, sysrow, tray, notifications, clock, weather, sysmonitor
- Adjustable: height, opacity, radius, border, background override
- Display target: all monitors / primary / specific monitor

**Settings App (Zen Settings)**
- General, Decoration, Animations, Themes, Displays, Panel, Bar Modules, System Tray, Sound & Network, Notifications, Desktop Widgets, Wallpaper
- Live preview for all changes
- Persists to JSON configs

**Themes**
- 16 built-in themes: Tokyo Night, Catppuccin Mocha, Dracula, Gruvbox, Nord, One Dark, Solarized, Everforest, Cyberpunk, Lovelace, Yousai, Arc, Adapta, Navy, Black, Paper
- Custom theme palette editor
- Rice export/import (save full config as JSON)

**Start Menu**
- Windows 11-style with pinned apps + all apps alphabetical list
- Search, right-click context menu, power controls

**Wallpaper**
- swww-powered wallpaper engine
- Visual picker with thumbnails
- Random wallpaper keybind

**Keybind Cheatsheet**
- Super + / to open
- Reads live from Hyprland config files
- 8 color-coded categories

**Screenshots**
- grim + slurp primary, flameshot fallback
- Region, full, clipboard, all-screens modes

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# Checkout the latest beta
git fetch --tags
git checkout beta-v12.6.14

# Run installer
./install.sh
```

## Dependencies

**Required:**
- [Quickshell](https://github.com/quickshell-mirror/quickshell) — QML shell framework
- [Hyprland](https://hyprland.org/) 0.54+ — Wayland compositor
- jq — JSON processor

**Recommended:**
- swww / awww — wallpaper daemon
- grim, slurp, wl-clipboard — screenshots
- flameshot — screenshot GUI
- alacritty — terminal
- thunar — file manager (+ tumbler, ffmpegthumbnailer for thumbnails)
- fuzzel — app launcher
- bottom (btm) — system monitor TUI
- swaync — notification daemon
- nwg-displays, nwg-look — display/GTK config
- blueman — bluetooth manager
- networkmanager (nmcli) — wifi
- wireplumber (wpctl) — audio
- pavucontrol — volume control GUI
- bluez-utils (bluetoothctl) — bluetooth control
- zenity — dialogs

The installer auto-detects missing packages and offers to install via paru > yay > pacman.

---

## Architecture

```
~/.config/quickshell/zen-shell/
├── shell.qml                  # Entry point — bar, overlays, widgets
├── Bar.qml                    # Bottom bar with module loader
├── StartMenu.qml              # Start button module
├── StartMenuPanel.qml         # Start menu overlay (Win11 style)
├── Taskbar.qml                # Running apps taskbar
├── ZenWorkspaces.qml          # Workspace dots/numbers
├── ZenClock.qml               # Bar clock module
├── ZenCalendar.qml            # Calendar popup (click clock)
├── ZenWeather.qml             # Bar weather module
├── ZenSysMonitor.qml          # Bar system monitor module
├── SysRow.qml                 # Expandable system tray
├── SysRowIcon.qml             # Tray icon with PopupWindow tooltip
├── SysRowState.qml            # System tray state persistence
├── ControlPanel.qml           # Quick settings popup (Super+C)
├── ConnectivityService.qml    # WiFi/BT/Audio/LAN poller
├── ConnToggleRow.qml          # Toggle row component
├── StatChip.qml               # Stat display chip
├── DesktopWidgets.qml         # Desktop overlay (clock, weather, sysmon)
├── KeybindCheatsheet.qml      # Keybind reference popup
├── WallpaperPicker.qml        # Wallpaper selection UI
├── WallpaperServiceV5.qml     # swww wallpaper engine
├── WeatherService.qml         # Open-Meteo weather provider
├── SystemMonitorService.qml   # /proc + /sys stats reader
├── ThemeService.qml           # Theme engine + JSON loader
├── ZenSettings.qml            # Settings window shell
├── GeneralPage.qml            # General settings
├── PanelPage.qml              # Panel config + size adjusters
├── PanelState.qml             # Panel state persistence
├── BarModulesPage.qml         # Bar module format config
├── SysRowPage.qml             # System tray settings
├── ConnectivityPage.qml       # Sound & Network settings
├── NotificationPage.qml       # SwayNC notification position
├── AnimationsPage.qml         # Hyprland animation presets
├── ThemesPage.qml             # Theme browser + editor
├── DisplaysPage.qml           # Monitor configuration
├── WidgetsPage.qml            # Desktop widget settings
├── DecorationPage.qml         # Window decoration config
├── AppearancePage.qml         # Legacy GTK appearance
├── WallpaperPage.qml          # Wallpaper settings
├── ZenConstants.qml           # Shared constants
└── ...                        # Helper components (50 QML total)
```

---

## Keybinds

| Key | Action |
|---|---|
| Super + C | Control Panel (quick settings) |
| Super + A | Start Menu |
| Super + , | Zen Settings |
| Super + W | Wallpaper Picker |
| Super + Shift + W | Random Wallpaper |
| Super + / | Keybind Cheatsheet |
| Clock click | Calendar popup |
| Super + T | Terminal |
| Super + E | File Manager |
| Super + D / R | App Launcher |
| Super + Q | Close window |
| Super + F | Maximize |
| Super + G | Toggle floating |
| Super + B | System monitor (btm) |
| Super + 1-0 | Switch workspace |
| Super + Shift + 1-0 | Move window to workspace |
| Super + F12 | Screenshot: region |
| Super + Shift + F12 | Screenshot: full monitor |
| Super + Ctrl + F12 | Screenshot: all screens |
| Super + Alt + F12 | Flameshot GUI |

---

## Changelogs

- [v6.14 — Tooltip PopupWindow Rewrite + SwayNC Position Fix](CHANGELOG-v6.14.md)
- [v6.13 — Control Panel + SysRow + Calendar + Rice Export](CHANGELOG-v6.13.md)
- [v6.12 — Settings Drag + Display Target + Taskbar Context Menu](CHANGELOG-v6.12.md)
- [v6.11 — Panel Island Mode + Start Menu Rewrite](CHANGELOG-v6.11.md)
- [v6.10 — Bar Module Reorder + Desktop Widgets](CHANGELOG-v6.10.md)
- [v6.9 — Taskbar + Screenshot System](CHANGELOG-v6.9.md)
- [v6.6 — Theme Engine + SwayNC CSS](CHANGELOG-v6.6.md)

---

## Upcoming — Priority 3

Next development phase focuses on enhancements and polish:

- [ ] **Integrate alpha WiFi/BT logic → QML** — Full NetworkManager integration (connect/disconnect/forget networks, BT pairing) directly in ConnectivityPage, replacing nmtui/blueman-manager shells
- [ ] **Media player widget** — MPRIS integration for Spotify/Firefox/etc in bar and Control Panel
- [ ] **Notification history** — SwayNC notification log viewer in Settings
- [ ] **App drawer grid** — Grid view option for Start Menu all-apps list
- [ ] **Multi-monitor widget placement** — Per-monitor desktop widget positions
- [ ] **Theme import from URL** — Paste a theme JSON URL to install
- [ ] **Bar auto-hide** — Hide bar on fullscreen or after timeout
- [ ] **Lock screen** — QML lock screen with clock + wallpaper blur
- [ ] **OSD overlays** — Volume/brightness on-screen display popups

---

## Platform

- **OS:** Arch Linux / CachyOS
- **Compositor:** Hyprland 0.54+
- **Shell Framework:** Quickshell
- **Language:** QML / JavaScript
- **Hardware tested:** AMD Ryzen 9 5950X + RX 6800 XT, 128GB RAM

## License

MIT

## Author

**Zenpy** ([@Gekinzen](https://github.com/Gekinzen))
