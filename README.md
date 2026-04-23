<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png" alt="Zen Shell — v6.16.4.1" width="960"/>
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
  <img src="https://img.shields.io/badge/v6.16.4.1-stable-brightgreen?style=flat-square"/>
  &nbsp;
  <img src="https://img.shields.io/badge/v6.16.5%2B-planned-blueviolet?style=flat-square"/>
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
  <a href="#whats-new-in-v6164x">What's New</a>
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
> **Stable: v6.16.4.1** (`main` branch — official release). **Next: v6.16.5** (configreloaded IPC listener).
>
> | Channel | Version | Branch | Notes |
> |---|---|---|---|
> | **Stable** | v6.16.4.1 | [`main`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/v6.16.4.1) | **Official release** — rolls in the full v6.16.3 hotfix series, the complete Lock Screen overhaul, Universal Widget Scale, configurable Idle/Lid/Sleep cascade, and the Panic Recovery keybind (`SUPER+SHIFT+CTRL+Esc`) that replaces force-power-off forever. |
> | **Next** | v6.16.5 | *planned* | Global Hyprland `configreloaded` IPC listener — architectural cleanup that unlocks cleaner live-reload across every Settings panel. |

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
  <sub>FULL TOUR</sub><br/>
  <b>Zen Shell — Full Tour</b><br/>
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
  <i>Zen Shell — captured on Hyprland 0.54, Quickshell 0.2.1.</i>
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

## What's New in v6.16.4.x

v6.16.4.1 is the current stable, and it rolls in **eight versions worth of shipping** since the previous v6.16.3.4.2 stable. The big arc: Lock Screen overhaul, Universal Widget Scale, full Idle/Lid/Sleep control, and the Panic Recovery keybind that fixes the "I have to force-power-off my laptop" problem.

<br/>

### v6.16.4.1 stable highlights

#### Panic Recovery keybind &nbsp;·&nbsp; v6.16.4 &nbsp;·&nbsp; hotfixed in v6.16.4.1

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

#### Idle / Lid / Sleep unified UX &nbsp;·&nbsp; v6.16.3.8

- Settings → Battery &amp; Power → **Idle &amp; Sleep** section
- Lock after idle: `30s / 1min / 30min / 1h / 3h / 5h / Never`
- Sleep after idle: same options, defaults to Never on desktops
- Lid close action: `Sleep (suspend + lock on wake) / Lock only / Do nothing`
- `zen-hypridle-sync.sh` reads PanelState values, rewrites hypridle.conf via sed (on lines marked `# ZEN_IDLE_LOCK`, `# ZEN_IDLE_DPMS`, `# ZEN_IDLE_SLEEP`), restarts hypridle — changes apply live without shell restart
- Pre-suspend health check kills zombie hyprlock before every `systemctl suspend` (prevents "suspend broken session → wake more broken" cascade)
- Wake-to-lock cascade handled by existing `before_sleep_cmd = loginctl lock-session` + hardened `zen-resume-handler.sh`

#### Universal Widget Scale &nbsp;·&nbsp; v6.16.3.7

- Settings → Widgets → **Widget Scale** slider (0.5× to 2.0×, default 1.0×, step 0.05)
- Live-apply — resizes all three desktop widgets (clocks, weather, sysmon) in lockstep
- 68 scale multipliers baked into `DesktopWidgets.qml` via single `dw._scale` property
- Font dependency check added to `install.sh` — offers `adwaita-fonts`, `inter-font`, `gnome-themes-extra` via `paru -S --needed`
- Widget positions stored unscaled → drag-and-drop survives scale changes

#### Lock Screen overhaul &nbsp;·&nbsp; v6.16.3.6

- Clock font now **matches your desktop widget font exactly** — `zen-lock.sh` reads `fontFamilyId` from panel-state.json, sed-substitutes into hyprlock.conf lines marked with `# ZEN_FONT_OVERRIDE_CLOCK`. Black/Bold weight variants per font (adwaita → `Adwaita Sans Black`, jetbrains → `JetBrainsMono Nerd Font Bold`, etc.)
- No more "Heyah Username" greeting — removed
- **Weather mood line** — `Sunny morning ☀️` / `Rainy afternoon 🌧️` / `Starry night sky 🌌` / `Cloudy evening 🌥️` / `Stormy night ⛈️` / `Foggy morning 🌫️` / `Snowy afternoon 🌨️`
- **Rotating care message** — pulled from pool seeded on minute-of-day (stable within a minute, rotates naturally):
  - *"Have a great day ahead"* · *"Tea or coffee weather ☕"* · *"Hope today was kind to you"* · *"Working late? Don't forget to rest"*
- **Gender-aware** — Settings → User Profile → Personal Preferences → pick *Neutral / Male / Female* — unlocks gendered pools:
  - Male: *"What's up, man!"* · *"Rise and grind, bro"* · *"Evening's yours now, boss"*
  - Female: *"Good morning, miss!"* · *"Rise and shine, queen"* · *"Stay cozy, madam"*
- All messages **English-only** · `~/.local/bin/zen-lock-message.sh` is pure bash with gendered pools per `(time × weather)` bucket

#### Clock + SysMonitor hover popup parity &nbsp;·&nbsp; v6.16.3.6

- `ZenClock` hover enhanced with live time-with-seconds, ISO week + day-of-year, IANA timezone + UTC offset
- `ZenSysMonitor` rewritten: inline Rectangle tooltip → proper `PopupWindow` with `anchor.edges: Edges.Top`, 350ms hover-intent Timer
- Both use identical styling (bg0@96% alpha, 15% fg border, Theme.panelRadius, DemiBold blue section headers, grey body)

#### Start Menu logo picker &nbsp;·&nbsp; v6.16.3.5

- 7 bundled SVG logos: Arch · CachyOS · EndeavourOS · Fedora · Ubuntu · NixOS · generic Linux
- 3 modes: auto-detect from `/etc/os-release`, pick from builtin, pick custom file
- Grid picker UI (4 columns × 7 tiles, selected state)
- Fallback chain: resolver → `Quickshell.iconPath(distributor-logo-<id>)` → `distributor-logo-archlinux`

#### v6.16.3.4.x hotfix sub-series

- **v6.16.3.4.1** — Widget color persistence fix (weather/sysmon `bgMode` + `bgCustomColor` + `bgOpacity` now persist across restart, were resetting to defaults)
- **v6.16.3.4.2** — Input page toggle design synchronized with System Tray toggle design (unified HMSwitch styling across all pages)
- **v6.16.3.4.3** — Animations page live-reload (now reflects current hyprctl state) + scroll-to-bottom fix (ScrollView was cutting off last rows) + Input toggle design sync propagated
- **v6.16.3.4.4** — Laptop brightness detection fix (ROG laptops using `amdgpu_bl0` / `asus::kbd_backlight` now detected) + themes dropdown is now scrollable (was fixed-height, cutting off Paper / Black / Navy)

Full per-patch details: [`CHANGELOG-v6.16.4.1.md`](CHANGELOG-v6.16.4.1.md) · [`CHANGELOG-v6.16.4.md`](CHANGELOG-v6.16.4.md) · [`CHANGELOG-v6.16.3.8.md`](CHANGELOG-v6.16.3.8.md) · [`CHANGELOG-v6.16.3.7.md`](CHANGELOG-v6.16.3.7.md) · [`CHANGELOG-v6.16.3.6.md`](CHANGELOG-v6.16.3.6.md)

<br/>

### Carried forward from v6.16.3.4.x (still in)

- PowerBadge bar module — profile + GPU pill with border color per profile (green/blue/orange, red on Gaming Boost)
- Lid-close hypridle/hyprlock patch at the compositor layer
- Material Design power confirm icons, theme-synced
- Display resolution dropdown enumeration via `hyprctl monitors all -j` + EDID fallback
- Every v6.16.2.3.6 fix — click-through settings/CP/music rope, OpacityMask avatar, default wallpaper, repo browser, mouse sensitivity, panelStateLoaded restart gating, DMI device info, bulletproof single-instance installer

<br/>

---

<br/>

## Features

<br/>

### Panic Recovery &nbsp;·&nbsp; v6.16.4+

- `SUPER+SHIFT+CTRL+Escape` keybind (Hyprland `bindl` — works through frozen hyprlock)
- 9-step recovery sequence runs in ~2 seconds
- Single press preserves Quickshell state (music marquee, widget positions, bar)
- Double-press within 10s escalates to full Quickshell restart
- Manual invocation via SSH or TTY: `~/.local/bin/zen-panic.sh`
- Settings → Battery &amp; Power → Panic Recovery section (keybind shown as red-tinted emergency pill)

<br/>

### Idle &amp; Sleep &nbsp;·&nbsp; v6.16.3.8+

- Idle lock timeout (30s / 1m / 30m / 1h / 3h / 5h / Never)
- Idle sleep timeout (same options)
- Lid close action (Sleep + Lock / Lock only / Do nothing)
- `zen-hypridle-sync.sh` live-rewrites hypridle.conf on every setting change
- DPMS off auto-derived as lock + 60s
- Before-sleep health check prevents broken sessions from suspending

<br/>

### Universal Widget Scale &nbsp;·&nbsp; v6.16.3.7+

- Settings → Widgets → Widget Scale slider (0.5× to 2.0×)
- Resizes clocks, weather, sysmon widgets in lockstep
- 68 scale multipliers baked into `DesktopWidgets.qml`
- Reset button returns to 1.0×
- Font dep check offers `adwaita-fonts` / `inter-font` / `gnome-themes-extra` in install.sh

<br/>

### Lock Screen &nbsp;·&nbsp; v6.16.3.6+

- Clock font matches desktop widget (Black/Bold weight variants per font family)
- Weather mood line (time × weather condition from WeatherService)
- Rotating care message, gender-aware (Neutral / Male / Female)
- All English, pure bash, editable at `~/.local/bin/zen-lock-message.sh`
- Settings → User Profile → Personal Preferences for gender pick

<br/>

### PowerBadge &nbsp;·&nbsp; v6.16.3.4+

- Tiny pill widget in the bar showing current power profile + GPU mode
- Border color: green (Saver) / blue (Balanced) / orange (Performance) / red (Gaming Boost)
- 300ms hover popup with full state + click-shortcut reference
- Left-click: open Control Panel · Right-click: cycle profile · Middle-click: Gaming Boost
- Self-hides on systems without PPD or multi-GPU

<br/>

### Material Power Icons &nbsp;·&nbsp; v6.16.3.1+

- Start Menu shutdown / restart / suspend / log-out confirm icons use Material Symbols Outlined
- Accent color pulled from active theme palette
- Smooth fade-in transitions, cached properly

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

<br/>

### Music Strings &nbsp;·&nbsp; v6.15+

- Audio-reactive bezier visualizer — `cava` drives beat amplitude
- `playerctl` drives artist/title tooltip
- Floating overlay panel — bezier curves bow above and below bar slot
- Color modes: theme / synced / custom
- `mask: Region {}` makes rope click-through
- Toggle in Settings → General → Strings

<br/>

### Screenshot Rope Overlay &nbsp;·&nbsp; v6.15+

- `Super+Shift+S` → region screenshot with physics-draped rope ornaments
- 10-segment ropes with tuned gravity / inertia / spring force
- `grim` + `slurp` primary, `flameshot` fallback
- `wl-copy` with `setsid` detachment — paste works on first try

<br/>

### Control Panel &nbsp;·&nbsp; Super+C

- PipeWire volume sliders (input + output)
- WiFi / Bluetooth / LAN toggles
- CPU / GPU / RAM / VRAM live stats
- Power Profile pills + Gaming Boost toggle
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

Fourteen pages: General, Decoration, Animations, Themes, Displays, Panel, Bar Modules, System Tray, Sound &amp; Network, Notifications, Desktop Widgets, Wallpaper, Battery &amp; Power &amp; GPU, Input.

- Live preview for all changes
- Animations page now reflects current hyprctl state and is fully scrollable (v6.16.3.4.3)
- Themes dropdown is scrollable (v6.16.3.4.4)
- Persists to JSON
- Revert buttons on every section

<br/>

### Unified Theming System

17 built-in themes auto-synchronize across Quickshell bar, Settings app, Control Panel, SwayNC notifications, Alacritty terminal, and Fuzzel launcher.

<p align="center">
  <sub>One Dark · Gruvbox · Nord · Tokyo Night · Catppuccin Mocha · Dracula · Solarized Dark · Everforest Dark · Cyberpunk · Lovelace · Yousai · Arc · Adapta · Navy · Black · Paper</sub>
</p>

- Custom theme palette editor
- Rice export / import

<br/>

### Start Menu &nbsp;·&nbsp; Super+A

- Win11-style with pinned apps + alphabetical all-apps
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

## Quick Start

### Stable &nbsp;·&nbsp; v6.16.4.1 &nbsp;·&nbsp; `main` branch

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

git fetch --tags
git checkout v6.16.4.1        # pin to exact release
#   — or —
git checkout main             # always the latest commit on stable

chmod +x install.sh
./install.sh --bootstrap      # safe alongside KDE / GNOME / COSMIC
#   — or —
./install.sh                  # if Hyprland + Quickshell already installed
```

On fresh install the dependency check will offer `adwaita-fonts` / `inter-font` / `gnome-themes-extra` via `paru -S --needed` (ensures Black/Bold font variants exist for lock-screen + widget font sync).

### Verify after install

```bash
# Should print 1 (not 2 or 3)
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Verify panic keybind is registered (v6.16.4+)
hyprctl binds | grep -i zen-panic

# Verify hypridle timeouts synced from PanelState (v6.16.3.8+)
grep ZEN_IDLE ~/.config/hypr/hypridle.conf

# Verify widget scale setting persisted (v6.16.3.7+)
jq .widgetScale ~/.local/share/quickshell/zen-shell/panel-state.json

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

- [Quickshell](https://github.com/quickshell-mirror/quickshell) 0.2.1+ — QML shell framework
- [Hyprland](https://hyprland.org/) 0.54+ — Wayland compositor
- `jq` — JSON processor

**Recommended** &nbsp;·&nbsp; most auto-installed by `--bootstrap`

`swww` · `grim` · `slurp` · `wl-clipboard` · `flameshot` · `cava` · `playerctl` · `power-profiles-daemon` · `brightnessctl` · `alacritty` · `thunar` · `fuzzel` · `btop` · `swaync` · `nwg-displays` · `nwg-look` · `blueman` · `networkmanager` · `wireplumber` · `pavucontrol` · `zenity` · `libnotify` · `imagemagick` · `hypridle` · `hyprlock` · `adwaita-fonts` · `inter-font` · `gnome-themes-extra`

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
├── ControlPanel.qml             # Super+C — cascade two-column        ← v6.16.1
├── PowerProfileService.qml      # powerprofilesctl + Gaming Boost     ← v6.16
├── GPUSwitcherService.qml       # GPU selection + env vars            ← v6.16
├── MouseSettingsService.qml     # Mouse sensitivity / scroll          ← v6.16.2.3
├── WallpaperRepoService.qml     # GitHub API listing fetcher          ← v6.16.2.3
├── HMSwitch.qml                 # Unified pill toggle (×27)           ← v6.16.1
├── UserProfileService.qml       # Versioned avatars + DMI info        ← v6.16.2.3.6
├── UserProfilePage.qml          # +Personal Preferences (gender)      ← v6.16.3.6
├── ZenSettings.qml              # Settings window — 14 pages
├── BatterySettingsPage.qml      # +Idle&Sleep +Panic Recovery         ← v6.16.3.8 / .4
├── WidgetsPage.qml              # +Widget Scale slider                ← v6.16.3.7
├── InputPage.qml                # Mouse + scroll page                 ← v6.16.2.3
├── DesktopWidgets.qml           # 68 scale multipliers                ← v6.16.3.7
├── PanelState.qml               # +widgetScale +idleLock/Sleep +lid   ← v6.16.3.7/.8
├── ZenCalendar.qml              # Hover-aware calendar                ← v6.16.2.3.1
├── SettingsStateV2.qml          # Full Hyprland state persistence
└── ...                          # ~76 QML files total

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
├── zen-bar-add-powerbadge.sh    # Opt-in PowerBadge inserter          ← v6.16.3.4
├── prime-run                    # One-shot dGPU launcher              ← v6.16
├── zs-restart.sh                # Selective nuclear restart
├── regen-terminal-themes.sh     # Alacritty / Fuzzel theme sync
└── regen-swaync-theme.sh        # SwayNC theme sync

hypr-config/                     # Separate overlay patches
├── hypridle.conf                # With ZEN_IDLE_* markers             ← v6.16.3.8
├── hyprlock.conf                # With ZEN_FONT_OVERRIDE_* markers    ← v6.16.3.6
├── binds.conf                   # +bindl panic keybind                ← v6.16.4
├── lid-behavior.conf            # Lid switch → zen-lid-handler.sh
└── autostart.conf

~/.local/share/quickshell/zen-shell/
└── logos/                       # 7 bundled distro SVGs               ← v6.16.3.5
    ├── arch.svg
    ├── cachyos.svg
    ├── endeavouros.svg
    ├── fedora.svg
    ├── ubuntu.svg
    ├── nixos.svg
    └── linux.svg
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
| `~/.config/hypr/zen-mouse.conf` | Mouse sensitivity |
| `~/.config/hypr/modules/hardware.conf` | GPU env vars + VRR |
| `~/.config/hypr/modules/lid-behavior.conf` | Lid bindl switch |
| `~/.config/hypr/hypridle.conf` | Sed-templated idle timeouts (v6.16.3.8) |
| `~/.config/hypr/hyprlock.conf` | Sed-templated font sync (v6.16.3.6) |
| `~/.config/quickshell/zen-shell/bar-layout.json` | Per-row module order |
| `~/.config/quickshell/zen-shell/wallpaper-v5.json` | Current wallpaper path |
| `~/.cache/zen-shell/wallpapers/listing.json` | Cached GitHub API repo listing |
| `~/.cache/zen-shell/panic.log` | Panic recovery audit log (v6.16.4) |
| `~/.cache/zen-shell/lid.log` | Lid-handler audit log |
| `~/.cache/zen-shell/resume.log` | Post-suspend pipeline log |
| `~/.cache/zen-shell/hypridle-sync.log` | hypridle sync audit log |
| `~/.cache/zen-shell/lock.log` | zen-lock.sh audit log |
| `/tmp/zen-shell.log` | Shell stdout/stderr |

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
| **`Super + Shift + Ctrl + Esc`** | **Panic recovery keybind** (works through frozen hyprlock) &nbsp;·&nbsp; **v6.16.4+** |
| Clock click | Calendar popup (with month-cycle scroll wheel) |
| Clock hover | Live time + ISO week + timezone popup &nbsp;·&nbsp; v6.16.3.6+ |
| SysMonitor hover | CPU / GPU / Memory / Network popup &nbsp;·&nbsp; v6.16.3.6+ |
| PowerBadge right-click | Cycle power profile &nbsp;·&nbsp; v6.16.3.4+ |
| PowerBadge middle-click | Toggle Gaming Boost &nbsp;·&nbsp; v6.16.3.4+ |
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

### v6.16.4.x &nbsp;·&nbsp; current stable

- **[v6.16.4.1](CHANGELOG-v6.16.4.1.md)** — Panic script hotfix (reload wipe, SIGUSR2 kill, music loop) ✅
- **[v6.16.4](CHANGELOG-v6.16.4.md)** — Laptop reliability pass — panic keybind + hardened resume ✅

### v6.16.3.x

- **[v6.16.3.8](CHANGELOG-v6.16.3.8.md)** — Idle / Lid / Sleep unified UX ✅
- **[v6.16.3.7](CHANGELOG-v6.16.3.7.md)** — Universal widget scale + font deps ✅
- **[v6.16.3.6.1](CHANGELOG-v6.16.3.6.1.md)** — Lock clock weight fix ✅
- **[v6.16.3.6](CHANGELOG-v6.16.3.6.md)** — Hover popup parity + Lock screen overhaul ✅
- **[v6.16.3.5](CHANGELOG-v6.16.3.5.md)** — Start Menu logo picker ✅
- **[v6.16.3.4](CHANGELOG-v6.16.3.4.md)** — PowerBadge widget ✅
- **[v6.16.3.3](CHANGELOG-v6.16.3.3.md)** — Display resolution dropdown fix ✅
- **[v6.16.3.2](CHANGELOG-v6.16.3.2.md)** — Lid-close hypridle/hyprlock patch ✅
- **[v6.16.3.1](CHANGELOG-v6.16.3.1.md)** — Material Power Icons ✅

### v6.16.x

- **[v6.16.x consolidated](CHANGELOG-v6.16.x.md)**
- **[v6.16.2.3.6 hotfix series closeout](HOTFIX-v6.16.2.3.6.md)**
- [v6.16.1.11](CHANGELOG-v6.16.1.11.md) — Cascade infinite-loop fix
- [v6.16.1.10](CHANGELOG-v6.16.1.10.md) — Cascade-to-side Control Panel
- [v6.16.1](CHANGELOG-v6.16.1.md) — Multi-GPU, GPU Switcher, Gaming Boost
- [v6.16](CHANGELOG-v6.16.md) — Battery, Power Profiles, Volume OSD

### v6.15.x

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

**I pressed the panic keybind — what just happened?**

`SUPER+SHIFT+CTRL+Esc` runs `~/.local/bin/zen-panic.sh` which does a 9-step recovery sequence: kill zombie hyprlock if detected, double DPMS cycle, force renderer reload (preserves monitor config — unlike `hyprctl reload`), revive swww-daemon if zombied, clean re-lock if session was locked, input subsystem kick. **Your Quickshell keeps running** — bar, widgets, music marquee, drag positions all preserved. Only double-press within 10 seconds escalates to full Quickshell restart. Log at `~/.cache/zen-shell/panic.log`.

<br/>

**Does this work on laptops?**

Yes — v6.16.3.8 added full Idle/Sleep/Lid configurability (Settings → Battery &amp; Power → Idle &amp; Sleep). v6.16.4 added the panic recovery keybind specifically for the "force-power-off my laptop" scenarios. v6.16.3.4.4 fixed ROG brightness detection. Everything auto-hides when hardware isn't detected.

<br/>

**Why is stable `v6.16.4.1` and not `v6.17`?**

Because the v6.16 phase has been an uninterrupted run of shipping since v6.16.0. Each `.x.y.z` bump corresponds to a clean feature drop or hotfix. `v6.17` will follow after Phase 4 items (Hyprland dark mode + GTK3/4 sync, hyprbars, float/tile assignment GUI, auto-clean memory) and Phase 5 (updates manager) ship.

<br/>

**Which distros work?**

Primary support is Arch-based distros (Arch, CachyOS, EndeavourOS, Manjaro). Other distros will work with **Hyprland 0.54+** and **Quickshell 0.2.1+**, but the installer assumes `paru` / `yay` / `pacman`.

<br/>

---

<br/>

## Roadmap

Zen Shell is actively developed. Continuous iteration rather than a "finished" state.

<br/>

### Naming convention

Once a phase reaches stable, the branch promotes to `main` as `v6.x.x.x`. Current stable is `v6.16.4.1` on `main`. Next work is `v6.16.5` (configreloaded listener) on a feature branch until stable.

<br/>

### Phase tracker — all shipped

| Phase | Status | Focus |
|---|---|---|
| **v6.16.3.1** | ✅ Shipped | Material Power Icons (theme-synced) |
| **v6.16.3.2** | ✅ Shipped | Lid-close hypridle/hyprlock overlay patch |
| **v6.16.3.3** | ✅ Shipped | Display resolution dropdown enumeration fix |
| **v6.16.3.4** | ✅ Shipped | PowerBadge bar module |
| **v6.16.3.4.1** | ✅ Shipped | Widget color persistence fix (weather / sysmon) |
| **v6.16.3.4.2** | ✅ Shipped | Input page toggle design synced with System Tray |
| **v6.16.3.4.3** | ✅ Shipped | Animations live-reload + scroll-to-bottom fix |
| **v6.16.3.4.4** | ✅ Shipped | Laptop brightness (ROG) + themes dropdown scrollable |
| **v6.16.3.5** | ✅ Shipped | Start Menu logo picker (7 bundled + custom) |
| **v6.16.3.6** | ✅ Shipped | Clock/SysMonitor hover parity + Lock screen overhaul |
| **v6.16.3.6.1** | ✅ Shipped | Lock clock weight fix (Black/Bold variants) |
| **v6.16.3.7** | ✅ Shipped | Universal widget scale slider + font dep check |
| **v6.16.3.8** | ✅ Shipped | Idle / Lid / Sleep configurable cascade |
| **v6.16.4** | ✅ Shipped | Laptop reliability — panic keybind + hardened resume |
| **v6.16.4.1** | 🟢 **Current stable** | Panic script hotfix — reload wipe, SIGUSR2, music loop |

<br/>

### Up next

<br/>

#### v6.16.5 — Global Hyprland `configreloaded` IPC listener

Architectural cleanup. Currently each Settings page has its own Process that calls `hyprctl reload` + its own `applyToHyprland()` callback. Every page re-implements the same boilerplate — and one missing callback was the root cause of the v6.16.4 panic monitor-wipe bug.

Fix: one singleton (`HyprlandConfigReloadListener`) listens to Hyprland's `configreloaded` IPC event. When it fires, ALL `SettingsStateV2` runtime keywords re-apply automatically. Less boilerplate, no more "I forgot to add applyToHyprland after reload on THIS page" bugs.

<br/>

#### v6.16.6 — Wallpaper repo browser + display modes

- Browse curated community wallpaper repos (linux-wallpapers, cachyos-wallpapers, nixos-artwork) with live preview
- One-click download + apply
- **Wallpaper display modes** — new per-wallpaper setting:
  - **Fit** (default) — aspect-preserving, letterbox if needed
  - **Stretch** — fill the screen, may distort
  - **Custom adjustment** — user-positioned pan + zoom with drag handles

<br/>

#### Phase 4 — UX polish (multi-version, likely v6.16.7 → v6.16.10)

- [ ] **Hyprland dark mode + GTK3/4 theming sync** — `gsettings` integration so GTK apps render in Adwaita-dark / Breeze-dark based on `ThemeService.styleMode`. Bonus: `nwg-look` bridge for icon/cursor themes.
- [ ] **hyprbars + recreate minimize mode** — Hyprland's hyprbars plugin with title-bar per window + minimize / maximize / close buttons. Useful for users transitioning from GNOME / KDE.
- [ ] **Float / tile assignment rules GUI** — visual editor for Hyprland's `windowrule`s. Assign an app to always float, always tile, always fullscreen, etc. Saves to `windowrules.conf` module. Preview which apps match each rule.
- [ ] **Auto-clean memory** — service watches free memory, triggers `echo 3 > /proc/sys/vm/drop_caches` when threshold hit. Settings → **Battery &amp; Power** → Auto-clean memory toggle + threshold slider. Useful for long dev sessions.

<br/>

#### Phase 5 — Updates manager

- [ ] **Channel picker** — select from GitHub: **Official** (tagged releases) / **Beta** (pre-tag branches) / **Alpha** (active development)
- [ ] **Download + execute** — grabs the tarball from GitHub Releases API, runs install.sh in a sandboxed path
- [ ] **Rollback support** — all fetched versions stored in `~/.local/share/zen-shell/versions/` — switch between them with one click
- [ ] **Notification on new release** — swaync popup when a new version is available on the user's chosen channel
- [ ] **Skip version** toggle — don't notify again for this specific version

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

## Legacy Archive &nbsp;·&nbsp; 2025 Alpha

<p align="center">
  <sub>HISTORICAL REFERENCE</sub><br/>
  <b>Zen Barebone Alpha — Hyprland 0.52 era</b><br/>
  <i>The original Python / GTK4 / Waybar stack, preserved for posterity before the full QML rewrite shipped in v6.10+.</i>
</p>

<br/>

> These assets were captured on **Hyprland 0.52** and document the pre-Quickshell lineage of the project. Current Zen Shell runs on **Hyprland 0.54+** with a unified QML architecture. The deprecated source is preserved at [`zen-alpha-deprecated-0.52/`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52).

<br/>

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif" alt="Alpha main demo" width="880"/>
</p>

<br/>

---

<br/>

## Credits

### Inspired By

The **Music Strings visualizer** and the **Screenshot Rope overlay** in v6.15+ are heavily inspired by [flickowoa's Zephyr dotfiles](https://github.com/flickowoa/dotfiles/tree/hyprland-zephyr) ([demo video](https://www.youtube.com/watch?v=7Miis9I25q4)).

Huge thanks to **[flickowoa](https://github.com/flickowoa)** for the original design language.

### Built With

- **[Quickshell](https://github.com/quickshell-mirror/quickshell)** — the QML shell framework
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
