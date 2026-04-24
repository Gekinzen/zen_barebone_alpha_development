<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/hero_desktop.jpg" alt="Zen Shell — v6.16.4.11.2 Kintsugi" width="960"/>
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
  &nbsp;
  <a href="https://www.youtube.com/watch?v=nS2L9dIQbF4">
    <img src="https://img.shields.io/badge/Watch%20Release%20Showcase-d4a85f?style=for-the-badge&labelColor=0a0a0a&logo=youtube&logoColor=white" alt="Watch release showcase"/>
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/v6.16.4.11.2-Kintsugi%20%E5%90%9B%E7%B9%BC%E3%81%8E-b8924e?style=flat-square&labelColor=0a0a0a"/>
  &nbsp;
  <img src="https://img.shields.io/badge/stable-brightgreen?style=flat-square"/>
  &nbsp;
  <img src="https://img.shields.io/badge/v6.16.4.12-Hikari%20alpha%20next-c68a4a?style=flat-square&labelColor=0a0a0a"/>
  &nbsp;
  <img src="https://img.shields.io/badge/v6.16.5-Michi%20planned-7a9068?style=flat-square&labelColor=0a0a0a"/>
  <br/>
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
  <a href="#whats-new-in-v61641x">What's New</a>
  &nbsp;·&nbsp;
  <a href="#features">Features</a>
  &nbsp;·&nbsp;
  <a href="#quick-start">Install</a>
  &nbsp;·&nbsp;
  <a href="#architecture">Architecture</a>
  &nbsp;·&nbsp;
  <a href="#codename-history">Codenames</a>
  &nbsp;·&nbsp;
  <a href="#wallpapers">Wallpapers</a>
  &nbsp;·&nbsp;
  <a href="#changelogs">Changelogs</a>
  &nbsp;·&nbsp;
  <a href="#roadmap">Roadmap</a>
  &nbsp;·&nbsp;
  <a href="#faq">FAQ</a>
  &nbsp;·&nbsp;
  <a href="#previous-showcases--v6153-era">Previous</a>
  &nbsp;·&nbsp;
  <a href="#legacy-archive--2025-alpha-koke--%E8%8B%94">Archive</a>
  &nbsp;·&nbsp;
  <a href="#credits">Credits</a>
</p>

<br/>

> [!NOTE]
> **Stable: v6.16.4.11.2 "Kintsugi" (金継ぎ)** — `main` branch, promoted 2026-04-24. **Next alpha: v6.16.4.12 "Hikari" (光)** (Profile Export/Import). **Next minor: v6.16.5 "Michi" (道)** (in-app Updates Manager).
>
> | Channel | Version | Codename | Notes |
> |---|---|---|---|
> | **Stable** | v6.16.4.11.2 | **Kintsugi 金継ぎ** — *golden-repair* | **Official release** — rolls in the full v4.2 → v4.11 alpha cycle on top of the v4.1 base: widget scale, dark mode, terminal auto-detect, WiFi fix, 4-attempt color picker saga, custom themes, palette relocation, Material-style ZenComboBox with WCAG auto-contrast text, new Kintsugi Light + Kintsugi Dark themes. |
> | **Alpha (next)** | v6.16.4.12 | **Hikari 光** — *light · clarity* | Profile Export/Import — whole-system snapshot JSON (theme + settings + panel + widgets + bar + wallpaper). Shareable with dotfile friends for instant reflection. |
> | **Planned** | v6.16.5 | **Michi 道** — *the way* | In-app Updates Manager — channel picker (Stable / Beta / Alpha), installed version readout, changelog browser, download + apply + rollback. No more terminal git-checkout dance. |

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
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/colorize-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/colorize-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>PaletteBox</b>
<br/><sub>Clickable theme swatches — v4.11.2</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/arrow-drop-down-circle-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/arrow-drop-down-circle-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Material Dropdown</b>
<br/><sub>WCAG auto-contrast — v4.11.2</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/save-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/save-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Custom Themes</b>
<br/><sub>Save · Rename · Delete — v4.11</sub>
</td>
</tr>
<tr>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/color-lens-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/color-lens-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Color Picker</b>
<br/><sub>Quickshell PopupWindow — v4.10</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/dark-mode-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/dark-mode-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Dark Mode Toggle</b>
<br/><sub>GTK3/4 + libadwaita sync — v4.7</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/terminal.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/terminal.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Terminal Auto-detect</b>
<br/><sub>Super+T fallback chain — v4.7</sub>
</td>
</tr>
<tr>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/lock-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/lock-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Lock Screen</b>
<br/><sub>Font sync + weather mood — v6.16.3.6</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/aspect-ratio-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/aspect-ratio-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Widget Scale</b>
<br/><sub>DPI-aware slider — v6.16.3.7</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/bedtime-outline.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/bedtime-outline.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Idle &amp; Sleep</b>
<br/><sub>Configurable cascade — v6.16.3.8</sub>
</td>
</tr>
<tr>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/bolt.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/bolt.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Panic Recovery</b>
<br/><sub>Escape keybind — v6.16.4</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/speed.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/speed.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>PowerBadge</b>
<br/><sub>Profile + GPU pill — v6.16.3.4</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.iconify.design/material-symbols/laptop-chromebook.svg?color=white&height=28">
  <img src="https://api.iconify.design/material-symbols/laptop-chromebook.svg?color=black&height=28" width="28" height="28" alt=""/>
</picture>
<br/><b>Lid-close Patch</b>
<br/><sub>hypridle/hyprlock — v6.16.3.2</sub>
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

<p align="center"><sub>Icons · <a href="https://fonts.google.com/icons">Google Material Symbols</a> (Apache 2.0), served via <a href="https://icon-sets.iconify.design/material-symbols/">Iconify</a>. Auto-switch light/dark via <code>&lt;picture&gt;</code> &nbsp;srcset.</sub></p>

<br/>

> The legacy Python/GTK4 alpha is preserved at [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52) for historical reference. Active development targets the QML rewrite shipped in this branch.

<br/>

---

<br/>

## Demos

### 🟢 Latest · Kintsugi Release Showcase

<p align="center">
  <a href="https://www.youtube.com/watch?v=nS2L9dIQbF4">
    <img src="https://img.youtube.com/vi/nS2L9dIQbF4/maxresdefault.jpg" alt="Zen Shell v6.16.4.11.2 Kintsugi — Release Showcase" width="880"/>
  </a>
</p>

<p align="center">
  <sub>v6.16.4.11.2 · KINTSUGI 金継ぎ · 1:35</sub><br/>
  <b>Zen Shell Kintsugi — Release Showcase</b><br/>
  <i>Panel, wallpaper engine, Material ZenComboBox, Themes with PaletteBox, Control Panel Dark Mode sync, WiFi picker. New Kintsugi Light + Dark themes matching the signature sage / gold / bone / ink palette.</i>
</p>

<br/>

### Historical tours

<table align="center">
<tr>
<td align="center" width="33%">
<a href="https://www.youtube.com/watch?v=dNwGRBhA97g">
  <img src="https://img.youtube.com/vi/dNwGRBhA97g/maxresdefault.jpg" alt="Zen Shell — Full Tour" width="280"/>
</a>
<br/>
<sub>FULL TOUR · v6.15.x ENSŌ</sub>
<br/>
<b>Zen Shell — Full Tour</b>
<br/>
<i>Strings music module, screenshot ropes, settings, and the complete desktop experience.</i>
</td>
<td align="center" width="33%">
<a href="https://www.youtube.com/watch?v=YQxrh5_naMQ">
  <img src="https://img.youtube.com/vi/YQxrh5_naMQ/maxresdefault.jpg" alt="Zen Shell v6.14" width="280"/>
</a>
<br/>
<sub>PREVIOUS SERIES · v6.14 YUGEN</sub>
<br/>
<b>Zen Shell v6.14</b>
<br/>
<i>Theme switching, panel modes, control center.</i>
</td>
<td align="center" width="33%">
<a href="https://www.youtube.com/watch?v=ao89J3DEqiA">
  <img src="https://img.youtube.com/vi/ao89J3DEqiA/maxresdefault.jpg" alt="Zen Shell v6.10 — QML Foundations" width="280"/>
</a>
<br/>
<sub>QML FOUNDATIONS · v6.10 YUGEN</sub>
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
  <i>v6.16.4.11.2 Kintsugi — captured on Hyprland 0.54, Quickshell 0.2.1+ with the Kintsugi Dark theme.</i>
</p>

<br/>

### Wallpaper engine

Full wallpaper picker with folder scanning, slideshow scheduling, transition effects, and the online `Gekinzen/images-demo` repo browser.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_01_wallpaper_picker.gif" alt="Wallpaper picker" width="920"/>
</p>

<br/>

### Animation presets · Material ZenComboBox &nbsp;·&nbsp; v4.11.2

21 community animation presets, live-applied via `hyprctl reload`. The new Material-style `ZenComboBox` auto-contrasts text using WCAG 2.0 luminance — readable on any theme.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_02_animations_dropdown.gif" alt="Animations dropdown" width="920"/>
</p>

<br/>

### Themes page with PaletteBox &nbsp;·&nbsp; v4.11.2

Unified theme engine with 19 built-in themes (including the new **Kintsugi Light** and **Kintsugi Dark**). Click any 60×60 palette box to open the Quickshell PopupWindow color picker with live hex typing.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_03_themes_palette.gif" alt="Themes palette" width="920"/>
</p>

<br/>

### Panel drag-drop + bar modes

Drag modules between Left / Center / Right zones — state persists to `panel-state.json`. Fullwidth ↔ Island mode toggle with `panelStateLoaded` gate prevents the old revert-on-reboot bug.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_04_panel_drag_drop.gif" alt="Panel drag-drop" width="920"/>
</p>

<br/>

### Control Panel + Dark Mode sync &nbsp;·&nbsp; v4.7+

`Super+C` opens Quick Settings — volume sliders, WiFi / Bluetooth / Ethernet, CPU / GPU / RAM / VRAM telemetry, Power Profile, Gaming Boost, and the **Dark Mode toggle** that syncs GTK3/4/libadwaita apps via gsettings + `settings.ini`.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_05_control_panel.gif" alt="Control Panel dark mode" width="920"/>
</p>

<br/>

---

<br/>

## What's New in v6.16.4.1x

v6.16.4.11.2 is the current stable, promoted from the `alpha-v6.16.4.11.2` branch on 2026-04-24. It rolls in **eleven alpha iterations** from the 4.x cycle, on top of the prior 4.1 stable base. The big arc: widget scale awareness, Dark Mode toggle, terminal auto-detect, WiFi Connect fix, a 4-attempt color picker saga that finally landed on Quickshell's native PopupWindow primitive, the custom themes management rework, and the new Kintsugi Light / Dark themes.

<br/>

### v6.16.4.11.2 stable highlights

#### Kintsugi themes &nbsp;·&nbsp; v6.16.4.11.2

- Two new built-in themes matching the signature sage / gold / bone / ink palette
- **Kintsugi Dark** — warm ink bg (`#14140f`) · sage bright fg (`#98b283`) · gold bright accent (`#d4a85f`)
- **Kintsugi Light** — bone bg (`#fafaf7`) · sage-deep fg (`#5f7450`) · gold accent (`#b8924e`)
- Both WCAG AA/AAA compliant
- **Kintsugi Dark is the default for fresh installs only** — existing users keep their selected theme (installer gate: `!exists current-theme.json` → fallback to `tokyo-night.json`)

#### Palette relocation &nbsp;·&nbsp; v6.16.4.11.2

- Theme Palette editor **moved** from General page → Themes page. Single source of truth for theme customization.
- Old General-page `HMSection` preserved via `visible: false` + zero height (*wala tayong babawasan* literal — every binding, state, and callback stays wired)
- New **`PaletteBox.qml`** component — compact 60×60 clickable swatches with hover pencil overlay
- Click any palette box → opens Quickshell PopupWindow picker → HS canvas + Lightness slider + live hex + Apply/Cancel
- Commits to `ThemeService.setAccent(key, hex)` — live re-render across the entire shell

#### Material-style ZenComboBox &nbsp;·&nbsp; v6.16.4.11.2

- Complete visual overhaul of the dropdown
- **WCAG 2.0 luminance-based auto-contrast** text: `L = 0.2126R + 0.7152G + 0.0722B` — readable on any theme (light OR dark, handles mismatched palette fg/bg)
- Rotating chevron indicator (180° on open, smooth cubic-bezier)
- Leading accent dots per item row (solid blue on highlight, 60% fg on current, 25% fg on others)
- Left blue accent bar (3px) on highlighted row
- Rounded 10px popup with subtle offset shadow (no Qt5Compat dep)

#### Custom Themes management &nbsp;·&nbsp; v6.16.4.11

- New "Custom Themes" section on Themes page
- **Save as…** button → zenity name prompt → writes `~/.config/hypr-control-center/themes/custom/<slug>.json`
- **Activate / Rename / Delete** buttons per custom theme row
- New `ThemeService.renameCustomTheme(theme, newName)` function — uses `jq` to rewrite id + name fields, `mv` to new path, re-copies to current-theme.json if active
- Empty state hint when no custom themes exist yet

#### Color Picker PopupWindow rewrite &nbsp;·&nbsp; v6.16.4.10

- Fourth iteration on this feature finally landed
- **Abandoned Qt Quick Popup entirely** — kept hitting Wayland-specific coord system bugs
- Switched to **Quickshell `PopupWindow` primitive** — backed by native `xdg_popup` Wayland surface. Compositor handles positioning, zero coord math.
- **Live hex typing** — hex textbox commits color on every valid 6/8 char keystroke (was previously only on Enter/Tab via `editingFinished`)
- Lesson: when Qt's high-level abstraction keeps misbehaving on Wayland, drop to the platform-native primitive

#### Super+T terminal auto-detect &nbsp;·&nbsp; v6.16.4.7

- `bind = $mainMod, T, exec, ~/.local/bin/zen-terminal.sh` (was hardcoded to `kitty`)
- **Auto-detect chain**: `$ZEN_TERMINAL` env → `~/.config/zen-shell/terminal.conf` → alacritty → kitty → wezterm → foot → ghostty → x-terminal-emulator
- `notify-send` warning if none found
- Logs to `~/.cache/zen-shell/terminal.log`

#### Dark Mode toggle &nbsp;·&nbsp; v6.16.4.7

- New toggle row in Control Panel (Super+C), right after Gaming Boost
- 🌙 / ☀️ icon with HMSwitch visual indicator
- `zen-darkmode.sh` syncs 4 places:
  - `gsettings color-scheme` → `prefer-dark` / `default` (libadwaita + GTK4 apps)
  - `gsettings gtk-theme` → `Adwaita-dark` / `Adwaita` (legacy GTK3 apps)
  - `~/.config/gtk-3.0/settings.ini` with `gtk-application-prefer-dark-theme=1/0`
  - `~/.config/gtk-4.0/settings.ini` same
- State persisted to `~/.local/share/zen-shell/darkmode.state`
- New `DarkModeService.qml` singleton — probes state on load, exposes reactive `isDark` boolean, `toggle()` method
- Override via `$ZEN_GTK_DARK` / `$ZEN_GTK_LIGHT` env vars (defaults `Adwaita-dark` / `Adwaita`)

#### WiFi Connect rewrite &nbsp;·&nbsp; v6.16.4.8

- Fixed the Quick Settings "Connect" button that was silently failing on secured networks
- **Root cause**: `nmcli device wifi connect <SSID>` without password fails silently on secured networks. Prior fix attempts tried type-sniffing arg 2 against a whitelist (`["WPA2", "WPA", "WEP", "WPA3"]`) but nmcli returns composite security strings like `"WPA2 802.1X"`, `"WPA1 WPA2"` — those failed the whitelist and got treated as literal passwords.
- **Fix**: Named-arg pattern — `connectWifi(ssid, security, password)` — no more type-sniffing. Saved-creds preflight via `nmcli -t connection show` → zenity password prompt for new secured networks → direct connect for open.
- **Audit log** at `~/.cache/zen-shell/wifi.log`

#### Gaps + Displays cascade fix &nbsp;·&nbsp; v6.16.4.4

- Changing display resolution via Settings → Displays was wiping runtime gaps_in/gaps_out state
- Root cause: `hyprctl reload` + `hyprctl keyword monitor` both clear runtime keyword overrides
- Fix: `SettingsStateV2.applyToHyprland()` now re-asserts gaps, borders, decoration settings, animation curves after any reload/monitor change

#### Widget scale oscillation fix &nbsp;·&nbsp; v6.16.4.3

- v6.16.4.2 surfaced display scale (100% / 125% / 150%) but didn't wire it to widget rendering
- v6.16.4.3 wired `displayScale` into widget `Layout.preferredWidth/Height` computations
- Killed oscillation loop where applying widget scale triggered a reflow that re-emitted the signal — added `Qt.callLater` debounce + dirty flag

#### Start Menu breathing room &nbsp;·&nbsp; v6.16.4.5

- Pinned app tiles were cramped — tile 64px → 72px, label height 58px → 66px
- Better visual rhythm, long app names no longer clip

#### Wallpaper grid columns &nbsp;·&nbsp; v6.16.4.6

- Grid was too cramped at 1.25× monitor scale with 5 columns
- Changed to 4 columns, page size adjusted to 16 wallpapers per page

Full per-patch details: [`CHANGELOG-ROLLUP-v6.16.4.x.md`](CHANGELOG-ROLLUP-v6.16.4.x.md) · [`CHANGELOG-v6.16.4.11.2.md`](CHANGELOG-v6.16.4.11.2.md) · [`CHANGELOG-v6.16.4.11.md`](CHANGELOG-v6.16.4.11.md) · [`CHANGELOG-v6.16.4.10.md`](CHANGELOG-v6.16.4.10.md)

<br/>

### Carried forward from v6.16.4.1 (still in)

- Panic Recovery keybind (`SUPER+SHIFT+CTRL+Escape`) — 9-step recovery, works through frozen hyprlock
- Full Idle / Lid / Sleep unified UX with live-edit hypridle.conf
- Universal Widget Scale slider (0.5× to 2.0×)
- Lock Screen overhaul — font sync + weather mood + gender-aware care messages
- Clock + SysMonitor hover popup parity
- Start Menu logo picker (7 bundled distro SVGs)
- PowerBadge bar module + lid-close patch + Material power icons
- Every v6.16.2.3.6 fix (click-through, OpacityMask avatar, default wallpaper, repo browser, mouse sensitivity, panelStateLoaded restart gating, DMI device info, bulletproof single-instance installer)

<br/>

---

<br/>

## Features

<br/>

### Theme engine with Kintsugi + Custom Themes &nbsp;·&nbsp; v6.16.4.11.2+

- **19 built-in themes** — including new Kintsugi Light + Kintsugi Dark — plus unlimited user custom themes (JSON-backed)
- Settings → Themes → Palette Preview with clickable PaletteBoxes (v4.11.2)
- Click any 60×60 swatch → Quickshell PopupWindow picker → HS canvas / Lightness slider / live hex typing
- Custom Themes management: Save as… / Activate / Rename / Delete per row
- Storage: `~/.config/hypr-control-center/themes/custom/<slug>.json`
- `ThemeService.renameCustomTheme()` uses `jq` for atomic JSON field rewrite

<br/>

### Dark Mode toggle &nbsp;·&nbsp; v6.16.4.7+

- Super+C → Control Panel toggle row
- 🌙 / ☀️ icon indicator
- `zen-darkmode.sh` syncs gsettings `color-scheme` + GTK3/4 settings.ini + libadwaita
- `DarkModeService.qml` singleton with reactive `isDark` boolean
- State persists at `~/.local/share/zen-shell/darkmode.state`
- Custom GTK theme via `$ZEN_GTK_DARK` / `$ZEN_GTK_LIGHT` env vars

<br/>

### Terminal auto-detect &nbsp;·&nbsp; v6.16.4.7+

- `Super+T` → `zen-terminal.sh`
- Fallback chain: `$ZEN_TERMINAL` env → `~/.config/zen-shell/terminal.conf` → alacritty → kitty → wezterm → foot → ghostty → x-terminal-emulator
- `notify-send` warning if no terminal found
- Logs every launch to `~/.cache/zen-shell/terminal.log`

<br/>

### WiFi Connect (secured networks) &nbsp;·&nbsp; v6.16.4.8+

- `ConnectivityService.connectWifi(ssid, security, password)` with named-arg pattern
- Saved-creds preflight check via `nmcli -t connection show`
- Zenity password prompt for new secured networks
- Audit log at `~/.cache/zen-shell/wifi.log` with timestamps + nmcli output

<br/>

### Panic Recovery keybind &nbsp;·&nbsp; v6.16.4+

- `SUPER+SHIFT+CTRL+Escape` — works **even through frozen hyprlock** (via Hyprland's `bindl` flag, so the bind fires at the compositor level before hyprlock sees the keystroke)
- Runs `~/.local/bin/zen-panic.sh` — 9-step recovery:
  - SIGKILL zombie hyprlock (only if detected via layer-surface count = 0)
  - Double DPMS off→on cycle (AMD GPU needs 2x for KMS resync)
  - `hyprctl dispatch forcerendererreload` — **preserves runtime monitor config** (the 4.1 hotfix — 4.0 was using `hyprctl reload` which wiped DisplaysPage settings)
  - swww-daemon zombie detection + restart + wallpaper re-apply
  - Input subsystem power-cycle (fixes "keystrokes don't reach password field")
  - Clean re-lock if session was locked before panic
- **Single press leaves Quickshell untouched** — bar, widgets, music marquee, drag positions all preserved
- **Double-press within 10s** = full Quickshell restart (escalation path, rare)
- Manual invocation (if even keybind can't fire): SSH or TTY → `~/.local/bin/zen-panic.sh`
- All steps logged to `~/.cache/zen-shell/panic.log` for post-mortem

<br/>

### Idle / Lid / Sleep unified UX &nbsp;·&nbsp; v6.16.3.8+

- Settings → Battery &amp; Power → **Idle &amp; Sleep** section
- Lock after idle: `30s / 1min / 30min / 1h / 3h / 5h / Never`
- Sleep after idle: same options, defaults to Never on desktops
- Lid close action: `Sleep (suspend + lock on wake) / Lock only / Do nothing`
- `zen-hypridle-sync.sh` reads PanelState values, rewrites `hypridle.conf` via sed (on lines marked `# ZEN_IDLE_LOCK`, `# ZEN_IDLE_DPMS`, `# ZEN_IDLE_SLEEP`), restarts hypridle — changes apply live without shell restart
- Pre-suspend health check kills zombie hyprlock before every `systemctl suspend`

<br/>

### Universal Widget Scale &nbsp;·&nbsp; v6.16.3.7+

- Settings → Widgets → **Widget Scale** slider (0.5× to 2.0×, default 1.0×, step 0.05)
- Live-apply — resizes all three desktop widgets (clocks, weather, sysmon) in lockstep
- 68 scale multipliers baked into `DesktopWidgets.qml` via single `dw._scale` property
- Font dependency check added to `install.sh` — offers `adwaita-fonts`, `inter-font`, `gnome-themes-extra`
- Widget positions stored unscaled → drag-and-drop survives scale changes

<br/>

### Lock Screen &nbsp;·&nbsp; v6.16.3.6+

- Clock font matches your desktop widget font exactly — `zen-lock.sh` reads `fontFamilyId` from `panel-state.json`
- Black/Bold weight variants per font (adwaita → `Adwaita Sans Black`, jetbrains → `JetBrainsMono Nerd Font Bold`)
- **Weather mood line** — `Sunny morning ☀️` / `Rainy afternoon 🌧️` / `Starry night sky 🌌` / etc.
- **Rotating care message** — gender-aware pool (Neutral / Male / Female) seeded on minute-of-day
- All messages English-only, pure bash, editable at `~/.local/bin/zen-lock-message.sh`

<br/>

### PowerBadge &nbsp;·&nbsp; v6.16.3.4+

- Tiny pill widget in the bar showing current power profile + GPU mode
- Border color: green (Saver) / blue (Balanced) / orange (Performance) / red (Gaming Boost)
- 300ms hover popup with full state + click-shortcut reference
- Left-click: open Control Panel · Right-click: cycle profile · Middle-click: Gaming Boost
- Self-hides on systems without PPD or multi-GPU

<br/>

### Lid-Close Wake Patch &nbsp;·&nbsp; v6.16.3.2+

- Separate `hypr-config/` overlay patch at the hypridle/hyprlock layer
- Handles every lid scenario: open with external, docked, close+external, close→open cycles
- Session persists, `swaync` stays alive
- Extended in v6.16.3.8 with user-configurable action (suspend/lock/ignore)

<br/>

### Battery, Power &amp; GPU &nbsp;·&nbsp; v6.16+

- Battery module — icon / text / bar modes, auto-hides on desktops
- Low-battery swaync notifications at 30% and 10% with hysteresis
- Power Profile pills in Control Panel (Saver / Balanced / Performance)
- Gaming Boost — performance + compositor effects off with one tap
- GPU Switcher — Auto / Integrated / Dedicated / Auto-Gaming
- `zen-game-watcher.sh` — 3s poll daemon for Steam, Lutris, Wine, Proton
- `prime-run <command>` wrapper for one-shot dedicated-GPU launches

<br/>

### Mouse &amp; Input &nbsp;·&nbsp; v6.16.2.3+

- Sensitivity slider (−1.0 to +1.0) live via `hyprctl keyword`
- Scroll factor (0.1 to 3.0)
- Mouse + Touchpad `natural_scroll` toggles (separate)
- Persists to `~/.config/hypr/zen-mouse.conf`
- Settings page + Control Panel tab — both bound to same singleton

<br/>

### Wallpapers &nbsp;·&nbsp; v6.16.2.3+

- `swww`-powered engine with transition effects
- Local visual picker with thumbnails (`Super+W`)
- "Online" tab — fetches `Gekinzen/images-demo/wallpapers` via GitHub API
- One-click download + apply
- Random wallpaper (`Super+Shift+W`)
- 4-column grid (v6.16.4.6, was 5)

<br/>

### Music Strings &nbsp;·&nbsp; v6.15+

- Audio-reactive bezier visualizer — `cava` drives beat amplitude
- `playerctl` drives artist/title tooltip
- Floating overlay panel — bezier curves bow above and below bar slot
- Color modes: theme / synced / custom
- `mask: Region {}` makes rope click-through

<br/>

### Screenshot Rope Overlay &nbsp;·&nbsp; v6.15+

- `Super+Shift+S` → region screenshot with physics-draped rope ornaments
- 10-segment ropes with tuned gravity / inertia / spring force
- `grim` + `slurp` primary, `flameshot` fallback
- `wl-copy` with `setsid` detachment — paste works on first try

<br/>

### Control Panel &nbsp;·&nbsp; Super+C

- PipeWire volume sliders (input + output)
- WiFi / Bluetooth / LAN toggles (Connect button fixed in v6.16.4.8)
- CPU / GPU / RAM / VRAM live stats
- Power Profile pills + Gaming Boost toggle
- **Dark Mode toggle row** (v6.16.4.7)
- Mouse sensitivity tab
- Cascade expand — two-column layout when tabs overflow
- Click-through transparent backdrop

<br/>

### Desktop Widgets

- **Clock** — 120px bold, gradient glow, multi-timezone array
- **Weather** — icon-led, 7-day forecast, Open-Meteo (no API key)
- **System Monitor** — CPU/GPU/RAM/Network sparklines, multi-GPU tabs, btop button
- Per-widget background: Default / Theme-synced / Custom (persists across restart — v6.16.3.4.1)
- Universal scale slider (0.5× to 2.0×) — v6.16.3.7
- Smooth drag with no ghost trails or frame drops

<br/>

### Bar / Panel

- 3 modes: Full-width · Floating · Island
- Drag-reorder modules between left / center / right zones
- 13 module slots: start, taskbar, workspaces, window title, music, sysrow, tray, notifications, clock, weather, sysmonitor, battery, **powerbadge**
- Adjustable: height, opacity, radius, border, background override
- Display target: all monitors / primary / specific monitor
- Island mode persists across reboot

<br/>

### Settings App &nbsp;·&nbsp; Zen Settings

Fourteen pages: General, Decoration, Animations, **Themes** (with Palette Preview + Custom Themes manager — v4.11.2), Displays, Panel, Bar Modules, System Tray, Sound &amp; Network, Notifications, Desktop Widgets, Wallpaper, Battery &amp; Power &amp; GPU, Input.

- Live preview for all changes
- Theme Palette editor moved to Themes page (v4.11.2)
- **Material-style ZenComboBox** with WCAG auto-contrast (v4.11.2)
- Animations page reflects current hyprctl state (v6.16.3.4.3)
- Persists to JSON
- Revert buttons on every section

<br/>

### Unified Theming System

19 built-in themes auto-synchronize across Quickshell bar, Settings app, Control Panel, SwayNC notifications, Alacritty terminal, and Fuzzel launcher. Plus unlimited user custom themes.

<p align="center">
  <sub><b>Kintsugi Light</b> · <b>Kintsugi Dark</b> · One Dark · Gruvbox · Nord · Tokyo Night · Catppuccin Mocha · Dracula · Solarized Dark · Everforest Dark · Cyberpunk · Lovelace · Yousai · Arc · Adapta · Navy · Black · Paper</sub>
</p>

- Custom theme palette editor on Themes page (v4.11.2)
- Save / Rename / Delete custom themes (v4.11)
- Rice export / import

<br/>

### Start Menu &nbsp;·&nbsp; Super+A

- Win11-style with pinned apps + alphabetical all-apps
- Pinned tiles 72px with breathing room (v4.5)
- Real-time search
- Right-click context menu
- Material Design power confirm icons (v6.16.3.1)
- Distro logo picker — 7 bundled + custom (v6.16.3.5)
- Avatar upload with OpacityMask circular render

<br/>

### User Profile

- Versioned avatar files with bare-name symlink
- **Personal Preferences** — address style for lock messages (Neutral / Male / Female) — v6.16.3.6
- Device + BIOS info from `/sys/class/dmi/id`

<br/>

### Keybind Cheatsheet &nbsp;·&nbsp; Super+/

- Reads live from Hyprland config
- 8 color-coded categories

<br/>

---

<br/>

## Codename history

Each release era gets a codename from Japanese zen vocabulary.

| Codename | Kanji | Meaning | Versions |
|---|---|---|---|
| Wakaba | 若葉 | Young leaf | Alpha v0.91 — Waybar + Python + rofi |
| Koke | 苔 | Moss | Alpha v2.x (v2.1.3) — GTK4 / Libadwaita era |
| Yugen | 幽玄 | Subtle profound grace | v6.10 – v6.14 — QML rewrite |
| Ensō | 円相 | The zen circle | v6.15.x · v6.16 base — unified stack |
| Ma | 間 | The space between | v6.16.1.x — cascade Control Panel |
| Shibui | 渋い | Understated refinement | v6.16.2.3.x — click-through masks |
| Sabi | 寂 | Beauty of age &amp; patina | v6.16.3.x — lock screen, PowerBadge |
| **Kintsugi** | **金継ぎ** | **Golden-repair** | **v6.16.4.x · v6.16.4.11.2** — 🟢 current stable |
| Hikari *(next)* | 光 | Light · clarity | v6.16.4.12 — Profile Export/Import |
| Michi *(planned)* | 道 | The way | v6.16.5 — in-app Updates Manager |

<br/>

---

<br/>

## Quick Start

### Stable &nbsp;·&nbsp; v6.16.4.11.2 Kintsugi &nbsp;·&nbsp; `main` branch

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

git fetch --tags
git checkout v6.16.4.11.2     # pin to exact release
#   — or —
git checkout main             # always the latest commit on stable

chmod +x install.sh
./install.sh --bootstrap      # safe alongside KDE / GNOME / COSMIC
#   — or —
./install.sh                  # if Hyprland + Quickshell already installed
```

On fresh install the dependency check will offer `adwaita-fonts` / `inter-font` / `gnome-themes-extra` / `zenity` / `jq` via `paru -S --needed`. `zenity` is required from v4.7+ (Dark Mode prompts) and v4.11+ (custom theme save/rename prompts). `jq` required for v4.11+ custom theme rename.

### Expected install output

```
[7/9] Themes...
    19 builtin themes
    ★ NEW: Kintsugi Light + Kintsugi Dark (v6.16.4.11.2 codename palette)
    Default theme: kintsugi-dark (Kintsugi 金継ぎ)
...
╔═══════════════════════════════════════════════════════════════╗
║     🎉  ZEN SHELL v6.16.4.11.2 · KINTSUGI INSTALLED  🎉      ║
╚═══════════════════════════════════════════════════════════════╝

  ── Install summary ──
    QML files installed:   76
    Toggle scripts:        22 in /home/you/.local/bin
    Builtin themes:        19
    Active theme:          kintsugi-dark
```

### Verify after install

```bash
# Should print 1 (not 2 or 3)
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Verify version
grep "version" ~/.config/quickshell/zen-shell/ZenVersion.qml | head -1
# → readonly property string version: "v6.16.4.11.2"

# Confirm Kintsugi themes present
ls ~/.config/hypr-control-center/themes/builtin/ | grep kintsugi
# → kintsugi-dark.json
# → kintsugi-light.json

# Confirm active theme
cat ~/.config/hypr-control-center/current-theme.json | grep '"id"'
# → "id": "kintsugi-dark"

# Verify panic keybind is registered (v6.16.4+)
hyprctl binds | grep -i zen-panic

# Verify Super+T uses zen-terminal.sh (v4.7+)
hyprctl binds | grep zen-terminal

# Verify hypridle timeouts synced from PanelState (v6.16.3.8+)
grep ZEN_IDLE ~/.config/hypr/hypridle.conf

# Verify widget scale setting persisted (v6.16.3.7+)
jq .widgetScale ~/.local/share/quickshell/zen-shell/panel-state.json

# Check dark mode state (v4.7+)
cat ~/.local/share/zen-shell/darkmode.state 2>/dev/null || echo "not yet toggled"

# Test panic recovery (safe — no damage)
~/.local/bin/zen-panic.sh
cat ~/.cache/zen-shell/panic.log | tail -30
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

- [Quickshell](https://github.com/quickshell-mirror/quickshell) 0.2.1+ with **`PopupWindow` support** — required by v4.10+ color picker
- [Hyprland](https://hyprland.org/) 0.54+ — Wayland compositor (new `windowrule` / `layerrule` anonymous syntax used throughout)
- `jq` — JSON processor (required for custom theme rename in v4.11+)
- `zenity` — GTK dialog prompts (required for Dark Mode + custom theme flows in v4.7+)

**Recommended** &nbsp;·&nbsp; most auto-installed by `--bootstrap`

`swww` · `grim` · `slurp` · `wl-clipboard` · `flameshot` · `cava` · `playerctl` · `power-profiles-daemon` · `brightnessctl` · `alacritty` · `thunar` · `fuzzel` · `btop` · `swaync` · `nwg-displays` · `nwg-look` · `blueman` · `networkmanager` · `wireplumber` · `pavucontrol` · `libnotify` · `imagemagick` · `hypridle` · `hyprlock` · `adwaita-fonts` · `inter-font` · `gnome-themes-extra`

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
├── PowerBadge.qml               # Profile + GPU pill                  ← v6.16.3.4
├── MusicStrings.qml             # Music slot placeholder              ← v6.15
├── ZenStrings.qml               # Audio-reactive visualizer           ← v6.15
├── ZenClock.qml                 # Clock bar module + hover popup      ← v6.16.3.6
├── ZenSysMonitor.qml            # SysMonitor + PopupWindow hover      ← v6.16.3.6
├── ZenRope.qml                  # Physics rope                        ← v6.15
├── ZenScreenshotOverlay.qml     # Region screenshot + ropes
├── ControlPanel.qml             # Super+C + Dark Mode toggle row      ← v4.7
├── DarkModeService.qml          # GTK3/4 + libadwaita sync            ← v4.7
├── ColorSwatch.qml              # Hex input + PopupWindow picker      ← v4.10
├── PaletteBox.qml               # Compact 60×60 clickable swatch      ← v4.11.2
├── ZenComboBox.qml              # Material-style + WCAG contrast      ← v4.11.2
├── PowerProfileService.qml      # powerprofilesctl + Gaming Boost     ← v6.16
├── GPUSwitcherService.qml       # GPU selection + env vars            ← v6.16
├── MouseSettingsService.qml     # Mouse sensitivity / scroll          ← v6.16.2.3
├── WallpaperRepoService.qml     # GitHub API listing fetcher          ← v6.16.2.3
├── ThemeService.qml             # Palette + custom theme CRUD         ← ext v4.11
├── HMSwitch.qml                 # Unified pill toggle (×27)           ← v6.16.1
├── UserProfileService.qml       # Versioned avatars + DMI info        ← v6.16.2.3.6
├── UserProfilePage.qml          # +Personal Preferences (gender)      ← v6.16.3.6
├── ZenSettings.qml              # Settings window — 14 pages
├── GeneralPage.qml              # Palette editor hidden (moved)       ← ext v4.11.2
├── ThemesPage.qml               # +Palette Preview clickable +Custom  ← ext v4.11.2
├── BatterySettingsPage.qml      # +Idle&Sleep +Panic Recovery         ← v6.16.3.8 / .4
├── WidgetsPage.qml              # +Widget Scale slider                ← v6.16.3.7
├── InputPage.qml                # Mouse + scroll page                 ← v6.16.2.3
├── DesktopWidgets.qml           # 68 scale multipliers                ← v6.16.3.7
├── PanelState.qml               # +widgetScale +idleLock/Sleep +lid   ← v6.16.3.7/.8
├── ZenCalendar.qml              # Hover-aware calendar                ← v6.16.2.3.1
├── SettingsStateV2.qml          # Full Hyprland state persistence
├── ZenVersion.qml               # Single version source of truth
└── ...                          # ~80 QML files total

~/.config/hypr-control-center/themes/
├── builtin/
│   ├── kintsugi-dark.json           ← NEW in v6.16.4.11.2 (default)
│   ├── kintsugi-light.json          ← NEW in v6.16.4.11.2
│   ├── tokyo-night.json
│   ├── nord.json
│   ├── gruvbox.json
│   └── ... (14 more)
└── custom/                          ← user custom themes (v4.11+)

~/.local/bin/
├── zen-screenshot.sh            # Screenshot pipeline
├── zen-cava.sh                  # cava wrapper for ZenStrings
├── zen-volume-notify.sh         # Volume + brightness OSD             ← v6.16
├── zen-power-profile-restore.sh # Profile persistence                 ← v6.16
├── zen-game-watcher.sh          # Auto-Gaming detection               ← v6.16
├── zen-lid-handler.sh           # Lid-close + action override         ← v6.16.3.8
├── zen-lock.sh                  # Lock launcher + font sync           ← v6.16.3.6
├── zen-lock-message.sh          # Weather mood + gender-aware care    ← v6.16.3.6
├── zen-hypridle-sync.sh         # PanelState → hypridle.conf sed      ← v6.16.3.8
├── zen-panic.sh                 # Escape hatch recovery               ← v6.16.4
├── zen-resume-handler.sh        # Post-suspend recovery pipeline      ← v6.16.4.1
├── zen-terminal.sh              # Terminal auto-detect launcher       ← v4.7
├── zen-darkmode.sh              # GTK3/4 + libadwaita mode switcher   ← v4.7
├── zen-bar-add-powerbadge.sh    # Opt-in PowerBadge inserter          ← v6.16.3.4
├── prime-run                    # One-shot dGPU launcher              ← v6.16
├── zs-restart.sh                # Selective nuclear restart
├── regen-terminal-themes.sh     # Alacritty / Fuzzel theme sync
└── regen-swaync-theme.sh        # SwayNC theme sync

hypr-config/                     # Separate overlay patches
├── hypridle.conf                # With ZEN_IDLE_* markers             ← v6.16.3.8
├── hyprlock.conf                # With ZEN_FONT_OVERRIDE_* markers    ← v6.16.3.6
├── binds.conf                   # +bindl panic keybind                ← v6.16.4
├── keybinds-update.conf         # Super+T → zen-terminal.sh           ← v4.7
├── lid-behavior.conf            # Lid switch → zen-lid-handler.sh
└── autostart.conf

~/.local/share/quickshell/zen-shell/
└── logos/                       # 7 bundled distro SVGs               ← v6.16.3.5
    ├── arch.svg · cachyos.svg · endeavouros.svg · fedora.svg
    └── ubuntu.svg · nixos.svg · linux.svg
```

<br/>

---

<br/>

## Locations &amp; state files

| Path | Purpose |
|---|---|
| `~/.config/quickshell/zen-shell/` | All QML files |
| `~/.local/share/quickshell/zen-shell/panel-state.json` | Panel mode · widget scale · idle timeouts · lid action · font ID · user gender |
| `~/.local/share/quickshell/zen-shell/logos/` | Bundled + custom Start Menu logos (v6.16.3.5) |
| `~/.config/zen-shell/user-avatar-*.png` | Versioned uploaded avatars |
| `~/.config/zen-shell/wallpapers/` | Local wallpaper folder |
| `~/.config/zen-shell/user-profile.json` | Avatar + profile JSON |
| `~/.config/zen-shell/terminal.conf` | Preferred terminal override (v4.7+) |
| `~/.config/hypr/zen-mouse.conf` | Mouse sensitivity |
| `~/.config/hypr/modules/hardware.conf` | GPU env vars + VRR |
| `~/.config/hypr/modules/lid-behavior.conf` | Lid bindl switch |
| `~/.config/hypr/hypridle.conf` | Sed-templated idle timeouts (v6.16.3.8) |
| `~/.config/hypr/hyprlock.conf` | Sed-templated font sync (v6.16.3.6) |
| `~/.config/hypr-control-center/themes/builtin/*.json` | 19 built-in themes (incl. Kintsugi) |
| `~/.config/hypr-control-center/themes/custom/*.json` | User custom themes (v4.11+) |
| `~/.config/hypr-control-center/current-theme.json` | Active theme pointer |
| `~/.config/gtk-3.0/settings.ini` | Synced by Dark Mode toggle (v4.7+) |
| `~/.config/gtk-4.0/settings.ini` | Synced by Dark Mode toggle (v4.7+) |
| `~/.local/share/zen-shell/darkmode.state` | Persisted dark/light choice (v4.7+) |
| `~/.config/quickshell/zen-shell/bar-layout.json` | Per-row module order |
| `~/.config/quickshell/zen-shell/wallpaper-v5.json` | Current wallpaper path |
| `~/.cache/zen-shell/wallpapers/listing.json` | Cached GitHub API repo listing |
| `~/.cache/zen-shell/panic.log` | Panic recovery audit log (v6.16.4) |
| `~/.cache/zen-shell/lid.log` | Lid-handler audit log |
| `~/.cache/zen-shell/resume.log` | Post-suspend pipeline log |
| `~/.cache/zen-shell/hypridle-sync.log` | hypridle sync audit log |
| `~/.cache/zen-shell/lock.log` | zen-lock.sh audit log |
| `~/.cache/zen-shell/wifi.log` | WiFi connect audit trail (v4.8+) |
| `~/.cache/zen-shell/terminal.log` | Terminal launch trace (v4.7+) |
| `~/.cache/zen-shell/darkmode.log` | GTK mode switch trace (v4.7+) |
| `/tmp/zen-shell.log` | Shell stdout/stderr |

<br/>

---

<br/>

## Keybinds

| Keybind | Action |
|---|---|
| `Super + C` | Control Panel (with Dark Mode toggle — v4.7+) |
| `Super + A` | Start Menu |
| `Super + ,` | Zen Settings |
| `Super + W` | Wallpaper Picker |
| `Super + Shift + W` | Random Wallpaper |
| `Super + /` | Keybind Cheatsheet |
| `Super + Shift + S` | Screenshot rope overlay &nbsp;·&nbsp; v6.15+ |
| `Super + Alt + S` | Toggle bar style (round ↔ pill) |
| **`Super + Shift + Ctrl + Esc`** | **Panic recovery keybind** (works through frozen hyprlock) &nbsp;·&nbsp; **v6.16.4+** |
| Clock click | Calendar popup (with month-cycle scroll wheel) |
| Clock hover | Live time + ISO week + timezone popup &nbsp;·&nbsp; v6.16.3.6+ |
| SysMonitor hover | CPU / GPU / Memory / Network popup &nbsp;·&nbsp; v6.16.3.6+ |
| PowerBadge right-click | Cycle power profile &nbsp;·&nbsp; v6.16.3.4+ |
| PowerBadge middle-click | Toggle Gaming Boost &nbsp;·&nbsp; v6.16.3.4+ |
| `Super + T` | Terminal (auto-detect) &nbsp;·&nbsp; **v4.7+** |
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
| `XF86MonBrightnessUp/Down` | Brightness + OSD &nbsp;·&nbsp; v6.16+ (ROG-detected in v6.16.3.4.4+) |
| `Super + F12` | Screenshot: region (legacy) |
| `Super + Shift + F12` | Screenshot: full monitor |
| `Super + Ctrl + F12` | Screenshot: all screens |
| `Super + Alt + F12` | Flameshot GUI |

<br/>

---

<br/>

## Wallpapers

A curated wallpaper set ships with the installer, plus a fresh-install default that auto-downloads from the image repository.

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

In the shell: `Super+W` → **Wallpaper Picker** → toggle to the **Online** tab.

<br/>

---

<br/>

## Changelogs

### v6.16.4.1x &nbsp;·&nbsp; current stable cycle (Kintsugi)

- **[v6.16.4.11.2](CHANGELOG-v6.16.4.11.2.md)** — Kintsugi themes + Palette relocation + Material dropdown + PaletteBox ✅ **CURRENT STABLE**
- **[v6.16.4.11](CHANGELOG-v6.16.4.11.md)** — Custom Themes management (Save/Rename/Delete) ✅
- **[v6.16.4.10](CHANGELOG-v6.16.4.10.md)** — ColorPicker PopupWindow rewrite + live hex typing ✅
- **[v6.16.4.9](CHANGELOG-v6.16.4.9.md)** — ColorPicker window bounds (still buggy) ✅
- **[v6.16.4.8](CHANGELOG-v6.16.4.8.md)** — WiFi named-arg rewrite + audit log + ColorPicker LEFT v2 ✅
- **[v6.16.4.7](CHANGELOG-v6.16.4.7.md)** — Super+T terminal auto-detect + Dark Mode toggle ✅
- **[v6.16.4.6](CHANGELOG-v6.16.4.6.md)** — Wallpaper cols 5→4 + WiFi v1 + ColorPicker v1 ✅
- **[v6.16.4.5](CHANGELOG-v6.16.4.5.md)** — Start Menu pinned tile breathing room ✅
- **[v6.16.4.4](CHANGELOG-v6.16.4.4.md)** — Gaps preserved after Displays apply ✅
- **[v6.16.4.3](CHANGELOG-v6.16.4.3.md)** — Widget scale applied + oscillation killed ✅
- **[v6.16.4.2](CHANGELOG-v6.16.4.2.md)** — Widget scale + display resolution awareness ✅
- **[CHANGELOG-ROLLUP-v6.16.4.x.md](CHANGELOG-ROLLUP-v6.16.4.x.md)** — combined rollup ✅

### v6.16.4.x base

- **[v6.16.4.1](CHANGELOG-v6.16.4.1.md)** — Panic script hotfix (reload wipe, SIGUSR2 kill, music loop) ✅
- **[v6.16.4](CHANGELOG-v6.16.4.md)** — Laptop reliability pass — panic keybind + hardened resume ✅

### v6.16.3.x (Sabi)

- **[v6.16.3.8](CHANGELOG-v6.16.3.8.md)** — Idle / Lid / Sleep unified UX ✅
- **[v6.16.3.7](CHANGELOG-v6.16.3.7.md)** — Universal widget scale + font deps ✅
- **[v6.16.3.6.1](CHANGELOG-v6.16.3.6.1.md)** — Lock clock weight fix ✅
- **[v6.16.3.6](CHANGELOG-v6.16.3.6.md)** — Hover popup parity + Lock screen overhaul ✅
- **[v6.16.3.5](CHANGELOG-v6.16.3.5.md)** — Start Menu logo picker ✅
- **[v6.16.3.4](CHANGELOG-v6.16.3.4.md)** — PowerBadge widget ✅
- **[v6.16.3.3](CHANGELOG-v6.16.3.3.md)** — Display resolution dropdown fix ✅
- **[v6.16.3.2](CHANGELOG-v6.16.3.2.md)** — Lid-close hypridle/hyprlock patch ✅
- **[v6.16.3.1](CHANGELOG-v6.16.3.1.md)** — Material Power Icons ✅

### v6.16.x &nbsp;·&nbsp; Ensō / Ma / Shibui

- **[v6.16.x consolidated](CHANGELOG-v6.16.x.md)**
- **[v6.16.2.3.6 hotfix series closeout](HOTFIX-v6.16.2.3.6.md)**
- [v6.16.1.11](CHANGELOG-v6.16.1.11.md) — Cascade infinite-loop fix
- [v6.16.1.10](CHANGELOG-v6.16.1.10.md) — Cascade-to-side Control Panel
- [v6.16.1](CHANGELOG-v6.16.1.md) — Multi-GPU, GPU Switcher, Gaming Boost
- [v6.16](CHANGELOG-v6.16.md) — Battery, Power Profiles, Volume OSD

### v6.15.x &nbsp;·&nbsp; Ensō

- **[v6.15.x consolidated](CHANGELOG-v6.15.x.md)**
- [v6.15.13](CHANGELOG-v6.15.13.md) — Install automation polish
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

Yes. `./install.sh --bootstrap` is designed for KDE / GNOME / COSMIC users — it adds Hyprland as a session option without touching your display manager or current DE.

<br/>

**Why 11 iterations in the 4.x alpha cycle?**

Software. The color picker alone took 4 iterations (4.6 → 4.8 → 4.9 → 4.10) before landing on the right abstraction (Quickshell's `PopupWindow` primitive instead of Qt Quick's `Popup`). WiFi Connect also needed a second pass (4.6 broken → 4.8 fixed). This is exactly what an alpha branch is for — flush out the bugs before promoting to stable.

<br/>

**What's the PaletteBox in v4.11.2?**

A compact 60×60 clickable color swatch with a pencil-icon hover overlay. Lives on the Themes page → Palette Preview. Click any box (bg0 / bg1 / fg / blue / red / etc.) → opens a Quickshell PopupWindow with HS canvas + Lightness slider + live hex textbox. Changes commit via `ThemeService.setAccent(key, hex)` and re-render the whole shell live. The hex textbox updates on every valid 6/8 char keystroke — no need to press Enter.

<br/>

**The dropdown text is readable regardless of theme — how?**

v4.11.2's `ZenComboBox` uses WCAG 2.0 relative luminance: `L = 0.2126R + 0.7152G + 0.0722B`. Checks the actual rendered background color (main field, popup, highlighted item — each has different bg), picks white (`#f5f5f5`) or near-black (`#1a1a1a`) based on whether L > 0.5. Works even when custom themes have mismatched fg/bg.

<br/>

**Why "Kintsugi"?**

金継ぎ is the Japanese art of repairing broken pottery by mending the cracks with gold lacquer — the breaks aren't hidden, they're illuminated as part of the object's history. The v4.x cycle took 11 alpha iterations to land, including a 4-attempt color picker saga. The codename honors that: the seams are visible, the repair *is* the art.

<br/>

**Will Kintsugi replace my current theme when I upgrade?**

No. The installer sets Kintsugi Dark as the default **only for fresh installs** (gated by `!exists ~/.config/hypr-control-center/current-theme.json`). Existing users keep their selected theme. If you want to switch: Settings → Themes → Kintsugi Dark / Kintsugi Light.

<br/>

**I pressed the panic keybind — what just happened?**

`SUPER+SHIFT+CTRL+Esc` runs `~/.local/bin/zen-panic.sh` which does a 9-step recovery sequence: kill zombie hyprlock if detected, double DPMS cycle, force renderer reload (preserves monitor config — unlike `hyprctl reload`), revive swww-daemon if zombied, clean re-lock if session was locked, input subsystem kick. **Your Quickshell keeps running** — bar, widgets, music marquee, drag positions all preserved. Only double-press within 10 seconds escalates to full Quickshell restart. Log at `~/.cache/zen-shell/panic.log`.

<br/>

**Does this work on laptops?**

Yes — v6.16.3.8 added full Idle/Sleep/Lid configurability (Settings → Battery &amp; Power → Idle &amp; Sleep). v6.16.4 added the panic recovery keybind specifically for the "force-power-off my laptop" scenarios. v6.16.3.4.4 fixed ROG brightness detection. Everything auto-hides when hardware isn't detected.

<br/>

**Why is stable `v6.16.4.11.2` and not `v6.17`?**

Because the v6.16 phase has been an uninterrupted run of shipping since v6.16.0. Each `.x.y.z` bump corresponds to a clean feature drop or hotfix. `v6.17` will follow after Phase 4 items (hyprbars, float/tile assignment GUI, auto-clean memory) and Phase 5 (in-app updates manager — v6.16.5 Michi) ship.

<br/>

**Which distros work?**

Primary support is Arch-based distros (Arch, CachyOS, EndeavourOS, Manjaro). Other distros will work with **Hyprland 0.54+** and **Quickshell 0.2.1+** (with PopupWindow support), but the installer assumes `paru` / `yay` / `pacman`.

<br/>

---

<br/>

## Roadmap

Zen Shell is actively developed. Continuous iteration rather than a "finished" state.

<br/>

### Naming convention

Once a phase reaches stable, the branch promotes to `main` as `v6.x.x.x`. Current stable is `v6.16.4.11.2 Kintsugi` on `main`. Next work is `v6.16.4.12 Hikari` (Profile Export/Import) on an alpha branch until stable, then `v6.16.5 Michi` (in-app Updates Manager).

<br/>

### Phase tracker — all shipped

| Phase | Status | Focus |
|---|---|---|
| **v6.16.3.1** | ✅ Shipped | Material Power Icons (theme-synced) |
| **v6.16.3.2** | ✅ Shipped | Lid-close hypridle/hyprlock overlay patch |
| **v6.16.3.3** | ✅ Shipped | Display resolution dropdown enumeration fix |
| **v6.16.3.4** | ✅ Shipped | PowerBadge bar module |
| **v6.16.3.4.1 – .4.4** | ✅ Shipped | Widget color persistence / animations live-reload / ROG brightness |
| **v6.16.3.5** | ✅ Shipped | Start Menu logo picker (7 bundled + custom) |
| **v6.16.3.6** | ✅ Shipped | Clock/SysMonitor hover parity + Lock screen overhaul |
| **v6.16.3.6.1** | ✅ Shipped | Lock clock weight fix (Black/Bold variants) |
| **v6.16.3.7** | ✅ Shipped | Universal widget scale slider + font dep check |
| **v6.16.3.8** | ✅ Shipped | Idle / Lid / Sleep configurable cascade |
| **v6.16.4** | ✅ Shipped | Laptop reliability — panic keybind + hardened resume |
| **v6.16.4.1** | ✅ Shipped | Panic script hotfix — reload wipe, SIGUSR2, music loop |
| **v6.16.4.2 – .5** | ✅ Shipped | Widget scale / gaps preserved / Start Menu breathing |
| **v6.16.4.6 – .9** | ✅ Shipped | Wallpaper cols / WiFi / ColorPicker iterations |
| **v6.16.4.10** | ✅ Shipped | ColorPicker PopupWindow rewrite + live hex typing |
| **v6.16.4.11** | ✅ Shipped | Custom Themes management (Save / Rename / Delete) |
| **v6.16.4.11.2** | 🟢 **Current stable** | Kintsugi themes + Palette relocation + Material dropdown + WCAG contrast |

<br/>

### Up next

<br/>

#### v6.16.4.12 Hikari 光 — Profile Export/Import (next alpha cycle)

Phase 2 of the themes/profiles work. The "big cousin" of v4.11's Custom Themes management.

**New files planned:**
- `UserProfileExportService.qml` — full-system snapshot singleton
- `ProfileManagerSection.qml` — UI component (top of GeneralPage, additive)

**What a profile captures** (everything portable):
- [ ] Active theme + all custom themes (embedded palettes)
- [ ] Settings V2 full dump (gaps/borders/decorations/animations)
- [ ] Panel state (island mode, bar layout)
- [ ] Widget layout
- [ ] Bar layout
- [ ] Wallpaper basename + mode

**Storage:**

```
~/.config/zen-shell/profiles/
├── active-profile.state      ← name of currently loaded profile
├── default.json
├── gaming-setup.json
└── <user-named>.json
```

Shareable as portable JSON — friends with same dotfiles can import and auto-reflect. Rename / Delete / Activate per profile. Persists across shell restart.

<br/>

#### v6.16.5 Michi 道 — In-app Updates Manager

- [ ] **Channel picker** — Official (tagged releases) / Beta (pre-tag branches) / Alpha (active development)
- [ ] **Installed version readout** — "v6.16.4.11.2 · main ✓ current"
- [ ] **Available updates list** — changelog viewer per version
- [ ] **Download + execute** — grabs tarball from GitHub Releases API, runs install.sh
- [ ] **Rollback support** — fetched versions stored in `~/.local/share/zen-shell/versions/`, switch with one click
- [ ] **Notification on new release** — swaync popup when new version on chosen channel
- [ ] **Skip version** toggle
- [ ] **Global Hyprland `configreloaded` IPC listener** — architectural cleanup. Currently each Settings page has its own Process + `applyToHyprland()`. One singleton replaces all of that.

Website mockup already staged at the project site.

<br/>

#### Phase 4 — UX polish (multi-version, likely v6.16.6 → v6.16.9)

- [x] **Hyprland dark mode + GTK3/4 theming sync** &nbsp;·&nbsp; ✅ shipped in v4.7
- [x] **Kintsugi Light + Dark themes** &nbsp;·&nbsp; ✅ shipped in v4.11.2
- [ ] **hyprbars + recreate minimize mode** — Hyprland's hyprbars plugin with title-bar per window + minimize / maximize / close buttons. Useful for users transitioning from GNOME / KDE.
- [ ] **Float / tile assignment rules GUI** — visual editor for Hyprland's `windowrule`s. Assign an app to always float, always tile, always fullscreen, etc. Saves to `windowrules.conf` module. Preview which apps match each rule.
- [ ] **Auto-clean memory** — service watches free memory, triggers `echo 3 > /proc/sys/vm/drop_caches` when threshold hit. Settings → Battery &amp; Power → Auto-clean memory toggle + threshold slider.
- [ ] **`nwg-look` bridge** — icon/cursor theme picker in Zen Settings

<br/>

### Longer-term ideas

- [ ] Integrate WiFi / BT logic directly in `ConnectivityPage` (connect / disconnect / forget / BT pairing) — replacing `nmtui` / `blueman-manager` shell-outs
- [ ] Media player widget — MPRIS in bar + Control Panel
- [ ] Notification history — SwayNC notification log viewer
- [ ] App drawer grid — grid view option for Start Menu all-apps
- [ ] Theme import from URL
- [ ] Bar auto-hide — hide on fullscreen or after timeout
- [ ] More OSD overlays — keyboard layout, caps lock
- [ ] Alt+Tab window switcher overlay
- [ ] Color eyedropper for PaletteBox (via `hyprpicker`)
- [ ] Theme export to matching GTK3/4 theme (Thunar / GNOME apps match palette exactly)

<br/>

---

<br/>

## Project Website

<p align="center">
  <a href="https://gekinzen.github.io/zen-shell-site/">
    <img src="https://img.shields.io/badge/gekinzen.github.io%2Fzen--shell--site-0a0a0a?style=for-the-badge" alt="Project website"/>
  </a>
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

## Previous showcases &nbsp;·&nbsp; v6.15.3 era

<p align="center">
  <sub>ENSŌ 円相 — preserved so the evolution stays visible. Captured before the v4.x Kintsugi alpha cycle began.</sub>
</p>

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png" alt="Zen Shell v6.15.3 desktop composition" width="880"/>
</p>

<p align="center"><sub><b>v6.15.3 · Desktop composition</b> — status bar, clock hover popup, music strings, desktop widgets.</sub></p>

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png" alt="Zen Shell v6.15.3 workspace" width="880"/>
</p>

<p align="center"><sub><b>v6.15.3 · Workspace</b> — island mode bar + Control Panel with quick toggles.</sub></p>

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png" alt="Zen Shell v6.15.3 settings pages" width="880"/>
</p>

<p align="center"><sub><b>v6.15.3 · Settings</b> — pre-relocation settings layout before the v4.11.2 Themes page refactor.</sub></p>

<br/>

### Adaptive theming

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_01_adaptive_theming.gif" alt="Adaptive theming" width="880"/>
</p>

<p align="center"><sub>One palette. Every surface — bar, settings, control panel, notifications, terminal, launcher.</sub></p>

<br/>

### Settings tour

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_02_settings_tour.gif" alt="Settings tour" width="880"/>
</p>

<p align="center"><sub>Fourteen pages of live-preview configuration. No config files. No restart.</sub></p>

<br/>

### Screenshot module · ultrawide

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_03_screenshot_module_ultrawide.gif" alt="Screenshot module on ultrawide" width="880"/>
</p>

<p align="center"><sub>Region selection with physics-draped ropes. Clipboard-backed paste, reliable on the first try.</sub></p>

<br/>

---

<br/>

## Legacy Archive &nbsp;·&nbsp; 2025 Alpha (Koke · 苔)

<p align="center">
  <sub>HISTORICAL REFERENCE · KOKE 苔 (moss) — steady growth of the early stack</sub><br/>
  <b>Zen Barebone Alpha — Hyprland 0.52 era</b><br/>
  <i>The original Python / GTK4 / Waybar stack, preserved for posterity before the full QML rewrite shipped in v6.10+ Yugen.</i>
</p>

<br/>

> These assets were captured on **Hyprland 0.52** and document the pre-Quickshell lineage. Current Zen Shell runs on **Hyprland 0.54+** with a unified QML architecture. The deprecated source is preserved at [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52).

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif" alt="Alpha main demo" width="880"/>
</p>

<p align="center"><sub><b>Main demo</b> — full alpha desktop tour (Python + GTK4 + Libadwaita + Waybar)</sub></p>

<br/>

<table align="center">
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.gif" alt="Alpha theme switching" width="420"/><br/><sub><b>Theme switching</b></sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/changewallpaper.gif" alt="Alpha wallpaper picker" width="420"/><br/><sub><b>Wallpaper picker</b></sub></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/paneldemo.gif" alt="Alpha panel modes" width="420"/><br/><sub><b>Panel modes</b></sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/desktoplooks.png" alt="Alpha desktop looks" width="420"/><br/><sub><b>Desktop looks</b></sub></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/dock.png" alt="Alpha dock" width="420"/><br/><sub><b>Custom dock</b></sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenter.png" alt="Alpha control center" width="420"/><br/><sub><b>Hypr Control Center (GTK4)</b></sub></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenteranimation.png" alt="Alpha animation editor" width="420"/><br/><sub><b>Animation editor (Bezier)</b></sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprlandappearance.png" alt="Alpha appearance settings" width="420"/><br/><sub><b>Appearance settings</b></sub></td>
</tr>
</table>

<br/>

---

<br/>

## Credits

### Inspired By

The **Music Strings visualizer** and the **Screenshot Rope overlay** in v6.15+ are heavily inspired by [flickowoa's Zephyr dotfiles](https://github.com/flickowoa/dotfiles/tree/hyprland-zephyr) ([demo video](https://www.youtube.com/watch?v=7Miis9I25q4)).

Huge thanks to **[flickowoa](https://github.com/flickowoa)** for the original design language.

### Built With

- **[Quickshell](https://github.com/quickshell-mirror/quickshell)** — the QML shell framework (requires v0.2.1+ with PopupWindow support for v4.10+)
- **[Hyprland](https://hyprland.org/)** — the Wayland compositor
- **Qt 6 / QML** — declarative UI + runtime
- **[Google Material Symbols](https://fonts.google.com/icons)** via [Iconify](https://icon-sets.iconify.design/material-symbols/) — feature-grid icons (Apache 2.0)

<br/>

---

<br/>

## Platform

<p align="center">
  <b>Arch Linux / CachyOS</b>
  &nbsp;·&nbsp;
  <b>Hyprland 0.54+</b>
  &nbsp;·&nbsp;
  <b>Quickshell 0.2.1+</b>
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

Zen Shell is developed independently, in personal time — late nights, after client work, from a small apartment in the Philippines. If it has helped you, or you just appreciate the craft, a coffee goes a long way.

<p align="center">
  <a href="https://buymeacoffee.com/zenpy">
    <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-0a0a0a?style=for-the-badge&logo=buy-me-a-coffee&logoColor=white" alt="Buy me a coffee"/>
  </a>
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
