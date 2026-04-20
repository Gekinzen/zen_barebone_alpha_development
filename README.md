<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png" alt="Zen Shell — v6.15.13" width="960"/>
</p>

<h1 align="center" style="letter-spacing:-0.02em;">Zen&nbsp;Shell</h1>

<p align="center">
  <sub><b>A QUICKSHELL-NATIVE DESKTOP ENVIRONMENT FOR HYPRLAND</b></sub>
</p>

<p align="center">
  <i>Control everything. Theme everything. Break nothing.</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/v6.15.13-0a0a0a?style=flat-square"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Arch%20Linux-1a1a1a?style=flat-square&logo=arch-linux&logoColor=white"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Hyprland%200.54%2B-1a1a1a?style=flat-square&logo=wayland&logoColor=white"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Quickshell%20QML-1a1a1a?style=flat-square"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Beta-1a1a1a?style=flat-square"/>
  &nbsp;
  <img src="https://img.shields.io/badge/MIT-1a1a1a?style=flat-square"/>
</p>

<p align="center">
  <img src="https://img.shields.io/github/last-commit/Gekinzen/zen_barebone_alpha_development?style=flat-square&label=last%20commit&color=1a1a1a&labelColor=0a0a0a"/>
  &nbsp;
  <img src="https://img.shields.io/github/issues/Gekinzen/zen_barebone_alpha_development?style=flat-square&color=1a1a1a&labelColor=0a0a0a"/>
  &nbsp;
  <img src="https://img.shields.io/github/stars/Gekinzen/zen_barebone_alpha_development?style=flat-square&color=1a1a1a&labelColor=0a0a0a"/>
  &nbsp;
  <img src="https://img.shields.io/github/forks/Gekinzen/zen_barebone_alpha_development?style=flat-square&color=1a1a1a&labelColor=0a0a0a"/>
</p>

<p align="center">
  <a href="#overview">Overview</a>
  &nbsp;·&nbsp;
  <a href="#demos">Demos</a>
  &nbsp;·&nbsp;
  <a href="#showcase">Showcase</a>
  &nbsp;·&nbsp;
  <a href="#whats-new-in-v615x">What's New</a>
  &nbsp;·&nbsp;
  <a href="#features">Features</a>
  &nbsp;·&nbsp;
  <a href="#quick-start">Install</a>
  &nbsp;·&nbsp;
  <a href="#architecture">Architecture</a>
  &nbsp;·&nbsp;
  <a href="#wallpapers">Wallpapers</a>
  &nbsp;·&nbsp;
  <a href="#changelogs">Changelogs</a>
  &nbsp;·&nbsp;
  <a href="#faq">FAQ</a>
  &nbsp;·&nbsp;
  <a href="#legacy-archive--2025-alpha">Archive</a>
  &nbsp;·&nbsp;
  <a href="#credits">Credits</a>
</p>

<br/>

---

<br/>

## Overview

**Zen Shell** (formerly *Zenith* / *Zen Barebone Alpha*) is a complete desktop shell built entirely in QML using [Quickshell](https://github.com/quickshell-mirror/quickshell) — replacing the previous mixed stack of GTK4/Libadwaita, Python, C++, and Waybar with a unified, lightweight QML architecture.

It is not just a Hyprland configuration. It is a structured, modular desktop ecosystem built around:

<br/>

<table align="center">
<tr>
<td align="center" width="33%">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/bolt.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/bolt.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Performance-first</b>
<br/><sub>Lean QML runtime</sub>
</td>
<td align="center" width="33%">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/palette-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/palette-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Unified theming</b>
<br/><sub>One switch, whole desktop</sub>
</td>
<td align="center" width="33%">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/tune.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/tune.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>GUI-driven</b>
<br/><sub>No config files required</sub>
</td>
</tr>
<tr>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/graphic-eq.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/graphic-eq.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Music Strings</b>
<br/><sub>Audio-reactive bezier — v6.15</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/screenshot-region.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/screenshot-region.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Screenshot Ropes</b>
<br/><sub>Physics overlay — v6.15</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/sync.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/sync.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>State-synchronized</b>
<br/><sub>Change one, update all</sub>
</td>
</tr>
</table>

<br/>

> The legacy Python/GTK4 alpha is preserved at [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52) for historical reference. Active development targets the QML rewrite shipped in this branch.

<br/>

---

<br/>

## Demos

<p align="center">
  <a href="https://www.youtube.com/watch?v=dNwGRBhA97g">
    <img src="https://img.youtube.com/vi/dNwGRBhA97g/maxresdefault.jpg" alt="Zen Shell v6.15.13 — Full Tour" width="880"/>
  </a>
</p>

<p align="center">
  <sub>CURRENT RELEASE</sub><br/>
  <b>Zen Shell v6.15.13 — Full Tour</b><br/>
  <i>Strings music module, screenshot ropes, settings, and the complete desktop experience.</i>
</p>

<br/>

<table align="center">
<tr>
<td align="center" width="50%">
<a href="https://www.youtube.com/watch?v=YQxrh5_naMQ">
  <img src="https://img.youtube.com/vi/YQxrh5_naMQ/maxresdefault.jpg" alt="Zen Shell v6.14" width="420"/>
</a>
<br/>
<sub>PREVIOUS SERIES</sub>
<br/>
<b>Zen Shell v6.14</b>
<br/>
<i>Theme switching, panel modes, control center.</i>
</td>
<td align="center" width="50%">
<a href="https://www.youtube.com/watch?v=ao89J3DEqiA">
  <img src="https://img.youtube.com/vi/ao89J3DEqiA/maxresdefault.jpg" alt="Zen Shell v6.10 — QML Foundations" width="420"/>
</a>
<br/>
<sub>QML FOUNDATIONS</sub>
<br/>
<b>Zen Shell v6.10</b>
<br/>
<i>The fresh QML rewrite — where the new stack began.</i>
</td>
</tr>
</table>

<br/>

---

<br/>

## Showcase

<p align="center">
  <i>Zen Shell v6.15.13 — captured on Hyprland 0.54, Quickshell 0.2.1.</i>
</p>

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png" alt="Desktop preview" width="920"/>
</p>

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png" alt="Desktop preview" width="920"/>
</p>

<br/>

### Adaptive theming

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_01_adaptive_theming.gif" alt="Adaptive theming" width="920"/>
</p>

<p align="center">
  <sub>One palette. Every surface — bar, settings, control panel, notifications, terminal, launcher.</sub>
</p>

<br/>

### Settings tour

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_02_settings_tour.gif" alt="Settings tour" width="920"/>
</p>

<p align="center">
  <sub>Thirteen pages of live-preview configuration. No config files. No restart.</sub>
</p>

<br/>

### Screenshot module · ultrawide

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_03_screenshot_module_ultrawide.gif" alt="Screenshot module on ultrawide" width="920"/>
</p>

<p align="center">
  <sub>Region selection with physics-draped ropes. Clipboard-backed paste, reliable on the first try.</sub>
</p>

<br/>

<p align="center">
  <a href="https://github.com/Gekinzen/images-demo/raw/main/zen_6_15_3_demo_2026/zen_shell_v6.15.13_showcase.mp4">
    <img src="https://img.shields.io/badge/Download%20MP4%20Showcase-0a0a0a?style=for-the-badge" alt="Download MP4 showcase"/>
  </a>
</p>

<br/>

---

<br/>

## What's New in v6.15.x

The v6.15 series was a large feature release followed by a long tail of hardening patches (v6.15.1 → v6.15.13). Summary of everything added relative to v6.14.2:

<br/>

### Music Strings Module

An audio-reactive bezier visualizer that replaces the music module in the bar when enabled via **Settings → General → Strings**. Beat data comes from `cava`, track metadata from `playerctl`. Hovering the strings shows an Artist — Title tooltip. Curves bow freely above and below the bar slot via a dedicated `WlrLayer.Overlay` panel window.

### Screenshot Ropes

`Super+Shift+S` opens a region-screenshot overlay with physics-simulated ropes draped from the screen corners. Drag to select a region; the toolbar appears with copy / save / annotate actions. The copy path is `wl-copy`-backed with `setsid` detachment so clipboard ownership survives the helper script exiting. Pasting into any app produces the JPEG immediately.

### Complete SettingsStateV2 Coverage

The previous implementation of `applyToHyprland()` was missing roughly 20 Hyprland keywords (all snap properties, most blur/shadow secondaries, `dim_special`). These are now all persisted correctly — no more "snap gaps reset when I change themes" surprises.

### Robust Layout Handling

Eight iterative improvements for music-string positioning across panel mode transitions (Fullwidth ↔ Floating ↔ Island), culminating in:

- `QQuickLayout.forceLayout()` — synchronous layout passes during transitions eliminate Qt's async RowLayout propagation issue
- `zs-restart.sh` — a selective shell respawn helper for the one corner case (Float/FW → Island) that even `forceLayout()` couldn't solve from the QML layer

### Bootstrap Flag

`./install.sh --bootstrap` now supports fresh Arch-based laptops (safe to run on systems currently running KDE, GNOME, or COSMIC — does **not** touch the display manager, does **not** change the default session, does **not** remove any existing DE). Installs Hyprland + Quickshell + all dependencies in four tiers and creates a Wayland session entry so Hyprland becomes selectable from the existing login screen.

### Hyprland 0.54+ Syntax Compatibility

All bundled configs updated to the new syntax:

- `windowrulev2` → `windowrule = prop val, match:key regex`
- `layerrule = blur, ns` → `layerrule = blur on, match:namespace ns`
- `layerrule = noanim` → `layerrule = no_anim on, match:namespace ns`
- Trailing commas removed from all `bind = ...` lines

Full per-patch details are in [`CHANGELOG-v6.15.x.md`](CHANGELOG-v6.15.x.md) (consolidated) or the individual `CHANGELOG-v6.15.<n>.md` files.

<br/>

---

<br/>

## Features

<br/>

### Music Strings &nbsp;·&nbsp; v6.15+

*New in this series.* Audio-reactive bezier curve visualizer.

- Replaces the music module when enabled
- `cava` drives the beat amplitude
- `playerctl` drives artist/title tooltip
- Floating overlay panel — curves bow above and below the bar slot without being clipped by the bar's layer-shell surface
- Color modes: theme (auto blue → purple), synced (follows accent), custom (two color pickers)
- Loading placeholder with pulsing dot while the bar layout settles
- Toggleable and fully configurable in **Settings → General → Strings**

<br/>

### Screenshot Rope Overlay &nbsp;·&nbsp; v6.15+

*New in this series.* `Super+Shift+S` → region screenshot with physics-draped rope ornaments.

- 10-segment ropes with tuned gravity / inertia / spring force
- `grim` + `slurp` primary with `flameshot` fallback
- `wl-copy` integration with `setsid` detachment — paste works reliably on the first try
- Multi-monitor: rope appears on the monitor where the cursor is
- Toggleable in **Settings → General → Strings → Screenshot ropes**

<br/>

### Control Panel &nbsp;·&nbsp; Super+C

- PipeWire volume sliders
- WiFi / Bluetooth / LAN toggle switches
- CPU / GPU / RAM live stats
- Expand arrow for network list + BT devices
- Draggable panel

<br/>

### System Tray &nbsp;·&nbsp; SysRow

- Waybar-style expandable tray with `❮` arrow
- 6 modules: Sound, CPU, RAM, Temp, Network, Bluetooth
- Icon + bargraph or icon + text display modes
- Per-module visibility and color customization
- PopupWindow tooltips anchored above each icon

<br/>

### Desktop Widgets

- **Clock** — 120px bold, gradient glow, multi-timezone array
- **Weather** — icon-led, 7-day forecast, Open-Meteo (no API key)
- **System Monitor** — CPU/GPU/RAM/Network with Canvas sparklines
- All draggable with per-monitor position persistence

<br/>

### Bar / Panel

- 3 modes: **Full-width**, **Floating**, **Island**
- Drag-reorder modules between left / center / right zones
- 11 modules: start, taskbar, workspaces, window title, music, sysrow, tray, notifications, clock, weather, sysmonitor
- Adjustable: height, opacity, radius, border, background override
- Display target: all monitors / primary / specific monitor

<br/>

### Settings App &nbsp;·&nbsp; Zen Settings

Pages: General, Decoration, Animations, Themes, Displays, Panel, Bar Modules, System Tray, Sound & Network, Notifications, Desktop Widgets, Wallpaper.

- Live preview for all changes
- Persists to JSON
- Revert buttons on every section

<br/>

### Unified Theming System

17 built-in themes auto-synchronize across Quickshell bar, Settings app, Control Panel, SwayNC notifications, Alacritty terminal, and Fuzzel launcher.

<p align="center">
  <sub>One Dark · Gruvbox · Nord · Tokyo Night · Catppuccin Mocha · Dracula · Solarized Dark · Everforest Dark · Cyberpunk · Lovelace · Yousai · Arc · Adapta · Navy · Black · Paper</sub>
</p>

- Custom theme palette editor
- Rice export / import (save full desktop config as a JSON file)

<br/>

### Start Menu &nbsp;·&nbsp; Super+A

- Win11-style with pinned apps + alphabetical all-apps
- Real-time search
- Right-click context menu
- Integrated power controls

<br/>

### Wallpaper

- `swww`-powered engine with transition effects
- Visual picker with thumbnails (`Super+W`)
- Random wallpaper (`Super+Shift+W`)

<br/>

### Keybind Cheatsheet &nbsp;·&nbsp; Super+/

- Reads live from Hyprland config
- 8 color-coded categories

<br/>

---

<br/>

## Quick Start

### Fresh Arch-based laptop &nbsp;·&nbsp; KDE / GNOME / COSMIC safe

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

The `--bootstrap` flag installs Hyprland, Quickshell, and all dependencies without touching your current desktop environment. You can log out, select Hyprland from your login screen's session picker, and switch back to your previous DE any time.

### Hyprland already installed

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

git fetch --tags
git checkout v6.15.13         # pin to exact release
#   — or —
git checkout main             # always the latest commit

chmod +x install.sh
./install.sh
```

### Backup first &nbsp;·&nbsp; recommended

```bash
mv ~/.config/hypr      ~/.config/hypr.backup      2>/dev/null || true
mv ~/.config/quickshell ~/.config/quickshell.backup 2>/dev/null || true
```

<br/>

---

<br/>

## Dependencies

**Required**

- [Quickshell](https://github.com/quickshell-mirror/quickshell) 0.2.1+ — QML shell framework
- [Hyprland](https://hyprland.org/) 0.54+ — Wayland compositor
- `jq` — JSON processor

**Recommended** &nbsp;·&nbsp; most auto-installed by `--bootstrap`

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

The installer auto-detects missing packages and offers to install via `paru` > `yay` > `pacman`.

<br/>

---

<br/>

## Architecture

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

<br/>

---

<br/>

## Keybinds

| Keybind | Action |
|---|---|
| `Super + C` | Control Panel |
| `Super + A` | Start Menu |
| `Super + ,` | Zen Settings |
| `Super + W` | Wallpaper Picker |
| `Super + Shift + W` | Random Wallpaper |
| `Super + /` | Keybind Cheatsheet |
| **`Super + Shift + S`** | **Screenshot rope overlay** &nbsp;·&nbsp; v6.15+ |
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

<br/>

---

<br/>

## Wallpapers

A curated wallpaper set ships with the installer. You can also browse and download the full collection directly from the image repository.

<p align="center">
  <a href="https://github.com/Gekinzen/images-demo/tree/main/wallpapers">
    <img src="https://img.shields.io/badge/Browse%20Wallpaper%20Collection-0a0a0a?style=for-the-badge" alt="Browse wallpaper collection"/>
  </a>
</p>

```bash
# Clone just the wallpapers folder
git clone --depth=1 --filter=blob:none --sparse \
  https://github.com/Gekinzen/images-demo.git
cd images-demo
git sparse-checkout set wallpapers
```

<br/>

---

<br/>

## Changelogs

- **[v6.15.x consolidated](CHANGELOG-v6.15.x.md)** — overall summary of the entire v6.15 series
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

<br/>

---

<br/>

## FAQ

<br/>

**Is this a Hyprland dotfiles repo I can copy?**

No. Zen Shell is a complete desktop shell — a unified QML application that takes over the bar, settings, control panel, notifications, screenshots, and desktop widgets. You install it; it runs as a first-class shell alongside Hyprland.

<br/>

**Can I try it without uninstalling my current desktop?**

Yes. `./install.sh --bootstrap` is designed for KDE / GNOME / COSMIC users — it adds Hyprland as a session option without touching your display manager or current DE. Log out, pick Hyprland from the session menu, and switch back anytime.

<br/>

**Do I need to edit config files?**

No. Thirteen settings pages cover every configurable option, with live preview. Changes persist to JSON automatically — no manual editing, no restart.

<br/>

**Which distros work?**

Primary support is Arch-based distros (Arch, CachyOS, EndeavourOS, Manjaro). Other distros will work if you have **Hyprland 0.54+** and **Quickshell 0.2.1+** available, but the installer's package detection assumes `paru` / `yay` / `pacman`. On non-Arch distros, install the [Dependencies](#dependencies) manually first, then run `./install.sh` (without `--bootstrap`).

<br/>

---

<br/>

## Credits

### Inspired By

The **Music Strings visualizer** and the **Screenshot Rope overlay** in v6.15+ are heavily inspired by [flickowoa's Zephyr dotfiles](https://github.com/flickowoa/dotfiles/tree/hyprland-zephyr) ([demo video](https://www.youtube.com/watch?v=7Miis9I25q4)).

The original Zephyr dotfiles provided the initial concept and physics tuning reference (10-segment ropes, short segment length for natural catenary drape, softer gravity/damping values). Zen Shell's implementation builds on that foundation with:

- Full QML-native integration — no external Python daemons or helpers
- Clipboard-integrated screenshot capture (paste works reliably on the first try via `setsid`-detached `wl-copy`)
- String module toggle integrated with Zen Shell's Settings app (can be enabled/disabled in **General → Strings** without editing any config files)
- Beat data from `cava` driving the bezier curve amplitude in real-time
- Multi-monitor awareness for both the strings and the screenshot ropes
- Panel-mode-aware positioning (Fullwidth / Floating / Island)

Huge thanks to **[flickowoa](https://github.com/flickowoa)** for the original design language.

### Built With

- **[Quickshell](https://github.com/quickshell-mirror/quickshell)** — the QML shell framework this entire project is built on
- **[Hyprland](https://hyprland.org/)** — the Wayland compositor
- **Qt 6 / QML** — declarative UI + runtime

<br/>

---

<br/>

## Platform

<p align="center">
  <b>Arch Linux / CachyOS</b>
  &nbsp;·&nbsp;
  <b>Hyprland 0.54+</b>
  &nbsp;·&nbsp;
  <b>Quickshell</b>
  &nbsp;·&nbsp;
  <b>QML / JavaScript</b>
</p>

<p align="center">
  <sub>Reference hardware: AMD Ryzen 9 5950X &nbsp;·&nbsp; RX 6800 XT &nbsp;·&nbsp; 128&nbsp;GB RAM</sub>
</p>

<br/>

---

<br/>

## Roadmap

Zen Shell is actively developed. This is a personal project I enjoy working on and learn a lot from — so expect continuous iteration rather than a "finished" state.

### Next phase &nbsp;·&nbsp; in progress

Reimplementing features from the legacy Python/GTK4 alpha (now preserved at [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52)) as native QML modules in Zen Shell:

- [ ] **Start Menu logo customization** — swap the Arch logo for a custom image / SVG via Settings → Panel → Start Button
- [ ] **Notification volume OSD** — on-screen overlay that pops up briefly when volume changes (keyboard media keys / wpctl), synced with the current theme
- [ ] **Alt+Tab window switcher** — in-QML window-switcher overlay with app icon + title preview, replacing Hyprland's default cycle-next binding
- [ ] **Import user photo** — personalize the Start Menu header with a user avatar (file picker + automatic crop to circle)
- [ ] **Other fixes** — ongoing polish from real-world usage

### Longer-term ideas

- [ ] Integrate WiFi/BT logic directly in `ConnectivityPage` (connect / disconnect / forget networks, BT pairing) — replacing the current `nmtui` / `blueman-manager` shell-outs
- [ ] Media player widget — MPRIS in bar + Control Panel
- [ ] Notification history — SwayNC notification log viewer
- [ ] App drawer grid — grid view option for Start Menu all-apps
- [ ] Multi-monitor widget placement — per-monitor desktop widget positions
- [ ] Theme import from URL
- [ ] Bar auto-hide — hide bar on fullscreen or after timeout
- [ ] Lock screen — QML lock with clock + wallpaper blur
- [ ] More OSD overlays — brightness, keyboard layout, caps lock

<br/>

---

<br/>

## Contributing

You can help by:

- Reporting bugs
- Suggesting features
- Submitting pull requests
- Sharing themes
- Improving documentation

Open an issue on [GitHub](https://github.com/Gekinzen/zen_barebone_alpha_development/issues) or jump straight to a PR.

<br/>

---

<br/>

## Legacy Archive &nbsp;·&nbsp; 2025 Alpha

<p align="center">
  <sub>HISTORICAL REFERENCE</sub><br/>
  <b>Zen Barebone Alpha — Hyprland 0.52 era</b><br/>
  <i>The original Python / GTK4 / Waybar stack, preserved for posterity before the full QML rewrite shipped in v6.10+.</i>
</p>

<br/>

> These assets were captured on **Hyprland 0.52** and document the pre-Quickshell lineage of the project. Current Zen Shell runs on **Hyprland 0.54+** with a unified QML architecture — see the [Showcase](#showcase) above for the latest look. The deprecated source is preserved at [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52).

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif" alt="Alpha main demo" width="880"/>
</p>

<br/>

<table align="center">
<tr>
<td align="center" width="50%">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.gif" alt="Alpha theme switching" width="420"/>
<br/><sub>Theme switching</sub>
</td>
<td align="center" width="50%">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/changewallpaper.gif" alt="Alpha wallpaper picker" width="420"/>
<br/><sub>Wallpaper picker</sub>
</td>
</tr>
<tr>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/paneldemo.gif" alt="Alpha panel modes" width="420"/>
<br/><sub>Panel modes</sub>
</td>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/desktoplooks.png" alt="Alpha desktop looks" width="420"/>
<br/><sub>Desktop looks</sub>
</td>
</tr>
<tr>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/dock.png" alt="Alpha dock" width="420"/>
<br/><sub>Dock / taskbar</sub>
</td>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenter.png" alt="Alpha control center" width="420"/>
<br/><sub>Control center</sub>
</td>
</tr>
<tr>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenteranimation.png" alt="Alpha animation editor" width="420"/>
<br/><sub>Animation editor</sub>
</td>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenter%20power%20profile.png" alt="Alpha power profile" width="420"/>
<br/><sub>Power profile</sub>
</td>
</tr>
<tr>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprlandappearance.png" alt="Alpha appearance settings" width="420"/>
<br/><sub>Appearance settings</sub>
</td>
<td align="center">
<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.png" alt="Alpha theme engine" width="420"/>
<br/><sub>Theme engine</sub>
</td>
</tr>
</table>

<br/>

---

<br/>

## Support

Zen Shell is developed independently, in personal time — late nights, after client work, from a small apartment in the Philippines. If it has helped you, or you just appreciate the craft, a coffee goes a long way. Literally. It's what keeps the commits flowing at 2 AM.

<p align="center">
  <a href="https://buymeacoffee.com/zenpy">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffffff?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black"/>
      <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-0a0a0a?style=for-the-badge&logo=buy-me-a-coffee&logoColor=white" alt="Buy me a coffee"/>
    </picture>
  </a>
</p>

<p align="center">
  <sub>Every coffee funds one more feature, one more bugfix, one more late-night commit.</sub>
</p>

<br/>

You can also support via crypto:

| Currency | Address |
|---|---|
| **BTC** &nbsp;·&nbsp; Bitcoin | `12Wo7KT9uqKzfZ15ZLugg7yyb3AfsmEVTc` |
| **BCH** &nbsp;·&nbsp; Bitcoin Cash | `1EBooTk9TuGBEn9bMkQoSs6yAjbCKd2TqQ` |
| **SOL** &nbsp;·&nbsp; Solana | `2FUpxNPHgAJ7r3VpRWxBJNMFoayoZWeFNV6tVsMPe5QR` |

<br/>

---

<br/>

<p align="center">
  <b>MIT</b> &nbsp;·&nbsp; Free to use, fork, and make your own. &nbsp;·&nbsp; Star the project if it resonates with you.
</p>

<br/>

<p align="center">
  <sub>Designed and built by <a href="https://github.com/Gekinzen">Zenpy</a> &nbsp;·&nbsp; Antipolo, Philippines</sub>
</p>
