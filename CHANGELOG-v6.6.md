# Zen Shell v6.6 — Changelog

Layered on v6.1 → v6.2 → v6.3 → v6.4 → v6.4.2 → v6.5 → v6.6.
One installer applies all. Previous install is backed up to
`$SHELL_DIR.bak-<timestamp>`.

## v6.6 — this release

### 1. SwayNC notification theming

**Symptom (pre):** "panu pala yun notification dati kasi swaync ako
kunwari change ako ng volume or any notification dapat may nag prompt"

SwayNC wasn't integrated — notifications (volume change, bluetooth
events, etc.) either didn't appear or used stock styling that clashed
with the theme.

**Fix:** New `regen-swaync-theme.sh` — ported your Python GTK module
to bash. Reads `current-theme.json` via `jq`, writes a complete SwayNC
`style.css` with all 6 color variables (background, background-alt,
text, selected, hover, urgent) + theme-aware notifications, control
center, notification groups, and widgets (DND, MPRIS, volume,
backlight, buttons grid, inhibitors).

- Backup: copies existing `style.css` → `style.css.backup` on first
  run (only once, to preserve your original)
- Reload: `swaync-client --reload-css` fires on every regen
- Auto-start: if `swaync` daemon not running, spawns it via nohup
- Theme sync: `ThemeService.applyTheme()` now triggers this as a
  Process after every theme apply

### 2. Custom theme profiles (Theme Palette section)

**Symptom (pre):** "yung mga pwd ma color picker isa isa yan ma assign
color once napalitan yan matic magiging custom profile na siya"

Manual color editing in the shell had no persistence — changes would
reset on restart, and there was no way to name/save a variant.

**Fix:** New "Theme Palette" section in General page — 12 color
swatches (bg0, bg1, bg2, fg, grey0, red, orange, yellow, green, aqua,
blue, purple). Each ColorSwatch calls `ThemeService.setAccent(key, hex)`
which updates the live color immediately. A "Save" button appears
(enabled when dirty) — clicking fires a zenity prompt for a name,
then `ThemeService.saveAsCustomTheme(name)` writes a full theme JSON
to `~/.config/hypr-control-center/themes/custom/<n>.json`, sets it
as the current theme, and cascades through:
- Shell reload (bar repaints)
- Terminal configs regen (Alacritty + fuzzel)
- SwayNC CSS regen
- Themes page list refresh (new profile appears immediately)

A "Revert" button also appears — reloads current-theme.json to bounce
back to persisted colors if you didn't want to keep the edits.

### 3. Bar Modules page — clock / workspace / font formats

**Symptom (pre):** Paul's original Python module had 13 clock formats,
11 workspace number presets (numbers, Korean 일-십, Chinese 一-十,
Japanese 壱-拾, Roman I-X, nerd dots/circles/squares, symbols, empty,
custom), and 10 Nerd Font family options. None of this was exposed
in the QML shell.

**Fix:** New `ZenConstants.qml` singleton holds all the data. New
`BarModulesPage.qml` in the nav (under INPUT & DISPLAY) with 3
dropdown rows + live previews:

- **Clock format**: dropdown of 13 options with live preview ticking
  every second. Formats include `%I:%M %p`, `%H:%M:%S`, `%Y-%m-%d`,
  `%A, %B %d`, etc. `ZenConstants.formatClock()` implements a
  strftime-subset so the QML Clock module can render it identically
  to Paul's Python version.
- **Workspace format**: dropdown of 11 presets with a live preview
  showing workspaces 1-10 as they'll appear in the bar.
  `ZenConstants.workspaceIcon(preset, n)` returns the right glyph.
- **Font family**: dropdown of 10 presets with "The quick brown fox"
  preview. `ZenConstants.fontPrimary(id)` returns the primary font
  name (for `Text.font.family`). Every font has the
  `JetBrainsMono Nerd Font Propo` fallback chain for icon glyphs.

All selections persist to `PanelState` — `clockFormatIndex`,
`workspaceFormat`, `fontFamilyId` — and load on shell start.

### 4. install.sh — v6.6 updates

- `swaync` + `swaync-client` added to recommended deps check
- `regen-swaync-theme.sh` added to install scripts list
- First-run step: runs `regen-swaync-theme.sh` so SwayNC starts
  themed right away

## Files

### New in v6.6
- `zen-shell-v5/ZenConstants.qml` — static lookup tables (clock,
  workspace, font formats) + formatClock/workspaceIcon/fontPrimary
  helper functions
- `zen-shell-v5/BarModulesPage.qml` — dedicated page for format pickers
  with live previews
- `scripts/regen-swaync-theme.sh` — SwayNC CSS generator + daemon
  management

### Modified in v6.6
- `zen-shell-v5/ThemeService.qml` — added `saveAsCustomTheme()`,
  `setAccent()`, `colorToHex()` helpers; `swayncThemer` Process hook
  after every theme apply
- `zen-shell-v5/PanelState.qml` — new `clockFormatIndex`,
  `workspaceFormat`, `fontFamilyId` persisted properties
- `zen-shell-v5/GeneralPage.qml` — new "Theme Palette" section with
  12 color swatches + Save/Revert buttons + zenity name prompt
- `zen-shell-v5/ZenSettings.qml` — "Bar Modules" nav entry +
  BarModulesPage in StackLayout
- `install.sh` — v6.6 banner, swaync deps, swaync-themer script,
  first-run swaync task

### Still fresh from v6.5
- `zen-shell-v5/WallpaperPicker.qml` (fixes Super+W)
- `scripts/{fix-monitor-scale,blueman-toggle,btm-toggle,wifi-toggle,termrun,regen-terminal-themes}.sh`

### Unmodified (preserved)
- Other pages, services, modules from v6.1 → v6.5

## State files

    ~/.config/quickshell/zen-shell/
      wallpaper-v5.json
      swww-state.json
      settings-state.json
      settings-state-v2.json
      panel-state.json             # v6.6: +clockFormatIndex, +workspaceFormat, +fontFamilyId

    ~/.config/hypr-control-center/
      current-theme.json
      themes/builtin/*.json
      themes/custom/*.json          # v6.6: populated by saveAsCustomTheme()

    ~/.config/swaync/
      style.css                     # v6.6: generated on every theme apply
      style.css.backup              # v6.6: original backed up on first run

    ~/.cache/zen-shell/
      swww.log

    /tmp/zen-theme-regen.log        # terminal themer output
    /tmp/zen-swaync-regen.log       # v6.6: swaync themer output

## Install

    tar -xzf zen-shell-v6_6-complete.tar.gz
    cd zen-shell-v6_6-complete
    ./install.sh

## Test checklist

### SwayNC theming

1. `paru -S swaync` if not installed
2. Run installer → swaync auto-starts themed
3. Trigger a notification (e.g. change volume) → should appear with
   your theme's bg/fg/accent colors
4. Apply a different theme in control panel → notification colors
   should update on next notification

### Custom palette profile

1. Super+, → General → scroll to "Theme Palette"
2. Click any color swatch, edit the hex → bar repaints immediately,
   Save button becomes active (blue)
3. Click Save → zenity prompt → type name like "My Dark Arc"
4. After save: Themes page now lists "My Dark Arc" in custom section
5. Switch to another theme, then back to yours → persisted

### Bar Modules formats

1. Super+, → Bar Modules
2. Clock → change dropdown → live preview updates every second
3. Workspaces → change dropdown → 10 pills update to new glyph style
4. Font → change dropdown → preview renders in selected font
5. Close settings → bar modules will pick up selections on next launch
   (current shell Clock/Workspaces modules need a shell reload)

### Regression checks (all still work)

- Super+W → wallpaper picker applies on click (v6.5)
- Floating bar doesn't clip on right (v6.4.2)
- Island bar hugs content (v6.3)
- Start menu apps clickable (v6.3)
- Themes apply to shell bar live (v6.4)

## Next iterations (noted for future releases)

- **Bar module QML files (SysRow, Clock, Taskbar)** — these live on
  your system outside the tarball. For the Bar Modules page to affect
  what actually renders in the bar, those modules need to be patched
  to read from `PanelState.clockFormatIndex` / `PanelState.workspaceFormat`
  / `PanelState.fontFamilyId` + call `ZenConstants.formatClock()` etc.
  If you paste the current `~/.config/quickshell/zen-shell/Clock.qml`
  and `Taskbar.qml` in a future chat, I can patch them to honor the
  new format settings.

- **Integrate swaync toggle into Zen Shell control center** —
  currently uses external `swaync-client -t` for toggle. Could be
  replaced with a QML-native notification panel that reads the
  same SwayNC socket.
