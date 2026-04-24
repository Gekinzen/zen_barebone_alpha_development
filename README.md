# Zen Shell — Quickshell-native desktop for Hyprland

> **➤ Current stable: `v6.16.4.11.2`** · promoted 2026-04-24

**Repo branch:** `main`
**Website:** https://zenshell.obsidevs.com
**Author:** Paul Hansen Yuki ([Gekinzen](https://github.com/Gekinzen))

A QML desktop environment built on [Quickshell](https://quickshell.outfoxxed.me/)
for [Hyprland](https://hyprland.org/) 0.54+. Includes a configurable bar,
start menu, control panel, settings UI, system monitoring, wallpaper
manager, theme engine, and audio-reactive music visualization.

---

## 📜 Version timeline

Every release that has shipped, earliest first. The current stable is
highlighted. All previous releases are kept in this section for
historical context and migration reference — **wala tayong nabawasan**,
every feature from every release that made the cut is still in the
current build.

### Pre-v6.15 · Archaeological

Original GTK4 + Python shell. Replaced fully by Quickshell-native v5
architecture. Not recommended for any use today. Listed here for
attribution — the CSS module pattern, panel state machine, and
settings schema all trace back to this era.

### v6.15.x series · Historical

The GTK4 → Quickshell rewrite cycle. `v6.15.1` through `v6.15.15`
gradually replaced each component:

| Version | Landed |
|---------|--------|
| v6.15.1 | Initial Quickshell skeleton |
| v6.15.2 – v6.15.4 | Bar, Start Menu, Control Panel port |
| v6.15.5 – v6.15.8 | Settings UI with HMSection / HMRow components |
| v6.15.9 – v6.15.12 | Theme engine, wallpaper manager, audio viz |
| v6.15.13 – v6.15.15 | Avatar system, island mode, system tray |

### v6.16.1 · First unified 6.16 cut

Consolidated the 6.15 series into a single architectural baseline.
Panel, start menu, control panel, settings, wallpaper, themes all
speak the same design token system.

### v6.16.3.x series · Superseded

Panel / Power / Notifications / Lid handling cycle. `v6.16.3.1` through
`v6.16.3.8` — each bringing one subsystem up to production quality.
Battery & Power page with thermals, Notification Center with do-not-disturb,
Laptop lid suspend/resume hooks. All preserved in current build.

### v6.16.3.4.x and v6.16.3.5.x · ZenComboBox hardening

Dropdown popup had clipping issues when the model had more items than
fit in the window — popup grew past bounds, items became unclickable.
Iterations `.4.1` → `.4.6` added dynamic bounds awareness; `.5.1` → `.5.3`
tuned the flip-upward decision when space above is bigger than below.
Carried forward. v4.11.2's Material-style dropdown rebuild kept the flip
logic intact.

### v6.16.3.6.x · User Profile system

Personal Preferences section. Gender-aware lock message pools. Avatar
auto-detection chain (`~/.config/zen-shell/user-avatar.png` → `~/.face`
→ `/var/lib/AccountsService/icons/$USER` → SDDM faces). Versioned uploads.

### v6.16.3.7 – v6.16.3.8 · System Info

fastfetch-style User Profile readout. DMI device + BIOS info from
`/sys/class/dmi/id` (no sudo). GPU detection via lspci. Theme palette
preview in profile.

### v6.16.2.3.1 → v6.16.2.3.6 · Click-through + install hardening

`v6.16.2.3.1` → `v6.16.2.3.6` the hotfix series that shipped:

- **v6.16.2.3.1 → .3.4** — Music rope click-through (`mask: Region {}`
  on stringsWindow). Settings / Control Panel click-through via same
  mask pattern. `OpacityMask` avatar circular mask (replaces the GLSL
  shader that silently failed on some Qt builds). Default wallpaper
  auto-download from `Gekinzen/images-demo`.
- **v6.16.2.3.5** — Mouse sensitivity UI. Hyprland version branch/commit
  tooltip in sys-info popover.
- **v6.16.2.3.6** — Duplicate-bar-on-reinstall fix. Bulletproof
  `install.sh` kill loop (SIGTERM × 3 → SIGKILL × 2 → verify → spawn).
  Clock hover peek + wheel-scroll months + right-click format cycle.
  Island mode persistence (`panelStateLoaded` signal gates the
  restart logic). Versioned avatar uploads with symlink fallback +
  diagnostic log. WallpaperPicker "Online" toggle with GitHub API repo
  browse. Device + BIOS rows in User Profile.

**All features from the 2.3.x line carried forward byte-identical into
v6.16.4.x.** The 2.3.x tags exist for archaeological reference; no new
patches land there. Migration is a clean install — state files at same
paths, existing themes + wallpapers + profile carry over.

### v6.16.4.1 · Panic keybind stable point

Super+Shift+P panic reload. `install.sh` writes `zen-panic.sh`
unconditionally. First tagged release cut from the 4.x branch. Stable
on main for ~2 weeks before alpha cycle started.

### v6.16.4.2 – v6.16.4.11 · Alpha cycle (superseded by .11.2)

Eleven rapid iterations over 2 days of active debugging:

| Version | What shipped |
|---------|--------------|
| v6.16.4.2 | Widget scale + display resolution awareness (incomplete) |
| v6.16.4.3 | Widget scale actually applied · oscillation loop killed |
| v6.16.4.4 | Gaps preserved after Displays apply (was wiped by `hyprctl reload`) |
| v6.16.4.5 | Start Menu breathing room — tile 64→72, label 58→66 |
| v6.16.4.6 | Wallpaper grid 5→4 cols · ColorPicker v1 (Qt Popup, buggy) |
| v6.16.4.7 | Super+T → `zen-terminal.sh` auto-detect · Dark Mode toggle |
| v6.16.4.8 | WiFi named-arg rewrite + audit log · ColorPicker v2 LEFT (still buggy) |
| v6.16.4.9 | ColorPicker v3 window bounds + coord translation (still buggy) |
| v6.16.4.10 | **ColorPicker complete rewrite** — Quickshell PopupWindow + live hex typing |
| v6.16.4.11 | Custom Themes management on Themes page |

Four iterations on the color picker alone. Lesson learned: when Qt's
high-level abstraction keeps misbehaving on Wayland, drop to the
platform-native primitive (`PopupWindow` = `xdg_popup`).

### ➤ v6.16.4.11.2 · **CURRENT STABLE (promoted 2026-04-24)**

```
┌─────────────────────────────────────────────────────────────┐
│  v6.16.4.11.2 is the recommended install for all users.     │
│  Promoted from alpha-v6.16.4.11.2 after 72h testing.        │
└─────────────────────────────────────────────────────────────┘
```

Highlights over 4.11:

| Area | What changed |
|------|--------------|
| **Theme Palette relocation** | Moved from General page → Themes page. Single source of truth. Old General-page HMSection preserved via `visible: false` (wala tayong babawasan literal) |
| **PaletteBox component** | New compact 60×60 clickable palette swatches on Themes page. Hover shows edit pencil. Click opens picker with live preview. |
| **ZenComboBox Material rebuild** | Rotating chevron, accent dots, blue left accent bar on highlight, rounded 10px popup with subtle shadow. **WCAG luminance-based auto-contrast text** — readable on any theme (light OR dark, handles mismatched palette fg/bg). |

Full rollup: [CHANGELOG-ROLLUP-v6.16.4.x.md](./CHANGELOG-ROLLUP-v6.16.4.x.md).

### Upcoming · v6.16.4.12 (next alpha cycle)

**Profile Export/Import** — Phase 2 of the themes/profiles work.

New files planned: `UserProfileExportService.qml`, `ProfileManagerSection.qml`.

A single profile JSON captures the **entire Settings state**: active
theme + all custom themes (embedded palettes), Settings V2 dump
(gaps/borders/animations), panel state, widget layout, bar layout,
wallpaper basename. Shareable as portable JSON — friends with same
dotfiles can import and auto-reflect. Rename / Delete / Activate per
profile. Storage at `~/.config/zen-shell/profiles/`.

### Upcoming · v6.16.5 (next minor)

**In-app Updates Manager** — update channel picker (Stable / Beta /
Alpha), installed version readout, changelog browser, download + apply
in-place, rollback to prior versions. No more terminal git-checkout
dance. Mockup already staged on the website.

---

## Install

### Quick (from release tarball)

```bash
tar -xzf zen-shell-v6.16.4.11.2-complete.tar.gz
cd zen-shell-v6.16.4.11.2
./install.sh
```

### From git

```bash
git clone https://github.com/Gekinzen/zen-shell.git
cd zen-shell
git checkout main
./install.sh
```

`install.sh` auto-detects whether bootstrap is needed (missing Hyprland,
Quickshell, grim, slurp, wl-copy, swww, cava, playerctl, jq, zenity,
notify-send), runs bootstrap if any are missing, then installs. At the
end, kills any existing zen-shell process and spawns exactly ONE new
instance.

### Verify after install

```bash
# Should print 1
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Should print the current version
grep "version" ~/.config/quickshell/zen-shell/ZenVersion.qml | head -1
# → readonly property string version: "v6.16.4.11.2"

# Watch avatar uploads / wifi connects / theme changes
tail -f /tmp/zen-avatar-debug.log
tail -f ~/.cache/zen-shell/wifi.log
```

---

## Keybinds (defaults)

```
Super+A          Start menu
Super+,          Settings
Super+C          Control Panel (quick toggles + Dark Mode toggle ← v4.7)
Super+W          Wallpaper picker
Super+T          Terminal (auto-detect)                            ← v4.7
Super+/          Keybind cheatsheet
Super+SHIFT+S    Screenshot rope (region + annotate)
Super+SHIFT+P    Emergency panic reload                            ← v4.1
Super+SHIFT+W    Manual resume from sleep handler
```

---

## Project structure

```
zen-shell-v6.16.4.11.2/
├── install.sh                Smart installer with bootstrap auto-detect
├── bootstrap.sh              One-time system setup (deps via paru)
│
├── zen-shell-v5/             QML files for Quickshell
│   ├── shell.qml             Root shell (windows + IPC handlers)
│   ├── Bar.qml               Status bar
│   ├── ControlPanel.qml      Quick toggles + Dark Mode row       ← v4.7
│   ├── ZenSettings.qml       Full settings UI
│   ├── StartMenuPanel.qml    App launcher
│   ├── WallpaperPicker.qml   Grid + Online repo tab
│   │
│   ├── ThemeService.qml      Palette + custom theme CRUD · renameCustomTheme() ← v4.11
│   ├── ColorSwatch.qml       Hex input + Quickshell PopupWindow picker ← v4.10
│   ├── PaletteBox.qml        Compact 60×60 clickable swatch      ← v4.11.2
│   ├── ZenComboBox.qml       Material-style + WCAG auto-contrast ← v4.11.2
│   ├── DarkModeService.qml   GTK3/4 + libadwaita sync            ← v4.7
│   │
│   ├── *Service.qml          Other singleton state services
│   └── *Page.qml             Settings pages (14 total)
│
├── hypr-config/              Hyprland config modules
│   ├── keybinds-update.conf  Super+T → zen-terminal.sh           ← v4.7
│   └── ...
│
├── scripts/                  Helpers → ~/.local/bin
│   ├── zs-restart.sh         Restart helper
│   ├── zen-terminal.sh       Terminal launcher                   ← v4.7
│   ├── zen-darkmode.sh       GTK dark/light switcher             ← v4.7
│   └── zen-panic.sh          Emergency reload                    ← v4.1
│
├── themes-builtin/           Pre-installed theme JSON files (16)
├── bin/                      Toggle scripts → ~/.local/bin
│
└── CHANGELOG-*.md            Historical release notes (per version)
```

---

## Locations & state files

| Path | Purpose | Since |
|------|---------|-------|
| `~/.config/quickshell/zen-shell/` | All QML files | — |
| `~/.config/zen-shell/user-avatar-*.png` | Versioned avatars | v6.16.2.3.6 |
| `~/.config/zen-shell/wallpapers/` | Local wallpaper folder | — |
| `~/.config/zen-shell/user-profile.json` | Avatar override | v6.16.3.6 |
| `~/.config/zen-shell/terminal.conf` | Terminal override | v4.7 |
| `~/.config/hypr/zen-mouse.conf` | Mouse sensitivity | v6.16.2.3.5 |
| `~/.config/hypr-control-center/themes/custom/*.json` | Custom themes | v4.11 |
| `~/.config/hypr-control-center/themes/current-theme.json` | Active theme | — |
| `~/.config/gtk-3.0/settings.ini` | Dark mode sync target | v4.7 |
| `~/.config/gtk-4.0/settings.ini` | Dark mode sync target | v4.7 |
| `~/.local/share/zen-shell/darkmode.state` | Dark/light choice | v4.7 |
| `~/.local/bin/zs-restart.sh` | Restart helper | — |
| `~/.local/bin/zen-terminal.sh` | Terminal launcher | v4.7 |
| `~/.local/bin/zen-darkmode.sh` | GTK mode switcher | v4.7 |
| `~/.config/quickshell/zen-shell/panel-state.json` | Panel mode, bar layout | — |
| `~/.config/quickshell/zen-shell/wallpaper-state.json` | Current wallpaper | — |
| `~/.cache/zen-shell/wallpapers/listing.json` | GitHub repo listing cache | v6.16.2.3.6 |
| `~/.cache/zen-shell/wifi.log` | WiFi connect audit | v4.8 |
| `~/.cache/zen-shell/terminal.log` | Terminal launch trace | v4.7 |
| `~/.cache/zen-shell/darkmode.log` | GTK mode switch trace | v4.7 |
| `/tmp/zen-avatar-debug.log` | Avatar upload trace | v6.16.2.3.6 |
| `/tmp/zs-restart.log` | Restart helper trace | — |

---

## Diagnostic commands

```bash
# What zen-shell processes are running?
pgrep -fa 'quickshell.*zen-shell'

# What version is loaded?
grep "version" ~/.config/quickshell/zen-shell/ZenVersion.qml | head -1

# Avatar upload trace
tail -50 /tmp/zen-avatar-debug.log

# Nuclear restart trace
tail -50 /tmp/zs-restart.log

# Live shell logs
journalctl --user -f -t quickshell

# Avatar Image status
journalctl --user -f | grep -E "AvatarBigImg|FooterAvatar|PopoverAvatar"

# WiFi connect tracing (v4.8+)
tail -50 ~/.cache/zen-shell/wifi.log

# Terminal launch tracing (v4.7+)
tail -50 ~/.cache/zen-shell/terminal.log

# Mouse settings reached Hyprland?
hyprctl getoption input:sensitivity
hyprctl getoption input:scroll_factor
hyprctl getoption input:natural_scroll

# Current dark mode state (v4.7+)
cat ~/.local/share/zen-shell/darkmode.state
gsettings get org.gnome.desktop.interface color-scheme
```

---

## Re-install (replace running shell cleanly)

The installer's end-of-install launch sequence (unchanged from
v6.16.2.3.6 through current):

1. Lists all existing `quickshell.*zen-shell` processes
2. SIGTERM × 3 rounds (300ms apart) — graceful shutdown chance
3. SIGKILL × 2 rounds — forced termination
4. **Verifies** nothing survived. If anything did, REFUSES to spawn another.
5. `setsid -f quickshell -p ~/.config/quickshell/zen-shell`

Result: exactly ONE shell, every time. No more stacked duplicate bars.

---

## Known caveats

- **Quickshell version**: Tested on Quickshell built from master near
  Hyprland 0.54.x. Older Quickshell may not support `mask: Region` or
  `PopupWindow` — if Settings/Control Panel blocks click-through OR the
  color picker misbehaves, update Quickshell.
- **GitHub API rate limit**: Wallpaper repo browser uses unauthenticated
  GitHub API (60 req/hr per IP). The cached listing means normal use
  never hits this.
- **DMI sysfs**: Device / BIOS rows in User Profile read from
  `/sys/class/dmi/id/*`. On VMs / containers / WSL these files may be
  empty or contain placeholder strings — the rows hide automatically.
- **Dark Mode toggle requires `zenity`**: for GTK theme switching prompts.
  Installed by `--bootstrap`.
- **Custom theme rename requires `jq`**: for JSON field rewriting.
  Installed by `--bootstrap`.
- **Color Picker requires Quickshell `PopupWindow`**: v4.10+ uses this
  primitive. Older Quickshell builds will fail to load ColorSwatch.qml.

---

## License

Personal project by Paul Hansen Yuki, shipped as an
[OBSIDEVS](https://obsidevs.com) deliverable.
No license attached at the moment; contact Paul (`paulyuki.com`) before
redistributing.

---

## Credits

Built on [Quickshell](https://quickshell.outfoxxed.me/), [Hyprland](https://hyprland.org),
and a lot of overnight debugging.
