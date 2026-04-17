# Zen Shell v6.10 — Changelog

## v6.10 — Desktop Widgets + Screenshots + Smart Installer

### Desktop Widgets Settings Page

New "Desktop Widgets" tab in Settings (left panel, under OTHER).
Configures desktop overlay widgets with persistent JSON state.

- **Primary Clock** — enable/disable, timezone dropdown (19 zones
  including Asia/Manila default), 24h/12h format toggle
- **Secondary Clock** — dual timezone support for partner/family.
  Pre-configured with America/Winnipeg. Enable/disable independently.
- **Weather Widget** — enable/disable, auto-detect location (IP) or
  manual city input. Live preview shows current temp, condition,
  and detected location from WeatherService.
- **System Monitor** — enable/disable. Live preview of CPU%, RAM,
  GPU temp with color coding.

All settings persist to `~/.config/quickshell/zen-shell/widgets-state.json`.

### Screenshot Fix (grim adapter not enabled)

Flameshot on Hyprland shows "grim adapter is not enabled" when the
daemon starts without correct Wayland environment variables.

**zen-screenshot.sh** — new screenshot script that:
- Uses **grim + slurp** as primary method (most reliable on Hyprland)
- Detects active monitor via `hyprctl monitors -j`
- `Super+F12` → region select (slurp box → grim capture)
- `Super+Shift+F12` → full active monitor → save to ~/Pictures/Screenshots
- `Print` → region select
- `Shift+Print` → full monitor → clipboard (via wl-copy)
- Falls back to flameshot with correct env vars if grim not available
- Sends desktop notification with screenshot preview

**Dependencies auto-installed:** grim, slurp, wl-clipboard, flameshot
added to recommended deps. Installer auto-offers to install via
paru/yay/pacman on Arch/CachyOS.

### Smart Installer

- Pre-flight check: detects existing install, shows QML count
- Warning before proceeding, explains what will be changed
- Full auto-backup of `~/.config/quickshell/zen-shell/` before any changes
- Auto-copies ZenClock→Clock.qml, ZenWorkspaces→Workspaces.qml
  with backup (no interactive prompt — just does it safely)
- Auto-updates Taskbar.qml (close button fix)
- Clean output design, no excessive emoji

### Keybind Updates

| Keybind | Action |
|---|---|
| Super + F12 | Screenshot region select (active monitor) |
| Super + Shift + F12 | Full active monitor screenshot |
| Print | Region select |
| Shift + Print | Full monitor → clipboard |
| Super + B | Toggle btm system monitor |
| Super + Return | Toggle terminal (termrun) |
| Super + N | Toggle wifi |
| Super + T | Open kitty |

Both `binds.conf` and `keybinds-update.conf` updated — no more
conflicting screenshot binds. All paths use `~/.local/bin/` prefix
for reliability.

### Bug Fixes

- **layerrule noanim error** — removed invalid `noanim = true` from
  `hyprland-layer-rules.conf` (not a valid layerrule property)
- **btm-toggle.sh** — no longer requires `~/.config/alacritty/btm.toml`,
  falls back to default alacritty config, then kitty
- **Taskbar close button** — X button MouseArea z-order fixed (wma
  declared before RowLayout, close button has `z: 1`). Larger 24x24
  click target with red hover feedback.
- **Animation preset persistence** — selected preset name saved to
  `animation-state.json`, survives logout/reload
- **Start menu alignment** — left edge aligns with start button left
  edge in island mode. Correct bar offset calculation for all modes.
- **Display primary toggle** — "Set as primary" button per monitor card
- **Display persistence** — saves to `hyprland-monitors.conf`, auto-sourced

### Previous (included in this build)

- WeatherService.qml — Open-Meteo, no API key, auto-location
- SystemMonitorService.qml — CPU/GPU/RAM/Network, no Python
- ZenWeather.qml, ZenSysMonitor.qml — bar modules
- ZenClock.qml, ZenWorkspaces.qml — auto-apply bar modules
- ColorSwatch popup HSL picker
- Draggable monitor preview with collision avoidance
- swww multi-session fix (cosmic/hyprland/dwl)
- Workspace limit (3-10 configurable)

## New Files

- zen-shell-v5/WidgetsPage.qml
- scripts/zen-screenshot.sh

## Modified Files

- install.sh (smart detect + auto-backup + grim/slurp deps)
- hypr-config/binds.conf (screenshot keybinds)
- hypr-config/keybinds-update.conf (btm, termrun, screenshot)
- hypr-config/hyprland-layer-rules.conf (removed invalid noanim)
- scripts/btm-toggle.sh (fallback terminal)
- zen-shell-v5/Taskbar.qml (close fix, included in tarball)
- zen-shell-v5/StartMenu.qml (alignment fix)
- zen-shell-v5/AnimationsPage.qml (preset persistence)
- zen-shell-v5/ZenSettings.qml (widgets nav entry)

## Install

    tar -xzf zen-shell-v6_10-complete.tar.gz
    cd zen-shell-v6_10-complete
    ./install.sh

Arch Linux / CachyOS. Installer uses paru > yay > pacman for
missing packages.

## Test Checklist

- Super+F12 → slurp region select → screenshot saved + notification
- Super+Shift+F12 → full active monitor screenshot
- Super+B → btm opens in terminal
- Super+, → Settings → Desktop Widgets tab visible
- Enable/disable clock toggle → persists after close
- Secondary clock → Winnipeg timezone shows
- Weather → live preview shows temp + condition
- No "layerrule noanim" error in Hyprland log
- Animation → select Diablo-2 → logout → login → still Diablo-2
