<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png" alt="Zen Shell — v6.16.2.3.6" width="960"/>
</p>

<h1 align="center" style="letter-spacing:-0.02em;">Zen&nbsp;Shell</h1>

<p align="center">
  <sub><b>A QUICKSHELL-NATIVE DESKTOP ENVIRONMENT FOR HYPRLAND</b></sub>
</p>

<p align="center">
  <i>Control everything. Theme everything. Break nothing.</i>
</p>

<p align="center">
  <a href="https://gekinzen.github.io/zen-shell-site/">
    <img src="https://img.shields.io/badge/Project%20Website-gekinzen.github.io%2Fzen--shell--site-1a1a1a?style=for-the-badge&labelColor=0a0a0a" alt="Project website"/>
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/v6.15.13-stable-brightgreen?style=flat-square"/>
  &nbsp;
  <img src="https://img.shields.io/badge/v6.16.2.3.6-beta-yellow?style=flat-square"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Arch%20Linux-1a1a1a?style=flat-square&logo=arch-linux&logoColor=white"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Hyprland%200.54%2B-1a1a1a?style=flat-square&logo=wayland&logoColor=white"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Quickshell%20QML-1a1a1a?style=flat-square"/>
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
  <a href="#whats-new-in-v61623x">What's New</a>
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
  <a href="#roadmap">Roadmap</a>
  &nbsp;·&nbsp;
  <a href="#faq">FAQ</a>
  &nbsp;·&nbsp;
  <a href="#legacy-archive--2025-alpha">Archive</a>
  &nbsp;·&nbsp;
  <a href="#credits">Credits</a>
</p>

<br/>

> [!NOTE]
> **Stable: v6.15.13** (`main` branch). **Beta: v6.16.2.3.6** (`beta-v12.6.16.2.3.6`).
>
> | Channel | Version | Branch | Notes |
> |---|---|---|---|
> | **Stable** | v6.15.13 | [`main`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/main) | Official release — recommended for most users |
> | **Beta** | v6.16.2.3.6 | [`beta-v12.6.16.2.3.6`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/beta-v12.6.16.2.3.6) | Closes out the v6.16.2.3 hotfix series. Click-through Settings/Control Panel, native QML hover calendar, OpacityMask avatar, default wallpaper, wallpaper repo browser, mouse sensitivity, duplicate-bar-on-reinstall fix. **Recommended for laptop users — works on desktop too.** |

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
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/battery-charging-50.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/battery-charging-50.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Battery &amp; Power</b>
<br/><sub>Smart profiles — v6.16</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/memory.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/memory.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Multi-GPU</b>
<br/><sub>Switcher + tabs — v6.16</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/mouse-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/mouse-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Mouse Tuning</b>
<br/><sub>Live hyprctl — v6.16.2.3</sub>
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
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/wallpaper.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/wallpaper.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Wallpaper Repo</b>
<br/><sub>GitHub-backed picker — v6.16.2.3</sub>
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
  <sub>STABLE RELEASE</sub><br/>
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
  <sub>Fourteen pages of live-preview configuration. No config files. No restart.</sub>
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

## What's New in v6.16.2.3.x

The v6.16.2.3 hotfix series closes out the v6.16.2 release with click-through transparency, native QML hover calendar wiring, the OpacityMask avatar fix, default wallpaper auto-fetch, the wallpaper repo browser, mouse sensitivity controls, and a bulletproof installer that no longer leaves duplicate bars stacked on top of each other.

<br/>

### v6.16.2.3.6 highlights

- **Music rope click-through** — `mask: Region {}` on `stringsWindow` makes the audio-reactive bar overlay fully input-transparent. Browsers, editors, and file managers below the strings overlay receive clicks normally.
- **Settings + Control Panel click-through** — both windows use `mask: Region { item: <inner panel> }` so the transparent backdrop around the panel passes clicks through to the apps below. Close via the ✕ button or `Super+C` toggle.
- **Clock hover popup + scroll-wheel calendar** — peek tooltip shows weekday, date, and week number after a 350ms hover. `WheelHandler` cycles calendar months. Right-click cycles `PanelState.clockFormatIndex` through clock formats. Same handler attached to the open calendar itself.
- **Island mode persistence on reboot** — `PanelState.qml` emits `panelStateLoaded()` after `FileView` finishes its first read; `shell.qml` gates the nuclear-restart trigger on `_shellReady` (with a 2000ms fallback). Initial-load mode transitions no longer trigger a restart cascade — Island mode now actually survives reboot.
- **Avatar — versioned filename + diagnostics + OpacityMask circle** — uploads write `~/.config/zen-shell/user-avatar-<nanosecond-ts>.<ext>` with a bare-name symlink for back-compat. Old files pruned (keep 3 newest). Verbose `set -x` trace to `/tmp/zen-avatar-debug.log`. Circular crop now uses `OpacityMask` from `Qt5Compat.GraphicalEffects` (the original GLSL shader silently failed on some Qt builds — `OpacityMask` is the same module ZenStrings already uses for `Glow`, so it's proven-reliable).
- **Default wallpaper auto-applied on fresh installs** — `install.sh` downloads `123824383_p0 (Edited) compressed.png` from `Gekinzen/images-demo/wallpapers` and applies via `swww` on first boot. Recorded in `wallpaper-state.json` so existing wallpapers are never overridden.
- **Wallpaper repo browser** — new `WallpaperRepoService.qml` singleton fetches the GitHub contents API listing for `Gekinzen/images-demo/wallpapers`, caches to `~/.cache/zen-shell/wallpapers/`, and renders an "Online" tab in `WallpaperPicker.qml` with one-click download + apply.
- **Mouse sensitivity (Settings + Control Panel)** — new `MouseSettingsService.qml` singleton handles sensitivity (-1.0 to +1.0), scroll factor (0.1 to 3.0), and two `natural_scroll` toggles (mouse + touchpad). Live via `hyprctl keyword`, persisted to `~/.config/hypr/zen-mouse.conf`. Two UIs both bound to the same singleton: full Settings page (descriptions + verification commands) and a compact Control Panel tab.
- **Hyprland version tooltip** — sys-info popover's WM row now has a hover tooltip showing the full branch/commit string (was being truncated).
- **Device + BIOS info in User Profile** — `UserProfileService.qml` reads `/sys/class/dmi/id/{sys_vendor,product_name,product_version,bios_vendor,bios_version,bios_date}` (no sudo — world-readable on mainstream Linux). Filters out placeholder values like `To be filled by O.E.M.` and `Default string`. Rows hide if every relevant field is empty.
- **Duplicate-bar-on-reinstall fix** — installer's end-of-install spawn now uses a bulletproof kill loop (SIGTERM × 3 → SIGKILL × 2) followed by a survivor check. If anything survives, the script *refuses* to spawn another and prints diagnostic instructions. Result: exactly one shell after every install. No more stacked bars.

Full per-patch details: [`HOTFIX-v6.16.2.3.6.md`](HOTFIX-v6.16.2.3.6.md)

<br/>

### v6.16.x cumulative (already in this release)

The v6.16.0 → v6.16.2 phases brought:

- **Battery module** — icon / text / bar modes, auto-hides on desktops, color shifts at 10/30/50%, low-battery swaync notifications at 30% warning and 10% critical with hysteresis
- **Power Profile Service** — `powerprofilesctl` wrapper, Saver / Balanced / Performance, persisted via `zen-power-profile-restore.sh`
- **Gaming Boost** — forces performance + disables blur/dim/animations via `hyprctl --batch`, survives shell restarts
- **GPU Switcher** — Auto / Integrated / Dedicated / Auto-Gaming, env vars to `~/.config/environment.d/zen-gpu.conf`, `zen-game-watcher.sh` polls every 3s for Steam, Lutris, Wine, Proton
- **Multi-GPU widget tabs** — Overview / CPU / GPU0 / GPU1 / NET, vendor-colored badges, 420×420 sysmon
- **Volume + Brightness OSD** — XF86 keys emit swaync notifications with 20-char progress bars, no stacking spam
- **Cascade Control Panel** — auto-splits to two columns when tabs overflow, click-outside-to-close
- **Unified HMSwitch** — one centralized pill toggle component, all 27 toggles share the same 150ms OutCubic animation
- **Smooth widget drag** — `_anyDragActive` guard prevents `_applyPositions()` from resetting position mid-drag
- **Widget background picker** — Default / Theme-synced / Custom per widget, 10 swatches + opacity slider
- **Lid close fix** — `lid-behavior.conf` module: Mirror / Keep Internal / Off
- **Hardware auto-detection** — `install.sh` writes `hardware.conf` based on detected GPU topology, NVIDIA driver version, chassis type

<br/>

### v6.15.x cumulative (carried forward)

- Music Strings module (audio-reactive bezier visualizer in the music slot)
- Screenshot rope overlay with physics-simulated ropes (`Super+Shift+S`)
- Complete `SettingsStateV2` Hyprland keyword coverage (~20 keywords were missing)
- 8 iterative layout improvements for music-string positioning across panel mode transitions
- `RowLayout.forceLayout()` for synchronous layout passes
- `zs-restart.sh` selective shell respawn helper
- `install.sh --bootstrap` for fresh Arch-based laptops (KDE/GNOME/COSMIC safe)
- Hyprland 0.54+ syntax migration (`windowrulev2` → `windowrule`, `layerrule` namespace match, etc.)

<br/>

---

<br/>

## Features

<br/>

### Battery, Power & GPU &nbsp;·&nbsp; v6.16+

- Battery module — icon / text / bar modes, auto-hides on desktops
- Low-battery swaync notifications at 30% and 10% with hysteresis
- Power Profile pills in Control Panel (Saver / Balanced / Performance)
- Gaming Boost — performance + compositor effects off with one tap
- Lid close behavior: Mirror / Keep Internal / Off
- `zen-power-profile-restore.sh` persists profile across reboots
- GPU Switcher — Auto / Integrated / Dedicated / Auto-Gaming
- `zen-game-watcher.sh` — 3s poll daemon for Steam, Lutris, Wine, Proton, etc.
- `prime-run <command>` wrapper for one-shot dedicated-GPU launches

<br/>

### Mouse & Input &nbsp;·&nbsp; v6.16.2.3+

- Sensitivity slider (−1.0 to +1.0) live via `hyprctl keyword`
- Scroll factor (0.1 to 3.0)
- Mouse `natural_scroll` toggle
- Touchpad `natural_scroll` toggle (separate)
- Persists to `~/.config/hypr/zen-mouse.conf` (sourced by `hyprland.conf`)
- Two UIs: full Settings page **and** compact Control Panel tab — both bound to the same `MouseSettingsService` singleton

<br/>

### Wallpapers &nbsp;·&nbsp; v6.16.2.3+

- `swww`-powered engine with transition effects
- Local visual picker with thumbnails (`Super+W`)
- "Online" tab — fetches `Gekinzen/images-demo/wallpapers` via the GitHub API, caches to `~/.cache/zen-shell/wallpapers/`
- One-click download + apply
- Default wallpaper auto-fetched on fresh installs
- Random wallpaper (`Super+Shift+W`)

<br/>

### Music Strings &nbsp;·&nbsp; v6.15+

- Audio-reactive bezier visualizer — `cava` drives beat amplitude
- `playerctl` drives artist/title tooltip
- Floating overlay panel — curves bow above and below the bar slot without being clipped
- Color modes: theme (auto blue → purple), synced (follows accent), custom (two color pickers)
- `mask: Region {}` makes the rope overlay click-through (v6.16.2.3.1)
- Loading placeholder with pulsing dot while bar layout settles
- Toggleable in **Settings → General → Strings**

<br/>

### Screenshot Rope Overlay &nbsp;·&nbsp; v6.15+

- `Super+Shift+S` → region screenshot with physics-draped rope ornaments
- 10-segment ropes with tuned gravity / inertia / spring force
- `grim` + `slurp` primary with `flameshot` fallback
- `wl-copy` integration with `setsid` detachment — paste works on first try
- Multi-monitor: rope appears on the monitor where the cursor is

<br/>

### Control Panel &nbsp;·&nbsp; Super+C

- PipeWire volume sliders (input + output)
- WiFi / Bluetooth / LAN toggle switches
- CPU / GPU / RAM / VRAM live stats
- Power Profile pills + Gaming Boost toggle
- Mouse sensitivity tab
- Cascade expand — two-column layout when tabs overflow (v6.16.1)
- Click-through transparent backdrop (v6.16.2.3.2)

<br/>

### Desktop Widgets

- **Clock** — 120px bold, gradient glow, multi-timezone array
- **Weather** — icon-led, 7-day forecast, Open-Meteo (no API key)
- **System Monitor** — CPU/GPU/RAM/Network sparklines, multi-GPU tabs, btop button
- Per-widget background: Default / Theme-synced / Custom (v6.16.1)
- Smooth drag with no ghost trails or frame drops (v6.16.1)
- Per-monitor position persistence

<br/>

### Bar / Panel

- 3 modes: **Full-width**, **Floating**, **Island**
- Drag-reorder modules between left / center / right zones
- 12 module slots: start, taskbar, workspaces, window title, music, sysrow, tray, notifications, clock, weather, sysmonitor, battery
- Adjustable: height, opacity, radius, border, background override
- Display target: all monitors / primary / specific monitor
- Island mode now persists across reboot (v6.16.2.3.1)

<br/>

### Settings App &nbsp;·&nbsp; Zen Settings

Fourteen pages: General, Decoration, Animations, Themes, Displays, Panel, Bar Modules, System Tray, Sound & Network, Notifications, Desktop Widgets, Wallpaper, Battery & Power & GPU, Input.

- Live preview for all changes
- Persists to JSON
- Revert buttons on every section
- Click-through transparent backdrop (v6.16.2.3.2)

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
- Avatar upload with versioned filename + circular OpacityMask render (v6.16.2.3.6)
- Hyprland version tooltip on the WM row in sys-info popover (v6.16.2.3.2)

<br/>

### User Profile

- Versioned avatar files (`user-avatar-<timestamp>.<ext>`) with bare-name symlink
- Diagnostic logging to `/tmp/zen-avatar-debug.log`
- Device + BIOS info from `/sys/class/dmi/id` (no sudo, placeholder strings filtered)

<br/>

### Keybind Cheatsheet &nbsp;·&nbsp; Super+/

- Reads live from Hyprland config
- 8 color-coded categories

<br/>

---

<br/>

## Quick Start

### Stable &nbsp;·&nbsp; v6.15.13 &nbsp;·&nbsp; `main` branch

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

git fetch --tags
git checkout v6.15.13         # pin to exact release
#   — or —
git checkout main             # always the latest commit on the stable branch

chmod +x install.sh
./install.sh --bootstrap      # safe alongside KDE / GNOME / COSMIC
#   — or —
./install.sh                  # if Hyprland + Quickshell already installed
```

### Beta &nbsp;·&nbsp; v6.16.2.3.6 &nbsp;·&nbsp; `beta-v12.6.16.2.3.6` branch

The beta closes out the v6.16.2.3 hotfix series — click-through Settings/Control Panel, native QML hover calendar wiring, OpacityMask avatar fix, default wallpaper auto-fetch, wallpaper repo browser, mouse sensitivity controls, and the duplicate-bar-on-reinstall fix.

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

git checkout beta-v12.6.16.2.3.6

chmod +x install.sh
./install.sh --bootstrap      # safe alongside KDE / GNOME / COSMIC
#   — or —
./install.sh                  # if Hyprland + Quickshell already installed
```

### Verify after install

```bash
# Should print 1 (not 2 or 3)
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Verify mouse settings reached Hyprland
hyprctl getoption input:sensitivity

# Watch avatar uploads
tail -f /tmp/zen-avatar-debug.log
```

### Backup first &nbsp;·&nbsp; recommended

```bash
mv ~/.config/hypr       ~/.config/hypr.backup       2>/dev/null || true
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

`swww` · `grim` · `slurp` · `wl-clipboard` · `flameshot` · `cava` · `playerctl` · `power-profiles-daemon` · `brightnessctl` · `alacritty` · `thunar` · `fuzzel` · `btop` · `swaync` · `nwg-displays` · `nwg-look` · `blueman` · `networkmanager` · `wireplumber` · `pavucontrol` · `zenity` · `libnotify` · `imagemagick`

The installer auto-detects missing packages and offers to install via `paru` > `yay` > `pacman`.

<br/>

---

<br/>

## Architecture

```
~/.config/quickshell/zen-shell/
├── shell.qml                    # Entry point — bar, overlays, widgets
├── Bar.qml                      # Bottom bar with module loader
├── Battery.qml                  # Battery bar module                  ← v6.16
├── MusicStrings.qml             # Music slot placeholder              ← v6.15
├── ZenStrings.qml               # Audio-reactive visualizer           ← v6.15
├── ZenStringsState.qml          # Shared strings state singleton
├── ZenRope.qml                  # Physics rope                        ← v6.15
├── ZenScreenshotOverlay.qml     # Region screenshot + ropes
├── ControlPanel.qml             # Super+C — cascade two-column        ← v6.16.1
├── PowerProfileService.qml      # powerprofilesctl + Gaming Boost     ← v6.16
├── GPUSwitcherService.qml       # GPU selection + env vars            ← v6.16
├── MouseSettingsService.qml     # Mouse sensitivity / scroll          ← v6.16.2.3
├── WallpaperRepoService.qml     # GitHub API listing fetcher          ← v6.16.2.3
├── HMSwitch.qml                 # Unified pill toggle (×27)           ← v6.16.1
├── UserProfileService.qml       # Versioned avatars + DMI info        ← v6.16.2.3.6
├── ZenSettings.qml              # Settings window — 14 pages
├── BatterySettingsPage.qml      # Battery, Power & GPU page           ← v6.16
├── InputPage.qml                # Mouse + scroll page                 ← v6.16.2.3
├── PanelState.qml               # panelStateLoaded() signal           ← v6.16.2.3.1
├── ZenCalendar.qml              # Hover-aware calendar                ← v6.16.2.3.1
├── SettingsStateV2.qml          # Full Hyprland state persistence
└── ...                          # ~73 QML files total

~/.local/bin/
├── zen-screenshot.sh            # Screenshot pipeline
├── zen-cava.sh                  # cava wrapper for ZenStrings
├── zen-volume-notify.sh         # Volume + brightness OSD             ← v6.16
├── zen-power-profile-restore.sh # Profile persistence                 ← v6.16
├── zen-game-watcher.sh          # Auto-Gaming detection               ← v6.16
├── zen-lid-handler.sh           # Lid-close behavior switch           ← v6.16
├── prime-run                    # One-shot dGPU launcher              ← v6.16
├── zs-restart.sh                # Selective nuclear restart
├── regen-terminal-themes.sh     # Alacritty / Fuzzel theme sync
└── regen-swaync-theme.sh        # SwayNC theme sync
```

<br/>

### Strings architecture

```
barWindow (WlrLayer.Top, namespace zen-shell-bar)
└── Bar.qml
    └── musicSlotItem (in RowLayout)
        └── Loader
            ├── MusicWidget.qml       (when strings disabled)
            └── MusicStrings.qml      (when strings enabled)

stringsWindow (WlrLayer.Overlay, namespace zen-shell-strings)
└── ZenStrings.qml
    margins.left   = barWindowLeft + musicSlotLocalX
    implicitHeight = barHeight + 2 × verticalPadding (±60px overflow)
    mask: Region {}                   ← click-through (v6.16.2.3.1)
```

<br/>

---

<br/>

## Locations & state files

| Path | Purpose |
|---|---|
| `~/.config/quickshell/zen-shell/` | All QML files |
| `~/.config/zen-shell/user-avatar-*.png` | Versioned uploaded avatars |
| `~/.config/zen-shell/wallpapers/` | Local wallpaper folder |
| `~/.config/zen-shell/user-profile.json` | Avatar + profile JSON |
| `~/.config/hypr/zen-mouse.conf` | Mouse sensitivity (sourced by hyprland.conf) |
| `~/.config/hypr/modules/hardware.conf` | GPU env vars + VRR (auto-detected) |
| `~/.config/hypr/modules/lid-behavior.conf` | Lid close handlers |
| `~/.config/quickshell/zen-shell/panel-state.json` | Panel mode, bar layout, etc. |
| `~/.config/quickshell/zen-shell/wallpaper-state.json` | Current wallpaper path |
| `~/.cache/zen-shell/wallpapers/listing.json` | Cached GitHub API repo listing |
| `~/.local/bin/zs-restart.sh` | Restart helper (used by nuclear-restart logic) |
| `/tmp/zen-avatar-debug.log` | Avatar upload diagnostic trace |
| `/tmp/zen-shell.log` | Shell stdout/stderr |
| `/tmp/zs-restart.log` | Restart helper trace |

<br/>

---

<br/>

## Diagnostic commands

```bash
# What zen-shell processes are running? (should be 1)
pgrep -fa 'quickshell.*zen-shell|qs.*zen-shell'

# What did the last avatar upload do?
tail -50 /tmp/zen-avatar-debug.log

# What did the last nuclear restart do?
tail -50 /tmp/zs-restart.log

# Live shell logs (errors, warnings, console.log output)
journalctl --user -f -t quickshell

# Avatar Image status — shows file load errors if any
journalctl --user -f | grep -E "AvatarBigImg|FooterAvatar|PopoverAvatar"

# Verify current mouse settings reached Hyprland
hyprctl getoption input:sensitivity
hyprctl getoption input:scroll_factor
hyprctl getoption input:natural_scroll

# Verify mouse settings sourced
cat ~/.config/hypr/zen-mouse.conf
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
| `Super + Shift + S` | Screenshot rope overlay &nbsp;·&nbsp; v6.15+ |
| `Super + Alt + S` | Toggle bar style (round ↔ pill) |
| Clock click | Calendar popup (with month-cycle scroll wheel — v6.16.2.3.1) |
| `Super + T` | Terminal |
| `Super + E` | File Manager |
| `Super + D` / `Super + R` | App Launcher |
| `Super + Q` | Close window |
| `Super + F` | Maximize |
| `Super + G` | Toggle floating |
| `Super + B` | System monitor (btm) |
| `Super + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | Move window to workspace |
| `XF86AudioRaiseVolume` | Volume up + OSD &nbsp;·&nbsp; v6.16+ |
| `XF86AudioLowerVolume` | Volume down + OSD &nbsp;·&nbsp; v6.16+ |
| `XF86AudioMute` | Mute toggle + OSD &nbsp;·&nbsp; v6.16+ |
| `XF86MonBrightnessUp/Down` | Brightness + OSD &nbsp;·&nbsp; v6.16+ |
| `Super + F12` | Screenshot: region (legacy) |
| `Super + Shift + F12` | Screenshot: full monitor |
| `Super + Ctrl + F12` | Screenshot: all screens |
| `Super + Alt + F12` | Flameshot GUI |

<br/>

---

<br/>

## Wallpapers

A curated wallpaper set ships with the installer, plus a fresh-install default that auto-downloads from the image repository. You can also browse the full collection directly.

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

In the shell itself: `Super+W` → **Wallpaper Picker** → toggle to the **Online** tab to browse and apply repo wallpapers without leaving the desktop.

<br/>

---

<br/>

## Re-install (replace running shell cleanly)

The installer's end-of-install launch sequence (v6.16.2.3.6+):

1. Lists all existing `quickshell.*zen-shell` and `qs.*zen-shell` processes
2. SIGTERM × 3 rounds (300ms apart) — graceful shutdown chance
3. SIGKILL × 2 rounds — forced termination
4. **Verifies** nothing survived. If anything did, REFUSES to spawn another and prints diagnostics.
5. `setsid -f quickshell -p ~/.config/quickshell/zen-shell`

Result: exactly ONE shell, every time. No more stacked duplicate bars.

<br/>

---

<br/>

## Changelogs

### v6.16.x

- **[v6.16.x consolidated](CHANGELOG-v6.16.x.md)**
- **[v6.16.2.3.6 hotfix series closeout](HOTFIX-v6.16.2.3.6.md)** — current beta
- [v6.16.1.11](CHANGELOG-v6.16.1.11.md) — Cascade infinite-loop fix
- [v6.16.1.10](CHANGELOG-v6.16.1.10.md) — Cascade-to-side Control Panel
- [v6.16.1](CHANGELOG-v6.16.1.md) — Multi-GPU, GPU Switcher, Gaming Boost, btop, smooth drag
- [v6.16](CHANGELOG-v6.16.md) — Battery, Power Profiles, Volume OSD, Lid Fix

### v6.15.x

- **[v6.15.x consolidated](CHANGELOG-v6.15.x.md)** — overall summary of the entire v6.15 series
- [v6.15.13](CHANGELOG-v6.15.13.md) — Install automation polish (current stable)
- [v6.15.12](CHANGELOG-v6.15.12.md) — Nuclear restart self-suicide fix
- [v6.15.9](CHANGELOG-v6.15.9.md) — `RowLayout.forceLayout()` synchronous layout
- [v6.15.5](CHANGELOG-v6.15.5.md) — Smooth runtime transitions
- [v6.15.2](CHANGELOG-v6.15.2.md) — Music string position + Loading placeholder
- [v6.15.1](CHANGELOG-v6.15.1.md) — Screenshot clipboard + rope physics
- [v6.15](CHANGELOG-v6.15.md) — Music module → ZenStrings + screenshot ropes

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

No. Fourteen settings pages cover every configurable option, with live preview. Changes persist to JSON automatically — no manual editing, no restart.

<br/>

**Does this work on laptops?**

Yes — v6.16 added full laptop support: battery module, low-battery notifications, power profiles, lid close behavior, and Gaming Boost. v6.16.2.3 added mouse sensitivity controls. Everything auto-hides when hardware isn't detected.

<br/>

**I have a dual-GPU laptop (Optimus). Does it support that?**

Yes. GPU Switcher in **Settings → Battery, Power & GPU**. Auto-Gaming mode watches for known games and auto-switches to Performance + dGPU on launch. The installer also writes `~/.config/hypr/modules/hardware.conf` with the right `AQ_DRM_DEVICES` priority based on detected GPU topology.

<br/>

**Why is the beta `v6.16.2.3.6` instead of just `v6.16.3`?**

Because v6.16.2.3 was meant to be a single hotfix; six iterations later it had absorbed enough fixes to functionally close out the v6.16.2 line. v6.16.3 is the next *feature* release — see the [Roadmap](#roadmap) below.

<br/>

**Which distros work?**

Primary support is Arch-based distros (Arch, CachyOS, EndeavourOS, Manjaro). Other distros will work if you have **Hyprland 0.54+** and **Quickshell 0.2.1+** available, but the installer's package detection assumes `paru` / `yay` / `pacman`. On non-Arch distros, install the [Dependencies](#dependencies) manually first, then run `./install.sh` (without `--bootstrap`).

<br/>

---

<br/>

## Roadmap

Zen Shell is actively developed. This is a personal project I enjoy working on and learn a lot from — so expect continuous iteration rather than a "finished" state.

<br/>

### Naming convention

Beta branches always carry the `beta-v12.` prefix. When a phase reaches stable, the prefix is stripped and the branch promotes to `main` as `v6.x.x.x`. Current beta is `beta-v12.6.16.2.3.6` — the closeout of the v6.16.2.3 hotfix series. v6.16.3 is the next *feature* phase.

<br/>

### v6.16.x phase tracker

| Phase | Status | Focus |
|---|---|---|
| **v6.16.0** | ✅ Shipped | Panel · Power · Notifications · Lid Fix |
| **v6.16.1** | ✅ Shipped | Widgets · GPU Smart Switching · Cascade Control Panel · Unified HMSwitch |
| **v6.16.2** | ✅ Shipped | StartMenu polish · Wallpaper repo · Native QML hover calendar · Mouse settings |
| **v6.16.2.3.6** | 🟡 Current beta | v6.16.2.3 hotfix closeout — click-through, OpacityMask avatar, default wallpaper, duplicate-bar fix |
| **v6.16.3** | 🔜 Future | Bar profile badge · Universal widget auto-resize · Fuzzel DPI sizing · Display res dropdown · Power-icons Material-synced · Lid-close hypridle config |

<br/>

### v6.16.3 (future) — what's intentionally held back

These are queued for the next feature release so each can ship clean rather than getting buried in a hotfix:

- [ ] **Bar profile badge widget** — small badge in the bar showing current power profile and/or GPU mode at a glance
- [ ] **Universal widget auto-resize** — currently widgets can look oversized on smaller laptop panels (e.g. Lenovo X270). The fix is **not** Lenovo-specific: every laptop and desktop should auto-scale widgets based on the monitor's resolution, scale factor, and DPI. Per-monitor sizing with a manual override slider for users who want to fine-tune.
- [ ] **Fuzzel auto-sizing per screen DPI** — launcher should pick its own width / row height / icon size from the active monitor's DPI rather than the current fixed values
- [ ] **Display resolution dropdown enumeration fix** — the resolution dropdown in `DisplaysPage` is missing some valid modes the monitor actually supports
- [ ] **Power confirm icons → Material Design + theme-synced** — the Start Menu's shutdown / restart / suspend / log-out confirm icons get a Material Symbols pass and pull color from the active theme palette
- [ ] **Lid-close black screen → separate `hypr-config/` patch** — the lid-close fix that survives every wake scenario lives at the `hypridle` / `hyprlock` layer, not in QML. Ships as a `hypr-config/` overlay patch alongside the QML release.
- [ ] **Clock hover popup parity with CPU/Memory hover** — the clock's hover should match the look-and-feel of the CPU/Memory hover popups, but with calendar content: clickable month selector, month/year navigation, **today's date highlighted with a circle**. Smooth transitions, memory-optimized (no allocations on every hover).
- [ ] **Start logo image picker** — a button in StartMenu settings to pick the logo from a list of distro icons (Arch, CachyOS, Pop!_OS, etc.) plus a custom image option. Smooth fade-in transitions, properly cached so the popover stays snappy.

<br/>

### Longer-term ideas

- [ ] Integrate WiFi/BT logic directly in `ConnectivityPage` (connect / disconnect / forget networks, BT pairing) — replacing the current `nmtui` / `blueman-manager` shell-outs
- [ ] Media player widget — MPRIS in bar + Control Panel
- [ ] Notification history — SwayNC notification log viewer
- [ ] App drawer grid — grid view option for Start Menu all-apps
- [ ] Multi-monitor widget placement — per-monitor desktop widget positions
- [ ] Theme import from URL
- [ ] Bar auto-hide — hide bar on fullscreen or after timeout
- [ ] Lock screen — QML lock with clock + wallpaper blur
- [ ] More OSD overlays — keyboard layout, caps lock
- [ ] Alt+Tab window switcher overlay

<br/>

---

<br/>

## Project Website

<p align="center">
  <a href="https://gekinzen.github.io/zen-shell-site/">
    <img src="https://img.shields.io/badge/gekinzen.github.io%2Fzen--shell--site-0a0a0a?style=for-the-badge" alt="Project website"/>
  </a>
</p>

<p align="center">
  <sub>Project landing page with screenshots, install steps, and links to changelogs and demos.</sub>
</p>

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
