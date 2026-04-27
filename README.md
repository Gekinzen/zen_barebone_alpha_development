# Zen Shell — Quickshell-native desktop for Hyprland

**Current version: v6.16.4.12.5 "Hikari" (光)** — alpha
**Repo branch:** `main` (promoted 2026-04-26)
**Author:** P.Yuki ([Gekinzen](https://github.com/Gekinzen))

A QML desktop environment built on [Quickshell](https://quickshell.outfoxxed.me/)
for [Hyprland](https://hyprland.org/) 0.54+. Includes a configurable bar,
start menu, control panel, settings UI, system monitoring, wallpaper
manager, audio-reactive music visualization, unified theme engine, and
on-the-fly dark mode toggle synced across GTK3/4/libadwaita apps.

![Zen Shell Kintsugi desktop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/hero_desktop.jpg)

---

## Showcase

Live captures from v6.16.4.12 running on Hyprland 0.54 with the Kintsugi Dark theme.

### Wallpaper engine

Full wallpaper picker with folder scanning, slideshow scheduling, transition effects, and the online Gekinzen/images-demo repo browser.

![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_01_wallpaper_picker.gif)

### Animation presets (Material ZenComboBox)

21 community animation presets, live-applied via `hyprctl reload`. The new Material-style ZenComboBox auto-contrasts text using WCAG 2.0 luminance — readable on any theme.

![Animations dropdown](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_02_animations_dropdown.gif)

### Themes page with PaletteBox

Unified theme engine with 19 built-in themes (including the new **Kintsugi Light** and **Kintsugi Dark**). Click any 60×60 palette box to open the Quickshell PopupWindow color picker with live hex typing.

![Themes palette](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_03_themes_palette.gif)

### Panel drag-drop + bar modes

Drag modules between Left / Center / Right zones — state persists to `panel-state.json`. Fullwidth ↔ Island mode toggle with `panelStateLoaded` gate prevents the old revert-on-reboot bug.

![Panel drag-drop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_04_panel_drag_drop.gif)

### Control Panel + Dark Mode sync

Super+C opens the Quick Settings panel — volume sliders, WiFi / Bluetooth / Ethernet, Ryzen 9 5950X temps, RX 6800 GPU, Power Profile, Gaming Boost, and the **Dark Mode toggle** that syncs GTK3/4/libadwaita apps via gsettings + GTK3 settings.ini + GTK4 settings.ini.

![Control Panel dark mode](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_05_control_panel.gif)

---

## Video demos

### 🟢 Latest — v6.16.4.12.5 "Hikari" Release Showcase

[![Zen Shell v6.16.4.11.2 Kintsugi — Release Showcase](https://img.youtube.com/vi/nS2L9dIQbF4/maxresdefault.jpg)](https://www.youtube.com/watch?v=nS2L9dIQbF4)

**Watch on YouTube:** https://www.youtube.com/watch?v=nS2L9dIQbF4

1:35 walkthrough of the Kintsugi release — hero desktop, wallpaper engine, Material ZenComboBox with WCAG auto-contrast, Themes page with PaletteBox, Panel drag-drop + island mode, Control Panel with Dark Mode toggle, WiFi picker.

### Historical tours

| Era | Video | Focus |
|---|---|---|
| v6.15.x · **Ensō** | [Full Tour](https://www.youtube.com/watch?v=dNwGRBhA97g) | Strings music module, screenshot ropes, settings, complete desktop experience |
| v6.14 · **Yugen** | [v6.14 Demo](https://www.youtube.com/watch?v=YQxrh5_naMQ) | Theme switching, panel modes, control center in the QML-rewrite era |
| v6.10 · **Yugen foundations** | [v6.10 Demo](https://www.youtube.com/watch?v=ao89J3DEqiA) | The fresh QML rewrite — where the new stack began |

---

## Previous showcases — v6.15.3 era

Preserved so the evolution stays visible. These assets are from the Ensō series (v6.15.x) before the Kintsugi v4 alpha cycle began.

### v6.15.3 — Desktop composition

![v6.15.3 Desktop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png)

### v6.15.3 — Workspace + Control Panel

![v6.15.3 Workspace](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png)

### v6.15.3 — Settings pages

![v6.15.3 Settings](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png)

### Adaptive theming across every surface

![Adaptive theming](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_01_adaptive_theming.gif)

### Settings tour · 14 pages

![Settings tour](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_02_settings_tour.gif)

### Screenshot Ropes · Super+Shift+S

![Screenshot Ropes](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_03_screenshot_module_ultrawide.gif)

---

## Legacy archive — 2025 Alpha (Koke · 苔)

Historical reference from the pre-Quickshell lineage. Hyprland 0.52 era. Python + GTK4 + Libadwaita stack. Custom dock, 13+ theme engine, Hypr Control Center. Preserved on branch [`zen-alpha-deprecated-0.52`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52).

### Main demo

![Alpha main demo](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif)

### Theming + Wallpaper + Panel

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.gif" alt="Alpha theme switching" width="420"/><br/><sub>Theme switching</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/changewallpaper.gif" alt="Alpha wallpaper picker" width="420"/><br/><sub>Wallpaper picker</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/paneldemo.gif" alt="Alpha panel modes" width="420"/><br/><sub>Panel modes</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/desktoplooks.png" alt="Alpha desktop looks" width="420"/><br/><sub>Desktop looks</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/dock.png" alt="Alpha dock" width="420"/><br/><sub>Custom dock</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenter.png" alt="Alpha control center" width="420"/><br/><sub>Hypr Control Center (GTK4)</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenteranimation.png" alt="Alpha animation editor" width="420"/><br/><sub>Animation editor (Bezier)</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprlandappearance.png" alt="Alpha appearance settings" width="420"/><br/><sub>Appearance settings</sub></td>
</tr>
</table>

---

## What v6.16.4.12.5 "Hikari" ships

This release opens the Hikari (光 — "Light") cycle. Illumination across every surface.

| Area | Change |
|---|---|
| **Panel position** | Bar can sit at top or bottom of screen. Visual selector in Settings → Panel → Position. All overlay windows (start menu, calendar, ZenStrings) flip correctly. |
| **Profile export/import** | Full-system snapshot: theme + panel + settings + bar layout + wallpaper → portable JSON. Save, load, rename, delete, share with friends. `~/.config/zen-shell/profiles/`. |
| **Per-monitor widgets** | Widget Display replaced with per-monitor toggles. Pick exactly which monitors show desktop widgets. Auto-detects connected displays. |
| **Display settings v2** | Preview rewritten with GPU-composited QML items (was Canvas). Smooth drag, zoom controls (+/−/Fit), per-monitor enable/disable toggle. |
| **Volume hard cap** | Sliders and keyboard keys now cap at 100%. Was 150%. No more accidental boost. |
| **Notification center** | Clock click opens unified panel: notifications top (count badge, DND toggle, swaync toggle), full calendar center, system quick-action icons bottom (BT, WiFi, Lock, Logout, Restart, Shutdown). Replaces standalone calendar popup. |
| **Calendar → swaync** | Notification row opens swaync when clicked. DND toggle via bell icon. Falls back gracefully if swaync not installed. |
| **Start menu sticky** | Menu gap reduced to 2px — feels attached to bar. Position-aware for top/bottom. |

Full changelog: `CHANGELOG-v6.16.4.12.5.md`.

### Previous: v6.16.4.11.2 "Kintsugi"

<details>
<summary>Click to expand v6.16.4.11.2 changelog</summary>

| Area | Change |
|---|---|
| **Panic keybind** | `SUPER+SHIFT+CTRL+Esc` works even through a frozen hyprlock — kills the shell, clears runtime state, respawns. No more force-power-off. |
| **Kintsugi themes** | Two new built-in themes matching the signature sage / gold / bone / ink palette. **Kintsugi Dark** is the default for fresh installs; existing users keep their selected theme. |
| **ZenComboBox rebuild** | Material-style dropdown — rotating chevron, accent dots, left accent bar on highlight. Text color picked via WCAG 2.0 luminance (threshold L=0.5). Readable on every theme, light or dark. |
| **Theme Palette relocated** | Moved from General page → Themes page. Single source of truth for palette edits. Old General HMSection preserved via `visible:false` — zero feature removal. |
| **PaletteBox component** | New 60×60 clickable palette swatches with hover pencil overlay. Click opens Quickshell `PopupWindow` picker with HS canvas + Lightness slider + live hex typing. Save / Rename / Delete custom themes via jq. |
| **Color picker (4 attempts)** | Qt `Popup` has Wayland coord quirks; switched to Quickshell `PopupWindow` primitive (xdg_popup, compositor-managed). Live hex input commits on every valid keystroke. |
| **Dark Mode toggle** | New `DarkModeService.qml` + `zen-darkmode.sh`. Syncs GTK3 (`settings.ini`), GTK4 (`settings.ini`), libadwaita (gsettings `color-scheme`). State at `~/.local/share/zen-shell/darkmode.state`. |
| **Super+T terminal** | `zen-terminal.sh` auto-detect chain: `$TERMINAL` → kitty → alacritty → ghostty → wezterm → foot → konsole → gnome-terminal. No more hardcoded kitty. |
| **WiFi rewrite** | Named-argument pattern replaces type-sniffing. Handles composite `nmcli` security strings like `WPA2 802.1X`. Audit log at `/tmp/zen-wifi-debug.log`. |
| **Start Menu breathing** | 64px → 72px pinned tiles. Better touch targets, cleaner grid rhythm. |
| **Widget Scale slider** | Live-updates desktop widgets (clock / weather / sysmon) without restart. Persists to widget state. |
| **Displays → gaps preserved** | Changing monitor config no longer wipes Hyprland gaps from `modules/appearance.conf`. |

</details>

---

## Codename history

Each release era gets a codename from Japanese zen vocabulary.

| Codename | Kanji | Meaning | Versions |
|---|---|---|---|
| **Hikari** | 光 | Light — illumination across every surface | v6.16.4.12.5 (alpha) |
| Wakaba | 若葉 | Young leaf | Alpha v0.91 — Waybar + Python + rofi |
| Koke | 苔 | Moss | Alpha v2.x (v2.1.3) — GTK4 / Libadwaita era |
| Yugen | 幽玄 | Subtle profound grace | v6.10 – v6.14 — QML rewrite |
| Ensō | 円相 | The zen circle | v6.15.x · v6.16 base — unified stack |
| Ma | 間 | The space between | v6.16.1.x — cascade Control Panel |
| Shibui | 渋い | Understated refinement | v6.16.2.3.x — click-through masks |
| Sabi | 寂 | Beauty of age & patina | v6.16.3.x — lock screen, PowerBadge |
| **Kintsugi** | **金継ぎ** | **Golden-repair** | **v6.16.4.x · v6.16.4.11.2** — current |
| Hikari *(next)* | 光 | Light · clarity | v6.16.4.12 — Profile Export/Import |
| Michi *(planned)* | 道 | The way | v6.16.5 — in-app Updates Manager |

---

## Install

### Quick

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development
git checkout v6.16.4.11.2
./install.sh --bootstrap
```

`install.sh` auto-detects whether bootstrap is needed (missing
Hyprland / Quickshell / grim / slurp / wl-copy / swww / cava /
playerctl / jq / notify-send), runs bootstrap if any are missing,
then installs. At the end, kills any existing zen-shell process
and spawns exactly ONE new instance.

### Expected output

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
# Should print 1
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Confirm Kintsugi themes present
ls ~/.config/hypr-control-center/themes/builtin/ | grep kintsugi
# → kintsugi-dark.json
# → kintsugi-light.json

# Confirm active theme
cat ~/.config/hypr-control-center/current-theme.json | grep '"id"'
# → "id": "kintsugi-dark"
```

---

## Keybinds (defaults)

```
Super+A                     Start menu
Super+,                     Settings
Super+C                     Control Panel (quick toggles)
Super+W                     Wallpaper picker
Super+T                     Terminal (auto-detect)
Super+/                     Keybind cheatsheet
Super+SHIFT+S               Screenshot rope (region capture + annotation)
Super+SHIFT+CTRL+Esc        Panic recovery (kills + respawns shell)
```

---

## Project structure

```
zen_barebone_alpha_development/
├── install.sh                  Smart installer (auto-detects bootstrap need)
├── bootstrap.sh                One-time system setup (deps via paru)
├── zen-shell-v5/               QML files for Quickshell
│   ├── shell.qml               Root shell (windows + IPC handlers)
│   ├── Bar.qml                 The status bar
│   ├── ControlPanel.qml        Quick-toggles popup (Super+C)
│   ├── ZenSettings.qml         Full settings UI (Super+,)
│   ├── StartMenuPanel.qml      App launcher (Super+A)
│   ├── WallpaperPicker.qml     Wallpaper grid + Online repo tab
│   ├── ColorPicker.qml         PopupWindow color picker (v4.10 rewrite)
│   ├── PaletteBox.qml          Clickable 60×60 palette swatch (v4.11.2)
│   ├── ZenComboBox.qml         Material dropdown with WCAG contrast
│   ├── DarkModeService.qml     GTK/libadwaita dark mode sync (v4.7)
│   ├── *Service.qml            Singleton state services
│   ├── UserProfileExportService.qml  Profile snapshot/restore (v6.16.4.12)
│   ├── ProfileManagerSection.qml     Profile management UI (v6.16.4.12)
│   ├── ZenNotificationCenter.qml     Calendar + notifs + system icons (v6.16.4.12)
│   └── *Page.qml               Settings page components
├── hypr-config/                Hyprland config modules + template
├── scripts/                    Helper scripts
│   ├── zs-restart.sh
│   ├── zen-terminal.sh         Super+T auto-detect chain (v4.7)
│   ├── zen-darkmode.sh         GTK/libadwaita dark mode sync (v4.7)
│   └── zen-panic.sh            Panic recovery (v6.16.4)
├── themes-builtin/             19 pre-installed theme JSON files
│   ├── kintsugi-dark.json      ← NEW in v6.16.4.11.2 (default)
│   ├── kintsugi-light.json     ← NEW in v6.16.4.11.2
│   ├── tokyo-night.json
│   ├── nord.json
│   └── ... (16 more)
├── bin/                        Toggle scripts copied to ~/.local/bin
├── CHANGELOG-v6.16.4.12.5.md    Detailed changelog for THIS release
└── CHANGELOG-v6.16.4.*.md      Historical alpha cycle notes
```

---

## Locations & state files

| Path | Purpose |
|---|---|
| `~/.config/quickshell/zen-shell/` | All QML files |
| `~/.config/hypr-control-center/themes/builtin/` | Built-in theme JSONs (19) |
| `~/.config/hypr-control-center/themes/custom/` | User-created themes (v4.11) |
| `~/.config/hypr-control-center/current-theme.json` | Active theme snapshot |
| `~/.config/zen-shell/user-avatar-*.png` | Versioned uploaded avatars |
| `~/.config/zen-shell/wallpapers/` | Local wallpaper folder |
| `~/.config/zen-shell/user-profile.json` | Avatar override JSON |
| `~/.config/hypr/zen-mouse.conf` | Mouse sensitivity (sourced by hyprland.conf) |
| `~/.config/quickshell/zen-shell/panel-state.json` | Panel mode, bar layout, module zones, **position** |
| `~/.config/zen-shell/profiles/` | Profile JSON storage (v6.16.4.12) |
| `~/.config/zen-shell/profiles/active-profile.state` | Currently loaded profile name |
| `~/.config/quickshell/zen-shell/wallpaper-state.json` | Current wallpaper path |
| `~/.cache/zen-shell/wallpapers/listing.json` | Cached GitHub API repo listing |
| `~/.local/share/zen-shell/darkmode.state` | Dark mode toggle state (v4.7) |
| `~/.local/bin/zs-restart.sh` | Restart helper |
| `~/.local/bin/zen-terminal.sh` | Super+T dispatcher (v4.7) |
| `~/.local/bin/zen-darkmode.sh` | Dark mode sync helper (v4.7) |
| `~/.local/bin/zen-panic.sh` | Panic recovery script (v6.16.4) |
| `/tmp/zen-avatar-debug.log` | Avatar upload diagnostic trace |
| `/tmp/zen-wifi-debug.log` | WiFi Connect audit log (v4.8) |
| `/tmp/zs-restart.log` | Restart helper trace |

---

## Diagnostic commands

```bash
# What zen-shell processes are running?
pgrep -fa 'quickshell.*zen-shell'

# What did the last avatar upload do?
tail -50 /tmp/zen-avatar-debug.log

# What did the last WiFi connect attempt do?
tail -50 /tmp/zen-wifi-debug.log

# What did the last nuclear restart do?
tail -50 /tmp/zs-restart.log

# Live shell logs (errors, warnings, console.log output)
journalctl --user -f -t quickshell

# Verify current mouse settings reached Hyprland
hyprctl getoption input:sensitivity
hyprctl getoption input:scroll_factor
hyprctl getoption input:natural_scroll

# Check dark mode sync state
cat ~/.local/share/zen-shell/darkmode.state
gsettings get org.gnome.desktop.interface color-scheme
```

---

## Re-install (replace running shell cleanly)

The installer's end-of-install launch sequence:

1. Lists all existing `quickshell.*zen-shell` processes
2. SIGTERM × 3 rounds (300ms apart) — graceful shutdown chance
3. SIGKILL × 2 rounds — forced termination
4. **Verifies** nothing survived. If anything did, REFUSES to spawn another.
5. `setsid -f quickshell -p ~/.config/quickshell/zen-shell`

Result: exactly ONE shell, every time. No more stacked duplicate bars.

---

## Known caveats

- **Quickshell version**: Tested on Quickshell 0.2.1+ with `PopupWindow`
  support (required for v4.10 color picker rewrite). If Settings/Control
  Panel still blocks click-through, update Quickshell.
- **Hyprland version**: 0.54+ required. New `windowrule` / `layerrule`
  anonymous syntax used throughout (not deprecated `windowrulev2` or old
  block format).
- **GitHub API rate limit**: Wallpaper repo browser uses unauthenticated
  GitHub API (60 req/hr per IP). Cached listing means normal use never
  hits this.
- **DMI sysfs**: Device / BIOS rows in User Profile read from
  `/sys/class/dmi/id/*`. On VMs / containers / WSL these files may be
  empty or contain placeholder strings — the rows hide automatically.
- **Existing users keep their theme**: The v4.11.2 installer sets
  Kintsugi Dark as the default **only for fresh installs** (when
  `current-theme.json` doesn't exist). If you're upgrading and want to
  switch, open Settings → Themes → Kintsugi Dark.

---

## License

Personal project by Zenpy Gekinzen. No license attached at the moment;

