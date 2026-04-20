<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/desktoplooks.png" alt="Zen Shell Desktop Preview" width="950"/>
</p>

<h1 align="center">Zen Shell</h1>

<p align="center">
  <b>A Quickshell-native desktop environment for Hyprland.</b><br/>
  <i>Control everything. Theme everything. Break nothing.</i>
</p>

<p align="center">
  <a href="#-overview">Overview</a> •
  <a href="#-live-demo">Demo</a> •
  <a href="#-screenshots">Screenshots</a> •
  <a href="#-whats-new">What's New</a> •
  <a href="#-features">Features</a> •
  <a href="#-installation">Install</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-changelogs">Changelogs</a> •
  <a href="#-credits">Credits</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v6.15.13-brightgreen"/>
  <img src="https://img.shields.io/badge/Arch-Linux-1793D1?logo=arch-linux&logoColor=white"/>
  <img src="https://img.shields.io/badge/Hyprland-0.54+-58E1FF?logo=wayland&logoColor=white"/>
  <img src="https://img.shields.io/badge/Quickshell-QML-4A86CF"/>
  <img src="https://img.shields.io/badge/Status-Beta-orange"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

---

# 🚀 Overview

**Zen Shell** (formerly "Zenith" / "Zen Barebone Alpha") is a complete
desktop shell built entirely in QML using
[Quickshell](https://github.com/quickshell-mirror/quickshell) —
replacing the previous mixed stack of GTK4/Libadwaita, Python, C++,
and Waybar with a unified, lightweight QML architecture.

It is not just a Hyprland configuration.
It is a structured, modular desktop ecosystem built around:

- ⚡ Performance-first configuration
- 🎨 Unified cross-application theming
- 🧩 GUI-driven customization without sacrificing power
- 🎵 Audio-reactive music visualizer (new in v6.15)
- 📸 Physics-simulated screenshot rope overlay (new in v6.15)

Everything is synchronized.
Switch one setting — the entire desktop updates.

> **The legacy Python/GTK4 alpha is preserved at
> [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52)**
> for historical reference. Active development targets the QML rewrite
> shipped in this branch.

---

# 🎬 Live Demo

<p align="center">
  <a href="https://www.youtube.com/watch?v=YQxrh5_naMQ">
    <img src="https://img.youtube.com/vi/YQxrh5_naMQ/maxresdefault.jpg" alt="Zen Shell — Full Demo" width="850"/>
  </a>
</p>

<p align="center">
  <b>▶️ Watch the full Zen Shell demo on YouTube</b><br/>
  <i>Theme switching, panel modes, system tray, control panel,
  desktop widgets, and more — all in action.</i>
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=rWz8_Hk6-0U">
    <img src="https://img.youtube.com/vi/rWz8_Hk6-0U/maxresdefault.jpg" alt="I Built a Control Center for Hyprland" width="850"/>
  </a>
</p>

<p align="center">
  <b>▶️ I Built a Control Center for Hyprland — Arch Linux Dotfiles</b><br/>
  <i>Deep dive into the control center, theming engine, and dotfiles
  workflow.</i>
</p>

---

# 📸 Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/main.gif" alt="Zen Shell Main Demo" width="850"/>
</p>

## 🎨 Theme Switching
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/theming.gif" alt="Theme Switching" width="850"/>
</p>

## 🖥 Desktop Looks
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/desktoplooks.png" alt="Desktop Looks" width="850"/>
</p>

## 🚀 Dock / Taskbar
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/dock.png" alt="Dock" width="850"/>
</p>

## 🎛 Panel Modes
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/paneldemo.gif" alt="Panel Modes" width="850"/>
</p>

## 🖼 Wallpaper Picker
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/changewallpaper.gif" alt="Wallpaper Switching" width="850"/>
</p>

## 🎛 Control Panel
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/hyprcontrolcenter.png" alt="Control Panel" width="850"/>
</p>

## 🎨 Settings / Appearance
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/hyprlandappearance.png" alt="Settings - Appearance" width="850"/>
</p>

## 🎞 Animation Editor
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/hyprcontrolcenteranimation.png" alt="Animation Editor" width="850"/>
</p>

## 🎨 Theme Engine
<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/zen_barebone_alpha_development/main/demo/theming.png" alt="Theme Engine" width="850"/>
</p>

> *Music-string visualizer and screenshot-rope GIFs will be added as
> soon as new recordings are captured on v6.15.13.*

---

# ✨ What's New in v6.15.x

The v6.15 series was a large feature release followed by a long tail
of hardening patches (v6.15.1 → v6.15.13). Summary of everything
added relative to v6.14.2:

### 🎵 Music Strings Module
An audio-reactive bezier visualizer that replaces the music module
in the bar when enabled via **Settings → General → Strings**. Beat
data comes from `cava`, track metadata from `playerctl`. Hovering
the strings shows an Artist — Title tooltip. Curves bow freely above
and below the bar slot via a dedicated `WlrLayer.Overlay` panel
window.

### 📸 Screenshot Ropes
`Super+Shift+S` opens a region-screenshot overlay with physics-
simulated ropes draped from the screen corners. Drag to select a
region; the toolbar appears with copy / save / annotate actions.
The copy path is `wl-copy`-backed with `setsid` detachment so
clipboard ownership survives the helper script exiting. Pasting into
any app produces the JPEG immediately.

### 🛠 Complete SettingsStateV2 Coverage
The previous implementation of `applyToHyprland()` was missing
roughly 20 Hyprland keywords (all snap properties, most blur/shadow
secondaries, `dim_special`). These are now all persisted correctly
— no more "snap gaps reset when I change themes" surprises.

### 🛡 Robust Layout Handling
Eight iterative improvements for music-string positioning across
panel mode transitions (Fullwidth ↔ Floating ↔ Island), culminating
in:

- `QQuickLayout.forceLayout()` — synchronous layout passes during
  transitions eliminate Qt's async RowLayout propagation issue
- `zs-restart.sh` — a selective shell respawn helper for the one
  corner case (Float/FW → Island) that even `forceLayout()` couldn't
  solve from the QML layer

### 🚀 Bootstrap Flag
`./install.sh --bootstrap` now supports fresh Arch-based laptops
(safe to run on systems currently running KDE, GNOME, or COSMIC —
does NOT touch the display manager, does NOT change the default
session, does NOT remove any existing DE). Installs Hyprland +
Quickshell + all dependencies in four tiers and creates a Wayland
session entry so Hyprland becomes selectable from the existing
login screen.

### 🎯 Hyprland 0.54+ Syntax Compatibility
All bundled configs updated to the new syntax:
- `windowrulev2` → `windowrule = prop val, match:key regex`
- `layerrule = blur, ns` → `layerrule = blur on, match:namespace ns`
- `layerrule = noanim` → `layerrule = no_anim on, match:namespace ns`
- Trailing commas removed from all `bind = ...` lines

Full per-patch details are in
[`CHANGELOG-v6.15.x.md`](CHANGELOG-v6.15.x.md) (consolidated) or the
individual `CHANGELOG-v6.15.<n>.md` files.

---

# ✨ Features

## 🎵 Music Strings (v6.15+)
*New in this series.* Audio-reactive bezier curve visualizer.
- Replaces the music module when enabled
- `cava` drives the beat amplitude
- `playerctl` drives artist/title tooltip
- Floating overlay panel — curves bow above and below the bar slot
  without being clipped by the bar's layer-shell surface
- Color modes: theme (auto blue → purple), synced (follows accent),
  custom (two color pickers)
- Loading placeholder with pulsing dot while the bar layout settles
- Toggleable and fully configurable in **Settings → General → Strings**

## 📸 Screenshot Rope Overlay (v6.15+)
*New in this series.* `Super+Shift+S` → region screenshot with
physics-draped rope ornaments.
- 10-segment ropes with tuned gravity / inertia / spring force
- `grim` + `slurp` primary with `flameshot` fallback
- `wl-copy` integration with `setsid` detachment — paste works
  reliably on the first try
- Multi-monitor: rope appears on the monitor where the cursor is
- Toggleable in **Settings → General → Strings → Screenshot ropes**

## 🎛 Control Panel (Super+C)
- PipeWire volume sliders
- WiFi / Bluetooth / LAN toggle switches
- CPU / GPU / RAM live stats
- Expand arrow for network list + BT devices
- Draggable panel

## 🖥 System Tray (SysRow)
- Waybar-style expandable tray with `❮` arrow
- 6 modules: Sound, CPU, RAM, Temp, Network, Bluetooth
- Icon + bargraph or icon + text display modes
- Per-module visibility and color customization
- PopupWindow tooltips anchored above each icon

## 🖼 Desktop Widgets
- **Clock** — 120px bold, gradient glow, multi-timezone array
- **Weather** — emoji icons, 7-day forecast, Open-Meteo (no API key)
- **System Monitor** — CPU/GPU/RAM/Network with Canvas sparklines
- All draggable with per-monitor position persistence

## 🎚 Bar / Panel
- 3 modes: **Full-width**, **Floating**, **Island**
- Drag-reorder modules between left/center/right zones
- 11 modules: start, taskbar, workspaces, window title, music,
  sysrow, tray, notifications, clock, weather, sysmonitor
- Adjustable: height, opacity, radius, border, background override
- Display target: all monitors / primary / specific monitor

## ⚙ Settings App (Zen Settings)
Pages: General, Decoration, Animations, Themes, Displays, Panel,
Bar Modules, System Tray, Sound & Network, Notifications, Desktop
Widgets, Wallpaper.
- Live preview for all changes
- Persists to JSON
- Revert buttons on every section

## 🎨 Unified Theming System
17 built-in themes auto-synchronize across Quickshell bar, Settings
app, Control Panel, SwayNC notifications, Alacritty terminal, and
Fuzzel launcher.

One Dark • Gruvbox • Nord • Tokyo Night • Catppuccin Mocha • Dracula
• Solarized Dark • Everforest Dark • Cyberpunk • Lovelace • Yousai
• Arc • Adapta • Navy • Black • Paper • Adapta

- Custom theme palette editor
- Rice export/import (save full desktop config as a JSON file)

## 🚀 Start Menu (Super+A)
- Win11-style with pinned apps + alphabetical all-apps
- Real-time search
- Right-click context menu
- Integrated power controls

## 🖼 Wallpaper
- `swww`-powered engine with transition effects
- Visual picker with thumbnails (`Super+W`)
- Random wallpaper (`Super+Shift+W`)

## ⌨️ Keybind Cheatsheet (Super+/)
- Reads live from Hyprland config
- 8 color-coded categories

---

# 🎯 Quick Start

## Fresh Arch-based laptop (KDE / GNOME / COSMIC safe)

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# Check out the latest release (either approach works):
git fetch --tags
git checkout v6.15.13         # pin to exact release
#   — or —
git checkout main             # always the latest commit (may contain
                              #   in-progress work)

chmod +x install.sh
./install.sh --bootstrap
```

The `--bootstrap` flag installs Hyprland, Quickshell, and all
dependencies without touching your current desktop environment.
You can log out, select Hyprland from your login screen's session
picker, and switch back to your previous DE any time.

## Hyprland already installed

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# Check out the latest release (either approach works):
git fetch --tags
git checkout v6.15.13         # pin to exact release
#   — or —
git checkout main             # always the latest commit (may contain
                              #   in-progress work)

chmod +x install.sh
./install.sh
```

## Backup first (recommended)

```bash
mv ~/.config/hypr      ~/.config/hypr.backup      2>/dev/null || true
mv ~/.config/quickshell ~/.config/quickshell.backup 2>/dev/null || true
```

---

# 📦 Dependencies

**Required:**
- [Quickshell](https://github.com/quickshell-mirror/quickshell) 0.2.1+ — QML shell framework
- [Hyprland](https://hyprland.org/) 0.54+ — Wayland compositor
- `jq` — JSON processor

**Recommended (most auto-installed by `--bootstrap`):**
- `swww` — wallpaper daemon
- `grim`, `slurp`, `wl-clipboard` — screenshots
- `flameshot` — screenshot GUI fallback
- `cava` — beat-reactive visualizer (Music Strings)
- `playerctl` — track metadata (Music Strings)
- `alacritty` — terminal
- `thunar` — file manager
- `fuzzel` — app launcher
- `bottom` (btm) — system monitor TUI
- `swaync` — notification daemon
- `nwg-displays`, `nwg-look` — display / GTK config
- `blueman`, `networkmanager`, `wireplumber`, `pavucontrol`
- `zenity` — dialogs

The installer auto-detects missing packages and offers to install
via `paru` > `yay` > `pacman`.

---

# 🏗 Architecture

```
~/.config/quickshell/zen-shell/
├── shell.qml                  # Entry point — bar, overlays, widgets
├── Bar.qml                    # Bottom bar with module loader
├── MusicStrings.qml           # Music slot placeholder (v6.15+)
├── ZenStrings.qml             # Audio-reactive visualizer (v6.15+)
├── ZenStringsState.qml        # Shared strings state singleton
├── ZenRope.qml                # Physics rope (v6.15+)
├── ZenScreenshotOverlay.qml   # Region screenshot + ropes
├── ZenAnnotationToolbar.qml   # Screenshot toolbar
├── StartMenu.qml / StartMenuPanel.qml
├── Taskbar.qml / ZenWorkspaces.qml
├── ZenClock.qml / ZenCalendar.qml
├── ZenWeather.qml / ZenSysMonitor.qml
├── SysRow.qml / SysRowIcon.qml / SysRowState.qml
├── ControlPanel.qml / ConnectivityService.qml / ConnToggleRow.qml / StatChip.qml
├── DesktopWidgets.qml / KeybindCheatsheet.qml
├── WallpaperPicker.qml / WallpaperServiceV5.qml
├── WeatherService.qml / SystemMonitorService.qml
├── ThemeService.qml
├── ZenSettings.qml            # Settings window shell
├── GeneralPage.qml / PanelPage.qml / PanelState.qml
├── BarModulesPage.qml / SysRowPage.qml / ConnectivityPage.qml
├── NotificationPage.qml / AnimationsPage.qml / ThemesPage.qml
├── DisplaysPage.qml / WidgetsPage.qml / DecorationPage.qml
├── AppearancePage.qml / WallpaperPage.qml
├── SettingsStateV2.qml        # Full Hyprland state persistence
└── ...                        # ~55 QML files total

~/.local/bin/
├── zen-cava.sh                # cava wrapper
├── zen-screenshot.sh          # Screenshot pipeline
├── zs-restart.sh              # Selective nuclear restart (v6.15.12+)
├── regen-terminal-themes.sh   # Alacritty / Fuzzel theme sync
├── regen-swaync-theme.sh      # SwayNC theme sync
└── ...                        # Other helpers
```

### Strings architecture

```
barWindow (WlrLayer.Top, namespace zen-shell-bar)
└── Bar.qml
    └── musicSlotItem (in RowLayout)
        └── Loader
            ├── MusicWidget.qml       (when strings disabled)
            └── MusicStrings.qml      (when strings enabled)
                ├── playerctl polling
                ├── zen-cava.sh process
                ├── Loading placeholder (while layout settles)
                └── Hover tooltip

stringsWindow (WlrLayer.Overlay, namespace zen-shell-strings)
└── ZenStrings.qml
    margins.left = barWindowLeft + musicSlotLocalX
    implicitWidth = musicSlotLocalWidth
    implicitHeight = barHeight + 2 × verticalPadding
        ↑ 60px overflow above/below so curves bow freely
```

---

# ⌨️ Keybinds

| Keybind | Action |
|---|---|
| `Super + C` | Control Panel |
| `Super + A` | Start Menu |
| `Super + ,` | Zen Settings |
| `Super + W` | Wallpaper Picker |
| `Super + Shift + W` | Random Wallpaper |
| `Super + /` | Keybind Cheatsheet |
| **`Super + Shift + S`** | **Screenshot rope overlay (v6.15+)** |
| `Super + Alt + S` | Toggle bar style (round ↔ pill) |
| Clock click | Calendar popup |
| `Super + T` | Terminal |
| `Super + E` | File Manager |
| `Super + D` / `Super + R` | App Launcher |
| `Super + Q` | Close window |
| `Super + F` | Maximize |
| `Super + G` | Toggle floating |
| `Super + B` | System monitor (btm) |
| `Super + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | Move window to workspace |
| `Super + F12` | Screenshot: region (legacy) |
| `Super + Shift + F12` | Screenshot: full monitor |
| `Super + Ctrl + F12` | Screenshot: all screens |
| `Super + Alt + F12` | Flameshot GUI |

---

# 📝 Changelogs

- **[v6.15.x consolidated](CHANGELOG-v6.15.x.md)** — Overall
  summary of the entire v6.15 series
- [v6.15.13 — Install automation polish (current)](CHANGELOG-v6.15.13.md)
- [v6.15.12 — Nuclear restart self-suicide fix](CHANGELOG-v6.15.12.md)
- [v6.15.11 — Nuclear respawn command correction](CHANGELOG-v6.15.11.md)
- [v6.15.10 — Nuclear shell respawn for Float/FW → Island](CHANGELOG-v6.15.10.md)
- [v6.15.9 — `RowLayout.forceLayout()` synchronous layout](CHANGELOG-v6.15.9.md)
- [v6.15.8 — Stable-read verification](CHANGELOG-v6.15.8.md)
- [v6.15.7 — Rapid mode cycling lockout](CHANGELOG-v6.15.7.md)
- [v6.15.6 — Theme reload + panel mode transition fixes](CHANGELOG-v6.15.6.md)
- [v6.15.5 — Smooth runtime transitions](CHANGELOG-v6.15.5.md)
- [v6.15.4 — Layout-stuck position + tooltip anchor](CHANGELOG-v6.15.4.md)
- [v6.15.3 — Loading loop fix + clock jitter](CHANGELOG-v6.15.3.md)
- [v6.15.2 — Music string position live-update + Loading placeholder](CHANGELOG-v6.15.2.md)
- [v6.15.1 — Screenshot clipboard + rope physics](CHANGELOG-v6.15.1.md)
- [v6.15 — Music module → ZenStrings + screenshot ropes](CHANGELOG-v6.15.md)

---

# 🙏 Credits

## Inspired By

The **Music Strings visualizer** and the **Screenshot Rope overlay**
in v6.15+ are heavily inspired by
[flickowoa's Zephyr dotfiles](https://github.com/flickowoa/dotfiles/tree/hyprland-zephyr)
([demo video](https://www.youtube.com/watch?v=7Miis9I25q4)).

The original Zephyr dotfiles provided the initial concept and physics
tuning reference (10-segment ropes, short segment length for natural
catenary drape, softer gravity/damping values). Zen Shell's
implementation builds on that foundation with:

- Full QML-native integration — no external Python daemons or helpers
- Clipboard-integrated screenshot capture (paste works reliably on
  the first try via `setsid`-detached `wl-copy`)
- String module toggle integrated with Zen Shell's Settings app
  (can be enabled/disabled in **General → Strings** without editing
  any config files)
- Beat data from `cava` driving the bezier curve amplitude in
  real-time
- Multi-monitor awareness for both the strings and the screenshot
  ropes
- Panel-mode-aware positioning (Fullwidth / Floating / Island)

Huge thanks to **[flickowoa](https://github.com/flickowoa)** for the
original design language.

## Built With

- **[Quickshell](https://github.com/quickshell-mirror/quickshell)** —
  the QML shell framework this entire project is built on
- **[Hyprland](https://hyprland.org/)** — the Wayland compositor
- **Qt 6 / QML** — declarative UI + runtime

---

# 🌐 Platform

- **OS:** Arch Linux / CachyOS
- **Compositor:** Hyprland 0.54+
- **Shell Framework:** Quickshell
- **Language:** QML / JavaScript
- **Hardware tested:** AMD Ryzen 9 5950X + RX 6800 XT, 128GB RAM

---

# 🛣 Roadmap

Zen Shell is actively developed. This is a personal project I enjoy
working on and learn a lot from — so expect continuous iteration
rather than a "finished" state.

## 🎯 Next phase (in progress)

Reimplementing features from the legacy Python/GTK4 alpha (now
preserved at
[`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52))
as native QML modules in Zen Shell:

- [ ] **Start Menu logo customization** — let users swap the Arch
      logo button for their own image / SVG via Settings → Panel →
      Start Button
- [ ] **Notification volume OSD** — on-screen overlay that pops up
      briefly when the user changes volume (keyboard media keys /
      wpctl), synced with the current theme
- [ ] **Alt+Tab window switcher** — in-QML window-switcher overlay
      with app icon + title preview, replacing Hyprland's default
      cycle-next binding
- [ ] **Import user photo** — personalize the Start Menu header with
      a user avatar (file picker + automatic crop to circle)
- [ ] **Other fixes** — ongoing polish from real-world usage

## Longer-term ideas

- [ ] Integrate WiFi/BT logic directly in `ConnectivityPage` (connect /
      disconnect / forget networks, BT pairing) — replacing the
      current `nmtui` / `blueman-manager` shell-outs
- [ ] Media player widget — MPRIS in bar + Control Panel
- [ ] Notification history — SwayNC notification log viewer
- [ ] App drawer grid — grid view option for Start Menu all-apps
- [ ] Multi-monitor widget placement — per-monitor desktop widget
      positions
- [ ] Theme import from URL
- [ ] Bar auto-hide — hide bar on fullscreen or after timeout
- [ ] Lock screen — QML lock with clock + wallpaper blur
- [ ] More OSD overlays — brightness, keyboard layout, caps lock

---

# 🤝 Contributing

You can help by:

- Reporting bugs
- Suggesting features
- Submitting pull requests
- Sharing themes
- Improving documentation

Open an issue on
[GitHub](https://github.com/Gekinzen/zen_barebone_alpha_development/issues)
or jump straight to a PR.

---

# ⭐ If You Like This Project

Consider starring the repository to support development and help
others discover it.

---

# ☕ Support

If you find this project useful and want to support its development,
any contribution is truly appreciated!

<p align="center">
  <a href="https://buymeacoffee.com/zenpy">
    <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black"/>
  </a>
</p>

You can also support via crypto:

| Currency | Address |
|----------|---------|
| **BTC** (Bitcoin) | `12Wo7KT9uqKzfZ15ZLugg7yyb3AfsmEVTc` |
| **BCH** (Bitcoin Cash) | `1EBooTk9TuGBEn9bMkQoSs6yAjbCKd2TqQ` |
| **SOL** (Solana) | `2FUpxNPHgAJ7r3VpRWxBJNMFoayoZWeFNV6tVsMPe5QR` |

---

# 📜 License

MIT License

---

<p align="center">
Made with ❤️ by <a href="https://github.com/Gekinzen">Zenpy</a>
</p>
