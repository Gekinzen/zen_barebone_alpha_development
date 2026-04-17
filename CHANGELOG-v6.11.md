# Zen Shell v6.11 — Changelog

## v6.11 — Desktop Widgets Redesign + Bar Display Target + Flameshot

### Desktop Widgets Full Redesign

Complete redesign of `DesktopWidgets.qml` matching the Python GTK CSS
reference design.

- **Clock** — 120px bold white, Font.Black weight, tight -4px letter
  spacing, heavy Text.Outline shadow. Transparent background, no card.
  Matches `.time-label-transparent` CSS class exactly.
- **Weather Card** — boxed `rgba(28,28,30,0.92)` background, 16px radius,
  380×240px. Shows weather icon, 42px temp, location, condition. Right
  column: humidity, wind speed, feels-like. Bottom: 7-day forecast row
  with day names, icons, high/low temps. Matches `.weather-compact` CSS.
- **System Monitor Card** — boxed `rgba(28,28,30,0.92)` background,
  340×360px. Red accent bar + "SYSTEM MONITOR" title + hardware names.
  2×2 card grid: CPU, GPU, RAM, Network. Each card shows usage percentage
  with color coding + animated usage bar. Network shows download/upload
  with green/blue colors. Matches `.sysmon-clean` CSS.
- **All widgets draggable** — click and drag any widget to reposition.
  Positions debounce-saved (500ms) to `widgets-state.json`. Persists
  across logout/reload/restart.
- **Secondary clock** — light blue accent color, below primary clock.

### Widget Color Modes

New "Widget Colors" section in WidgetsPage settings.

- **Default** — white text with heavy shadows (works on any wallpaper)
- **Theme** — auto-syncs text color from ThemeService.fg, accent from
  ThemeService.blue. Changes when you switch themes.
- **Custom** — pick from 10 preset colors (white, gray, red, orange,
  yellow, green, cyan, indigo, purple, pink)

Color mode persists to `widgets-state.json`.

### Bar Display Target Dropdown

New "Display Target" section in PanelPage (Panel settings).

- **All Monitors** — bar shows on every connected display (default)
- **Primary Monitor** — bar only on focused/primary monitor
- **Specific Monitor** — dropdown lists all connected monitors by name
  (e.g. DP-1, HDMI-A-1). Select one to show bar only there.

Persists to `panel-state.json` via `PanelState.barTargetDisplay`.

### Screenshot Enhancement (Flameshot + Display Targeting)

`zen-screenshot.sh` v6.11 improvements:

- **Flameshot specific display** — when using flameshot in `full` mode,
  detects active monitor geometry via `hyprctl monitors -j` and passes
  `--region WxH+X+Y` to capture only the focused monitor
- **Flameshot Wayland env** — auto-starts daemon with correct
  `XDG_CURRENT_DESKTOP=Hyprland`, `QT_QPA_PLATFORM=wayland`,
  `WAYLAND_DISPLAY` variables. No more "grim adapter not enabled" error.
- **All screens mode** — `Super+Ctrl+F12` captures all monitors combined
- **Force flameshot** — `Super+Alt+F12` opens flameshot GUI directly
- **grim+slurp remains primary** — most reliable on Hyprland

### Thunar Thumbnail Support

Installer now includes `tumbler` and `ffmpegthumbnailer` as recommended
dependencies. These enable image/video thumbnail previews in Thunar file
manager. Auto-offered via paru/yay/pacman on Arch/CachyOS.

### Widget Position Reset

New "Widget Positions" section in WidgetsPage settings:

- Shows current coordinates of Clock, Weather, System Monitor
- "Reset" button restores default positions (clock top-left, weather
  and sysmon auto-right-aligned)

### Keybind Updates

| Keybind | Action |
|---|---|
| Super + F12 | Screenshot region select (active monitor) |
| Super + Shift + F12 | Full active monitor screenshot |
| Super + Ctrl + F12 | All screens combined screenshot |
| Super + Alt + F12 | Flameshot GUI (force flameshot) |
| Print | Region select |
| Shift + Print | Full monitor → clipboard |
| Super + B | Toggle btm system monitor |
| Super + Return | Toggle terminal (termrun) |
| Super + N | Toggle wifi |
| Super + T | Open kitty |

## New Files

- zen-shell-v5/DesktopWidgets.qml (full redesign)
- zen-shell-v5/WidgetsPage.qml (color modes + position reset)

## Modified Files

- zen-shell-v5/PanelPage.qml (bar display target dropdown)
- install.sh (v6.11 banner + tumbler/ffmpegthumbnailer deps)
- scripts/zen-screenshot.sh (flameshot display targeting + allscreens)
- hypr-config/binds.conf (allscreens + flameshot keybinds)
- hypr-config/keybinds-update.conf (allscreens + flameshot keybinds)

## Install

    tar -xzf zen-shell-v6_11-complete.tar.gz
    cd zen-shell-v6_11-complete
    ./install.sh

Arch Linux / CachyOS. Installer uses paru > yay > pacman for
missing packages.

## Test Checklist

- Desktop widgets render: clock top-left, weather card top-right, sysmon below weather
- Clock shows 120px bold white text with heavy shadows
- Weather card shows temp, location, condition, humidity, wind, 7-day forecast
- System monitor shows 2×2 grid: CPU, GPU, RAM, Network with usage bars
- Drag clock widget → position saves → persists after quickshell reload
- Drag weather widget → position saves → persists
- Drag sysmon widget → position saves → persists
- Settings → Desktop Widgets → Widget Colors → switch to Theme → widget text changes color
- Settings → Desktop Widgets → Widget Colors → Custom → pick red → text turns red
- Settings → Desktop Widgets → Widget Positions → Reset → widgets return to defaults
- Settings → Panel → Display Target → Primary Monitor → bar only on focused monitor
- Settings → Panel → Display Target → specific monitor name → bar only on that monitor
- Super+F12 → grim region select → screenshot saved + notification
- Super+Shift+F12 → full active monitor screenshot
- Super+Ctrl+F12 → all screens combined screenshot
- Super+Alt+F12 → flameshot GUI opens
- Thunar shows image/video thumbnails (tumbler + ffmpegthumbnailer installed)
- No regressions: start menu, wallpaper picker, settings, animations, themes
