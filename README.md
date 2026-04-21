<div align="center">

<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png" alt="Zen Shell v6.16.1" width="100%"/>

<br/><br/>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/blur-on.svg?color=white&height=48"/>
  <img src="https://api.iconify.design/material-symbols/blur-on.svg?color=%23333&height=48" height="48" alt=""/>
</picture>

# Zen Shell

**A Quickshell-native desktop environment for Hyprland**

*Control everything. Theme everything. Break nothing.*

<br/>

![Version](https://img.shields.io/badge/v6.15.13-stable-brightgreen?style=flat-square)
![Beta](https://img.shields.io/badge/v6.16.1.11-beta-yellow?style=flat-square)
![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1a1a1a?style=flat-square&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland%200.54%2B-1a1a1a?style=flat-square&logo=wayland&logoColor=white)
![Quickshell QML](https://img.shields.io/badge/Quickshell%20QML-1a1a1a?style=flat-square)
![Beta](https://img.shields.io/badge/Beta-1a1a1a?style=flat-square)
![MIT](https://img.shields.io/badge/MIT-1a1a1a?style=flat-square)

![Last Commit](https://img.shields.io/github/last-commit/Gekinzen/zen_barebone_alpha_development?style=flat-square&label=last%20commit&color=1a1a1a&labelColor=0a0a0a)
![Issues](https://img.shields.io/github/issues/Gekinzen/zen_barebone_alpha_development?style=flat-square&color=1a1a1a&labelColor=0a0a0a)
![Stars](https://img.shields.io/github/stars/Gekinzen/zen_barebone_alpha_development?style=flat-square&color=1a1a1a&labelColor=0a0a0a)
![Forks](https://img.shields.io/github/forks/Gekinzen/zen_barebone_alpha_development?style=flat-square&color=1a1a1a&labelColor=0a0a0a)

<br/>

[Overview](#overview) · [Demo](#demo) · [Showcase](#showcase) · [What's New](#whats-new-in-v616x) · [Features](#features) · [Install](#quick-start) · [Architecture](#architecture) · [Keybinds](#keybinds) · [FAQ](#faq) · [Credits](#credits)

<br/>

> [!NOTE]
> **Current stable release is v6.15.13** (`main` branch). The v6.16.x series is still in beta.
>
> | Channel | Version | Branch | Notes |
> |---|---|---|---|
> | **Stable** | v6.15.13 | [`main`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/main) | Official release — recommended for most users |
> | **Beta** | v6.16.1.11 | [`beta-v12.6.16.1.11`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/beta-v12.6.16.1.11) | Latest features — Battery, Power Profiles, GPU Switcher, Gaming Boost. **Especially recommended for laptop users.** Works on desktop too. |

<br/>

---

</div>

## Overview

**Zen Shell** is a complete desktop shell built entirely in QML using [Quickshell](https://github.com/quickshell-mirror/quickshell) — replacing the previous mixed stack of GTK4/Libadwaita, Python, C++, and Waybar with a **unified, lightweight QML architecture**.

Not just a Hyprland configuration. A structured, modular desktop ecosystem.

<br/>

<div align="center">

<table>
<tr>
<td align="center" width="33%">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/bolt.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/bolt.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>Performance-first</b>
<br/><sub>Lean QML runtime</sub>
</td>
<td align="center" width="33%">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/palette-outline.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/palette-outline.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>Unified theming</b>
<br/><sub>One switch, whole desktop</sub>
</td>
<td align="center" width="33%">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/tune.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/tune.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>GUI-driven</b>
<br/><sub>No config files required</sub>
</td>
</tr>
<tr>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/battery-charging-50.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/battery-charging-50.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>Battery &amp; Power</b>
<br/><sub>Smart profiles — v6.16</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/memory.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/memory.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>Multi-GPU</b>
<br/><sub>Switcher + tabs — v6.16</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/sync.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/sync.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>State-synchronized</b>
<br/><sub>Change one, update all</sub>
</td>
</tr>
<tr>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/graphic-eq.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/graphic-eq.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>Music Strings</b>
<br/><sub>Audio-reactive bezier — v6.15</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/screenshot-region.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/screenshot-region.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>Screenshot Ropes</b>
<br/><sub>Physics overlay — v6.15</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/sports-esports-outline.svg?color=white&height=28"/>
  <img src="https://api.iconify.design/material-symbols/sports-esports-outline.svg?color=%23333&height=28" height="28" alt=""/>
</picture>
<br/><b>Gaming Boost</b>
<br/><sub>One-tap performance — v6.16</sub>
</td>
</tr>
</table>

</div>

<br/>

> The legacy Python/GTK4 alpha is preserved at [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52) for historical reference.

<br/>

---

## Demo

<div align="center">

[![Zen Shell v6.15.13 — Full Tour](https://img.youtube.com/vi/dNwGRBhA97g/maxresdefault.jpg)](https://www.youtube.com/watch?v=dNwGRBhA97g)

**Zen Shell v6.15.13 — Full Tour**
*Strings music module · screenshot ropes · settings · complete desktop experience*

<br/>

| | |
|:---:|:---:|
| [![v6.14](https://img.youtube.com/vi/YQxrh5_naMQ/maxresdefault.jpg)](https://www.youtube.com/watch?v=YQxrh5_naMQ) | [![v6.10 QML Foundations](https://img.youtube.com/vi/ao89J3DEqiA/maxresdefault.jpg)](https://www.youtube.com/watch?v=ao89J3DEqiA) |
| **Zen Shell v6.14** — Theme switching, panel modes | **Zen Shell v6.10** — The QML rewrite that started it all |

</div>

<br/>

---

## Showcase

<div align="center">

*Captured on Hyprland 0.54, Quickshell 0.2.1*

<br/>

<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png" width="920" alt="Desktop preview"/>

<br/><br/>

<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png" width="920" alt="Desktop preview"/>

</div>

<br/>

### Adaptive theming

<div align="center">

<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_01_adaptive_theming.gif" width="920" alt="Adaptive theming"/>

*One palette. Every surface — bar, settings, control panel, notifications, terminal, launcher.*

</div>

<br/>

### Settings tour

<div align="center">

<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_02_settings_tour.gif" width="920" alt="Settings tour"/>

*Fourteen pages of live-preview configuration. No config files. No restart.*

</div>

<br/>

### Screenshot module · ultrawide

<div align="center">

<img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_03_screenshot_module_ultrawide.gif" width="920" alt="Screenshot module"/>

*Region selection with physics-draped ropes. Clipboard-backed paste, reliable on the first try.*

<br/>

[![Download MP4 Showcase](https://img.shields.io/badge/Download%20MP4%20Showcase-0a0a0a?style=for-the-badge)](https://github.com/Gekinzen/images-demo/raw/main/zen_6_15_3_demo_2026/zen_shell_v6.15.13_showcase.mp4)

</div>

<br/>

---

## What's New in v6.16.x

The v6.16 series introduces **laptop-grade power management**, **multi-GPU support**, and a **cascade Control Panel** — the biggest feature release since v6.15 Music Strings. Hardened by 11 hotfix patches (v6.16.1.1 → v6.16.1.11).

<br/>

<table>
<tr>
<td width="36">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/battery-charging-full.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/battery-charging-full.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Battery Module</b></td>
<td>Icon / text / bar modes. Auto-hides on desktops. Color shifts at 10/30/50%.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/electric-bolt.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/electric-bolt.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Power Profile Service</b></td>
<td><code>powerprofilesctl</code> wrapper. Saver / Balanced / Performance. Persists across reboots.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/sports-esports-outline.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/sports-esports-outline.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Gaming Boost</b></td>
<td>Forces performance + disables blur/dim/animations via <code>hyprctl --batch</code>. Survives restarts.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/memory.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/memory.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>GPU Switcher</b></td>
<td>4 modes. Auto-detects NVIDIA/AMD/Intel. Writes env vars to <code>~/.config/environment.d/</code>.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/monitor.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/monitor.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Multi-GPU Widget Tabs</b></td>
<td>Overview / CPU / GPU0 / GPU1 / NET. Vendor-colored badges. 420×420 sysmon widget.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/volume-up.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/volume-up.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Volume &amp; Brightness OSD</b></td>
<td>XF86 keys emit swaync notifications with 20-char progress bars. No stacking spam.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/view-sidebar.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/view-sidebar.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Cascade Control Panel</b></td>
<td>Auto-splits to two columns when tabs overflow. Click-outside-to-close.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/toggle-on.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/toggle-on.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Unified HMSwitch</b></td>
<td>One centralized pill toggle. All 27 toggles — identical 150ms OutCubic animation.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/drag-pan.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/drag-pan.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Smooth Widget Drag</b></td>
<td><code>_anyDragActive</code> guard prevents <code>_applyPositions()</code> resetting position mid-drag.</td>
</tr>
<tr>
<td>
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/color-lens.svg?color=white&height=20"/>
  <img src="https://api.iconify.design/material-symbols/color-lens.svg?color=%23555&height=20" height="20" alt=""/>
</picture>
</td>
<td><b>Widget Background Picker</b></td>
<td>Default / Theme-synced / Custom per widget. 10 swatches + opacity slider.</td>
</tr>
</table>

<br/>

Full per-patch details: [`CHANGELOG-v6.16.x.md`](CHANGELOG-v6.16.x.md)

<br/>

---

## Features

<br/>

### <picture><source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/battery-charging-full.svg?color=white&height=20"/><img src="https://api.iconify.design/material-symbols/battery-charging-full.svg?color=%23333&height=20" height="20" alt=""/></picture> Battery & Power · v6.16+

- Battery module — icon / text / bar modes, auto-hides on desktops
- Low-battery swaync notifications at 30% and 10% with hysteresis
- Power Profile pills in Control Panel (Saver / Balanced / Performance)
- Gaming Boost — performance + compositor effects off with one tap
- Lid close behavior: Mirror / Keep Internal / Off
- `zen-power-profile-restore.sh` persists profile across reboots

<br/>

### <picture><source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/memory.svg?color=white&height=20"/><img src="https://api.iconify.design/material-symbols/memory.svg?color=%23333&height=20" height="20" alt=""/></picture> GPU Switcher · v6.16+

- 4 modes — Auto / Integrated / Dedicated / Auto-Gaming
- Writes to `~/.config/environment.d/zen-gpu.conf` for systemd persistence
- `zen-game-watcher.sh` — 3s poll daemon for Steam, Lutris, Wine, Proton, etc.
- `prime-run <command>` wrapper for one-shot dedicated-GPU launches
- Auto-detects NVIDIA / AMD / Intel from `/sys/class/drm/card*` vendor IDs

<br/>

### <picture><source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/graphic-eq.svg?color=white&height=20"/><img src="https://api.iconify.design/material-symbols/graphic-eq.svg?color=%23333&height=20" height="20" alt=""/></picture> Music Strings · v6.15+

- Audio-reactive bezier curve visualizer — `cava` drives beat amplitude
- Floating overlay panel (WlrLayer.Overlay) — curves bow freely above and below the bar
- `playerctl` drives artist/title tooltip
- Color modes: theme / synced / custom (two color pickers)
- Toggleable in **Settings → General → Strings**

<br/>

### <picture><source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/screenshot-region.svg?color=white&height=20"/><img src="https://api.iconify.design/material-symbols/screenshot-region.svg?color=%23333&height=20" height="20" alt=""/></picture> Screenshot Rope Overlay · v6.15+

- `Super+Shift+S` → region screenshot with physics-draped ropes
- 10-segment ropes with tuned gravity / inertia / spring force
- `grim` + `slurp` primary, `flameshot` GUI fallback
- `wl-copy` with `setsid` detachment — paste works on the first try
- Multi-monitor aware · Toggleable in Settings

<br/>

### <picture><source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/tune.svg?color=white&height=20"/><img src="https://api.iconify.design/material-symbols/tune.svg?color=%23333&height=20" height="20" alt=""/></picture> Control Panel · Super+C

- PipeWire volume sliders (input + output)
- WiFi / Bluetooth / LAN toggle switches
- CPU / GPU / RAM / VRAM live stats
- Power Profile pills + Gaming Boost toggle
- Cascade expand — two-column layout when tabs overflow · v6.16.1
- Click-outside-to-close · v6.16.1

<br/>

### <picture><source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/widgets-outline.svg?color=white&height=20"/><img src="https://api.iconify.design/material-symbols/widgets-outline.svg?color=%23333&height=20" height="20" alt=""/></picture> Desktop Widgets

- **Clock** — 120px bold, gradient glow, multi-timezone
- **Weather** — icon-led, 7-day forecast, Open-Meteo (no API key)
- **System Monitor** — CPU/GPU/RAM/Network sparklines, multi-GPU tabs, btop button · v6.16
- Per-widget background: Default / Theme-synced / Custom · v6.16.1
- Smooth drag with no ghost trails or frame drops · v6.16.1

<br/>

### <picture><source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/palette-outline.svg?color=white&height=20"/><img src="https://api.iconify.design/material-symbols/palette-outline.svg?color=%23333&height=20" height="20" alt=""/></picture> Unified Theming

17 built-in themes auto-sync across Quickshell bar, Settings, Control Panel, SwayNC, Alacritty, and Fuzzel.

> One Dark · Gruvbox · Nord · Tokyo Night · Catppuccin Mocha · Dracula · Solarized Dark · Everforest Dark · Cyberpunk · Lovelace · Yousai · Arc · Adapta · Navy · Black · Paper

- Custom theme palette editor
- Rice export / import (full desktop config as JSON)

<br/>

### Other highlights

- **Bar** — 3 modes (Full-width / Floating / Island), drag-reorder modules, 12 module slots
- **Start Menu** — Win11-style, pinned apps, real-time search, right-click context
- **Wallpaper** — `swww`-powered, visual picker with thumbnails, random wallpaper
- **Keybind Cheatsheet** — live-reads from Hyprland config, 8 color-coded categories
- **Settings App** — 14 pages, live preview, JSON persistence, revert buttons

<br/>

---

## Quick Start

### Stable · v6.15.13 · `main` branch

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# main branch = v6.15.13 (default, already checked out)

# Fresh install — safe alongside KDE / GNOME / COSMIC
chmod +x install.sh
./install.sh --bootstrap

# Hyprland already installed? Skip --bootstrap:
./install.sh
```

### Beta · v6.16.1.11 · recommended for laptop users (works on desktop too)

The beta branch includes Battery module, Power Profiles, GPU Switcher, Gaming Boost, Multi-GPU widget tabs, Cascade Control Panel, Unified HMSwitch, and Volume/Brightness OSD.

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# Switch to the beta branch
git checkout beta-v12.6.16.1.11

# Fresh install — safe alongside KDE / GNOME / COSMIC
chmod +x install.sh
./install.sh --bootstrap

# Hyprland already installed? Skip --bootstrap:
./install.sh
```

### Backup first (recommended)

```bash
mv ~/.config/hypr       ~/.config/hypr.backup      2>/dev/null || true
mv ~/.config/quickshell ~/.config/quickshell.backup 2>/dev/null || true
```

<br/>

---

## Dependencies

**Required**

| Package | Purpose |
|---|---|
| [Quickshell](https://github.com/quickshell-mirror/quickshell) 0.2.1+ | QML shell framework |
| [Hyprland](https://hyprland.org/) 0.54+ | Wayland compositor |
| `jq` | JSON processor |

**Recommended** (most auto-installed via `--bootstrap`)

`swww` · `grim` · `slurp` · `wl-clipboard` · `flameshot` · `cava` · `playerctl` · `power-profiles-daemon` · `brightnessctl` · `alacritty` · `thunar` · `fuzzel` · `btop` · `swaync` · `nwg-displays` · `nwg-look` · `blueman` · `networkmanager` · `wireplumber` · `pavucontrol` · `zenity`

<br/>

---

## Architecture

```
~/.config/quickshell/zen-shell/
├── shell.qml                  # Entry point — bar, overlays, widgets
├── Bar.qml                    # Bottom bar with module loader
├── Battery.qml                # Battery bar module                  ← v6.16
├── MusicStrings.qml           # Music slot placeholder              ← v6.15
├── ZenStrings.qml             # Audio-reactive visualizer           ← v6.15
├── ZenStringsState.qml        # Shared strings state singleton
├── ZenRope.qml                # Physics rope                        ← v6.15
├── ZenScreenshotOverlay.qml   # Region screenshot + ropes
├── ControlPanel.qml
├── PowerProfileService.qml    # powerprofilesctl + Gaming Boost     ← v6.16
├── GPUSwitcherService.qml     # GPU selection + env vars            ← v6.16
├── HMSwitch.qml               # Unified pill toggle (×27)           ← v6.16.1
├── ThemeService.qml
├── SettingsStateV2.qml        # Full Hyprland state persistence
├── ZenSettings.qml            # Settings window · 14 pages
├── BatterySettingsPage.qml    # Battery, Power & GPU page           ← v6.16
└── ...                        # ~73 QML files total

~/.local/bin/
├── zen-screenshot.sh          # Screenshot pipeline
├── zen-volume-notify.sh       # Volume/brightness OSD               ← v6.16
├── zen-power-profile-restore.sh
├── zen-game-watcher.sh        # Auto-Gaming process detection       ← v6.16
└── prime-run                  # One-shot dGPU launcher              ← v6.16
```

### Strings architecture

```
barWindow (WlrLayer.Top, namespace zen-shell-bar)
└── Bar.qml
    └── Loader
        └── MusicStrings.qml
            ├── zen-cava.sh process
            └── Loading placeholder

stringsWindow (WlrLayer.Overlay, namespace zen-shell-strings)
└── ZenStrings.qml
    margins.left   = barWindowLeft + musicSlotLocalX
    implicitHeight = barHeight + 2 × verticalPadding (±60px overflow)
```

<br/>

---

## Keybinds

| Keybind | Action |
|---|---|
| `Super + C` | Control Panel |
| `Super + A` | Start Menu |
| `Super + ,` | Zen Settings |
| `Super + W` | Wallpaper Picker |
| `Super + Shift + W` | Random Wallpaper |
| `Super + /` | Keybind Cheatsheet |
| `Super + Shift + S` | Screenshot rope overlay — v6.15 |
| `Super + T` | Terminal |
| `Super + E` | File Manager |
| `Super + D` / `Super + R` | App Launcher |
| `Super + Q` | Close window |
| `Super + F` | Maximize |
| `Super + G` | Toggle floating |
| `Super + B` | System monitor (btm) |
| `Super + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | Move window to workspace |
| `XF86AudioRaiseVolume` | Volume up + OSD — v6.16 |
| `XF86AudioLowerVolume` | Volume down + OSD — v6.16 |
| `XF86AudioMute` | Mute toggle + OSD — v6.16 |
| `XF86MonBrightnessUp/Down` | Brightness + OSD — v6.16 |

<br/>

---

## Wallpapers

<div align="center">

[![Browse Wallpaper Collection](https://img.shields.io/badge/Browse%20Wallpaper%20Collection-0a0a0a?style=for-the-badge)](https://github.com/Gekinzen/images-demo/tree/main/wallpapers)

</div>

```bash
git clone --depth=1 --filter=blob:none --sparse https://github.com/Gekinzen/images-demo.git
cd images-demo && git sparse-checkout set wallpapers
```

<br/>

---

## Changelogs

### v6.16.x

- **[v6.16.x consolidated](CHANGELOG-v6.16.x.md)**
- [v6.16.1.11](CHANGELOG-v6.16.1.11.md) — Cascade infinite-loop fix
- [v6.16.1.10](CHANGELOG-v6.16.1.10.md) — Cascade-to-side Control Panel
- [v6.16.1.9](CHANGELOG-v6.16.1.9.md) — Widget ghost root-cause + WiFi tab visibility
- [v6.16.1.8](CHANGELOG-v6.16.1.8.md) — Drag stability + tab redesign
- [v6.16.1.7](CHANGELOG-v6.16.1.7.md) — HMSwitch type registration
- [v6.16.1.6](CHANGELOG-v6.16.1.6.md) — Expand visibility + hyprctl-reload clobber fix
- [v6.16.1.5](CHANGELOG-v6.16.1.5.md) — Weather icon + widget backgrounds
- [v6.16.1.4](CHANGELOG-v6.16.1.4.md) — Unified HMSwitch toggle design
- [v6.16.1.3](CHANGELOG-v6.16.1.3.md) — Widget ghost fix
- [v6.16.1.2](CHANGELOG-v6.16.1.2.md) — Nav Flickable fix
- [v6.16.1.1](CHANGELOG-v6.16.1.1.md) — Quickshell.Io import fix
- [v6.16.1](CHANGELOG-v6.16.1.md) — Multi-GPU, GPU Switcher, Gaming Boost, btop, smooth drag
- [v6.16.0.2](CHANGELOG-v6.16.0.2.md) — PanelState migration
- [v6.16.0.1](CHANGELOG-v6.16.0.1.md) — ToolTip → Rectangle popup
- [v6.16](CHANGELOG-v6.16.md) — Battery, Power Profiles, Volume OSD, Lid Fix

### v6.15.x

- **[v6.15.x consolidated](CHANGELOG-v6.15.x.md)**
- [v6.15.13](CHANGELOG-v6.15.13.md) — Install automation polish
- [v6.15.12](CHANGELOG-v6.15.12.md) — Nuclear restart self-suicide fix
- [v6.15.9](CHANGELOG-v6.15.9.md) — `RowLayout.forceLayout()` synchronous layout
- [v6.15.5](CHANGELOG-v6.15.5.md) — Smooth runtime transitions
- [v6.15.2](CHANGELOG-v6.15.2.md) — Music string position + Loading placeholder
- [v6.15.1](CHANGELOG-v6.15.1.md) — Screenshot clipboard + rope physics
- [v6.15](CHANGELOG-v6.15.md) — Music module → ZenStrings + screenshot ropes

<br/>

---

## FAQ

**Is this just a Hyprland dotfiles repo?**
No. Zen Shell is a complete desktop shell — a unified QML application taking over the bar, settings, control panel, notifications, screenshots, and desktop widgets.

**Can I try it without uninstalling my current DE?**
Yes. `./install.sh --bootstrap` adds Hyprland as a session option without touching your display manager.

**Do I need to edit config files?**
No. All configuration is done via the 14 settings pages with live preview. Changes persist to JSON automatically.

**Does this work on laptops?**
Yes — v6.16 added full laptop support: battery module, low-battery notifications, power profiles, lid close behavior, and Gaming Boost. Everything auto-hides when hardware isn't detected.

**I have a dual-GPU laptop (Optimus). Does it support that?**
Yes. GPU Switcher in Settings → Battery, Power & GPU. Auto-gaming mode watches for known games and auto-switches to Performance + dGPU on launch.

**Which distros work?**
Primary: Arch-based (Arch, CachyOS, EndeavourOS, Manjaro). Other distros work if Hyprland 0.54+ and Quickshell 0.2.1+ are available.

<br/>

---

## Credits

### Inspired By

The **Music Strings** and **Screenshot Rope** visualizers are heavily inspired by [flickowoa's Zephyr dotfiles](https://github.com/flickowoa/dotfiles/tree/hyprland-zephyr). Zen Shell's implementation adds full QML-native integration, clipboard-reliable screenshot capture, Settings toggle integration, multi-monitor awareness, and `cava`-driven beat amplitude. Huge thanks to [flickowoa](https://github.com/flickowoa).

### Built With

- **[Quickshell](https://github.com/quickshell-mirror/quickshell)** — QML shell framework
- **[Hyprland](https://hyprland.org/)** — Wayland compositor
- **Qt 6 / QML** — declarative UI runtime

<br/>

---

## Roadmap

### v6.16.x — Three phases to stable

> **Naming convention:** Beta branches always carry the `beta-v12.` prefix. When a phase reaches stable, the prefix is stripped and the branch promotes to `main` as `v6.x.x.x`. Current beta is `beta-v12.6.16.1.11` — still beta because **v6.16.2** is the final phase before official release.

| Phase | Status | Focus |
|---|---|---|
| **v6.16.0** | ✅ Shipped | Panel · Power · Notifications · Lid Fix |
| **v6.16.1** | 🟡 Beta (`beta-v12.6.16.1.11`) | Widgets · GPU Smart Switching |
| **v6.16.2** | 🔜 Next (final phase) | StartMenu · Wallpaper · Calendar |

#### v6.16.0 — Panel, Power, Notifications, Lid Fix · *shipped*

- Battery module in `Bar.qml` (icon / text / bar mode)
- Battery warnings: 30% warning, 10% critical → swaync
- Volume change → swaync notifications
- Power profiles: Saver / Balanced / Performance (persisted, notify)
- Lid-close fix (Hyprland monitor config)
- All settings persisted via `SettingsStateV2`

#### v6.16.1 — Widgets + GPU Smart Switching · *current beta*

- DesktopWidgets: multi-GPU auto-detect + tabs / show-all
- Multi-CPU same treatment
- btop button on the upper-right
- GPU switching service (integrated / dedicated, auto / manual gaming detection)
- All swaync notifications wired up

#### v6.16.2 — StartMenu, Wallpaper, Calendar · *final phase before official*

- Fuzzy finder search in StartMenu
- Logo image settings + auto-fit
- Right-click pin / unpin prompts
- Theme sync + proper rounded corners (taskbar, startmenu, popups)
- Wallpaper repo integration (`Gekinzen/images-demo`) + default wallpaper
- Hover calendar + click-to-open (native QML — theme-synced, not hyprclock)

### Longer-term

- Media player widget (MPRIS)
- WiFi/BT connect/pair directly in ConnectivityPage
- Notification history viewer
- App drawer grid view
- Bar auto-hide (fullscreen / timeout)
- QML lock screen
- Alt+Tab window switcher overlay
- Multi-monitor per-widget placement

<br/>

---

## Support

<div align="center">

Zen Shell is built independently — late nights, after client work. If it's improved your desktop, a coffee keeps the commits coming.

<br/>

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-0a0a0a?style=for-the-badge&logo=buy-me-a-coffee&logoColor=white)](https://buymeacoffee.com/zenpy)

<br/>

| Currency | Address |
|---|---|
| **BTC** | `12Wo7KT9uqKzfZ15ZLugg7yyb3AfsmEVTc` |
| **BCH** | `1EBooTk9TuGBEn9bMkQoSs6yAjbCKd2TqQ` |
| **SOL** | `2FUpxNPHgAJ7r3VpRWxBJNMFoayoZWeFNV6tVsMPe5QR` |

<br/>

---

**MIT** · Free to use, fork, and make your own. · Star the project if it resonates.

*Built by [Zenpy](https://github.com/Gekinzen)*

</div>
