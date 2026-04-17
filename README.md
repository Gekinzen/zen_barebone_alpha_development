# Zen Barebone Alpha

**A Quickshell-native desktop environment for Hyprland.**

Zen Shell (formerly "Zenith") is a complete desktop shell built entirely in QML using [Quickshell](https://github.com/quickshell-mirror/quickshell) — replacing the previous mixed stack of GTK4/Libadwaita, Python, C++, and Waybar with a unified, lightweight QML architecture.

![Zen Shell Desktop](https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/preview.png)

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
| Animations | Hyprland conf only | **QML** (AnimationsPage.qml) |
| Keybind Cheatsheet | None | **QML** (KeybindCheatsheet.qml) |

**Now it's 39 QML files + 8 shell scripts.** No Waybar. No GTK4. No psutil. No C++ widgets. Just QML + Quickshell + a bit of Python for the legacy GTK control center (optional).

## Features

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
- Start button icon size slider
- Workspace dot + font size sliders
- Display target: all monitors / primary / specific monitor

**Settings App (Zen Settings)**
- General, Decoration, Animations, Themes, Displays, Panel, Bar Modules, Desktop Widgets, Wallpaper, Appearance
- Live preview for all changes
- Persists to JSON configs

**Themes**
- 16 built-in themes: Tokyo Night, Catppuccin Mocha, Dracula, Gruvbox, Nord, One Dark, Solarized, Everforest, Cyberpunk, Lovelace, Yousai, Arc, Adapta, Navy, Black, Paper
- Custom theme palette editor
- Hot-reload via keybind

**Start Menu**
- Windows 11-style with pinned apps + all apps alphabetical list
- Search, right-click context menu, power controls
- Dynamic positioning (follows bar mode)

**Wallpaper**
- swww-powered wallpaper engine
- Visual picker with thumbnails
- Random wallpaper keybind
- Multi-session support (COSMIC/Hyprland/dwl)

**Keybind Cheatsheet**
- Super + / to open
- Reads live from Hyprland config files
- Smart-detects what each bind does
- 8 color-coded categories

**Screenshots**
- grim + slurp primary, flameshot fallback
- Active monitor detection
- Region, full, clipboard, all-screens, flameshot modes

## Quick Start

```bash
# Clone the repo
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# Checkout the latest beta
git fetch --tags
git checkout Tag-Beta-V12-15-2026-04-18
git checkout -b beta-v12-clean

# Run installer
./install.sh
```

Or curl directly:

```bash
curl -L https://github.com/Gekinzen/zen_barebone_alpha_development/archive/refs/tags/Tag-Beta-V12-15-2026-04-18.tar.gz | tar -xz
cd zen_barebone_alpha_development-Tag-Beta-V12-15-2026-04-18
./install.sh
```

## Dependencies

**Required:**
- [Quickshell](https://github.com/quickshell-mirror/quickshell) — QML shell framework
- [Hyprland](https://hyprland.org/) — Wayland compositor
- jq — JSON processor

**Recommended:**
- swww / awww — wallpaper daemon
- grim, slurp, wl-clipboard — screenshots
- flameshot — screenshot GUI
- kitty — terminal
- thunar — file manager (+ tumbler, ffmpegthumbnailer for thumbnails)
- fuzzel — app launcher
- bottom (btm) — system monitor TUI
- swaync — notification daemon
- nwg-displays, nwg-look — display/GTK config
- alacritty — alternate terminal
- blueman — bluetooth
- networkmanager — wifi
- zenity — dialogs

The installer auto-detects missing packages and offers to install via paru > yay > pacman.

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
├── ZenWeather.qml             # Bar weather module
├── ZenSysMonitor.qml          # Bar system monitor module
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
├── AnimationsPage.qml         # Hyprland animation presets
├── ThemesPage.qml             # Theme browser + editor
├── DisplaysPage.qml           # Monitor configuration
├── BarModulesPage.qml         # Bar module format config
├── WidgetsPage.qml            # Desktop widget settings
├── DecorationPage.qml         # Window decoration config
├── AppearancePage.qml         # Legacy GTK appearance
├── WallpaperPage.qml          # Wallpaper settings
├── ZenConstants.qml           # Shared constants
└── ...                        # Helper components
```

```
~/.config/hypr/
├── modules/binds.conf                         # Core keybinds
└── hyprland.conf                              # Sources zen-shell configs
```

```
~/.config/quickshell/zen-shell/config/
├── keybinds-update.conf       # Zen Shell keybinds
└── hyprland-layer-rules.conf  # Layer rules for overlays
```

## Keybinds

| Key | Action |
|---|---|
| Super + A | Start Menu |
| Super + , | Zen Settings |
| Super + W | Wallpaper Picker |
| Super + Shift + W | Random Wallpaper |
| Super + / | Keybind Cheatsheet |
| Super + T | Kitty terminal |
| Super + E | Thunar |
| Super + D / R | Fuzzel launcher |
| Super + Q | Close window |
| Super + F | Maximize |
| Super + G | Toggle floating |
| Super + B | System monitor (btm) |
| Super + 1-0 | Switch workspace |
| Super + Shift + 1-0 | Move window to workspace |
| Super + F12 | Screenshot: region select |
| Super + Shift + F12 | Screenshot: full monitor |
| Super + Ctrl + F12 | Screenshot: all screens |
| Super + Alt + F12 | Flameshot GUI |
| Super + Shift + T | Cycle theme |
| Super + Shift + S | Toggle round/pill |
| Super + Shift + L | Lock screen |
| Super + Shift + X | Logout |

## Platform

- **OS:** Arch Linux / CachyOS
- **Compositor:** Hyprland
- **Shell Framework:** Quickshell
- **Language:** QML / JavaScript
- **Hardware tested:** AMD Ryzen 9 5950X + RX 6800 XT, 128GB RAM, dual 4K monitors

## License

MIT

## Author

**Paul Hansen Yuki** ([@Gekinzen](https://github.com/Gekinzen))
