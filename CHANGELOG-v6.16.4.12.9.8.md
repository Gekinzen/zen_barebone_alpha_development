# v6.16.4.12.9.8 — Modori (戻り) · hotfix 8

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.7 — Modori hotfix 7

## Summary

Brings the **GTK / libadwaita Dark Mode toggle** back to the
Modori alpha line. The feature originally landed in Kintsugi
(v6.16.4.7) but didn't carry forward through Hikari/Tsubasa/
Hiraki/Tachiagari/Modori as the alpha line worked through other
priorities. This drop wires the existing `DarkModeService.qml`
singleton + `zen-darkmode.sh` script + the dormant Control Panel
toggle row into a working feature.

## What you get

A new toggle row in the **Control Panel** (Super+C), right after
Gaming Boost:

- 🌙 / ☀️ icon that flips with the current state
- "Dark Mode" / "Light Mode" label
- Sub-label: "GTK3 / GTK4 / libadwaita apps using {dark,light}
  theme"
- HMSwitch visual indicator that mirrors the toggle state

One tap flips four sync points atomically:

1. **`gsettings color-scheme`** → `prefer-dark` / `default`
   (libadwaita + GTK4 apps read this)
2. **`gsettings gtk-theme`** → `Adwaita-dark` / `Adwaita`
   (legacy GTK3 apps that read gsettings)
3. **`~/.config/gtk-3.0/settings.ini`** → `gtk-theme-name=` and
   `gtk-application-prefer-dark-theme=1/0` (GTK3 apps that bypass
   gsettings — Thunar with certain themes, GIMP, etc.)
4. **`~/.config/gtk-4.0/settings.ini`** → same key/value pattern
   for GTK4 apps that bypass gsettings

State persists to `~/.local/share/zen-shell/darkmode.state` so
the next shell launch reads it back instantly without querying
gsettings.

Apps that respond live (no restart needed):
- Thunar
- Nautilus
- GNOME Settings
- Geary
- GIMP (GTK port)
- gnome-text-editor / gedit
- Most libadwaita apps

Apps with their own theme preference (Firefox, Chromium with
their own dark mode toggle) are unaffected by design — they
manage their own theme.

## Architecture

### `zen-darkmode.sh` script

The source of truth for sync. Handles all four locations
atomically + writes the persistence state file. Usage:

```bash
zen-darkmode.sh dark      # → switch to dark, exit 0 echoing "dark"
zen-darkmode.sh light     # → switch to light, exit 0 echoing "light"
zen-darkmode.sh toggle    # → flip whatever is currently set
zen-darkmode.sh state     # → echo "dark" or "light" (read state)
```

settings.ini updates use a portable `awk` that preserves every
other key in the file. We don't `> ini`-clobber — if the user
has custom GTK keys set, they survive the toggle.

`gsettings` calls are non-fatal: if `gsettings` isn't installed
or the schema isn't available (some minimal Arch installs), the
script logs a warning and continues to the settings.ini fallback.
The state file write always happens.

Audit log at `~/.cache/zen-shell/darkmode.log` with timestamps.

### `DarkModeService.qml` singleton

The QML wrapper around the script. Probes availability at
startup (does the script exist + is it executable?). If yes,
runs `zen-darkmode.sh state` to read the current dark/light
choice into the reactive `isDark` boolean.

Public API:

```qml
DarkModeService.isDark        // reactive boolean
DarkModeService.available     // false if script missing
DarkModeService.busy          // true while a toggle is in flight

DarkModeService.toggle()      // flip current
DarkModeService.setDark(true) // set explicit
DarkModeService.toggled       // signal: emits the new state
```

The setter is optimistic (updates `isDark` immediately for snappy
UI), then re-probes after the script returns to confirm the new
state actually landed. If the script fails for any reason, the
re-probe corrects the visual back to the truth.

### Control Panel UI row

Lives in `ControlPanel.qml`, right after the Gaming Boost row.
Uses the same row pattern (Rectangle + RowLayout + sibling
MouseArea) as Gaming Boost — proven structure that doesn't
trigger the layout-flow conflicts that plagued the sidebar user
row in earlier hotfixes.

Auto-hides via `visible: DarkModeService.available` if the
script isn't installed (e.g. on a partial install or if
`scripts/zen-darkmode.sh` was somehow missed).

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.8. |
| `zen-shell-v5/DarkModeService.qml` | (Already present in source tree, now wired into actual flow.) Singleton with `isDark`, `available`, `busy` reactive properties + `toggle()` / `setDark(bool)` methods. Probes availability + state at startup. Optimistic setter with post-apply re-probe. |
| `zen-shell-v5/ControlPanel.qml` | (Already had the dormant row.) Now actually visible + functional because DarkModeService is being instantiated and zen-darkmode.sh ships with the install. |
| `scripts/zen-darkmode.sh` | (Already present.) Authoritative sync script — handles gsettings + GTK3/4 settings.ini + state file. Portable awk for ini updates preserves user custom keys. Non-fatal gsettings handling for minimal installs. |
| `install.sh` | (Already wired.) Installs `zen-darkmode.sh` to `~/.local/bin/` as part of the standard scripts loop. Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.8.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.8
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

After install:

1. `Super+C` → Control Panel opens.
2. Scroll to find the "Dark Mode" / "Light Mode" toggle row,
   right after Gaming Boost.
3. Tap. Watch your Thunar / GNOME Settings / etc. flip themes
   instantly.
4. State persists across reboots via the state file.

Verify:

```bash
# Script is installed
ls -la ~/.local/bin/zen-darkmode.sh

# Current state
~/.local/bin/zen-darkmode.sh state
# → dark   (or light)

# Persistence file
cat ~/.local/share/zen-shell/darkmode.state

# gsettings sync
gsettings get org.gnome.desktop.interface color-scheme
# → 'prefer-dark'   (or 'default')

# settings.ini sync
grep prefer-dark ~/.config/gtk-3.0/settings.ini
grep prefer-dark ~/.config/gtk-4.0/settings.ini

# Audit log
tail ~/.cache/zen-shell/darkmode.log
```

## Override default GTK theme names

Default themes are `Adwaita-dark` / `Adwaita`. To use a custom
theme pair (e.g. you prefer Catppuccin or Tokyonight GTK themes),
set env vars in your Hyprland config:

```
env = ZEN_GTK_DARK,Catppuccin-Mocha-dark
env = ZEN_GTK_LIGHT,Catppuccin-Latte-light
```

The script picks these up. `gsettings gtk-theme` and the ini
files will be set accordingly.

## What's NOT in this drop (deferred)

- **Keybind for toggle.** Currently Control Panel only. If
  you want `Super+Shift+D` or similar for one-tap toggle without
  opening Control Panel, that's a follow-up — easy to add but
  needs a keybind-conflict check first.
- **`hypr-darkwindow` Hyprland plugin support** (per-window
  shader effects: invert colors, tint, etc.). Different beast
  entirely — would land as a separate plugin entry under the
  Plugins page. Tracked in BETA-BLOCKERS.md.
- **Auto-schedule** (sunset → dark, sunrise → light). Not in
  this drop. Tracked as a future enhancement.
- **Theme-pair-aware** (when toggling, also flip the Zen Shell
  theme to a paired Modori Dark / Modori Light selection).
  Possible follow-up if useful.

## Carry-forward from Modori .9.7

All Modori .9.7 features preserved:

- Bulletproof sidebar user labels (env-fallback resolution +
  MouseArea moved out of RowLayout)
- Smart-contrast theme engine
- Modori Dark + Light themes + paired procedural wallpapers
- Default wallpaper switched to Modori Dark on fresh install
- Settings persistence fix
- Slider-drag save corruption fix
- Left/Right panel position cards hidden + L/R-to-Bottom
  migration safety net
- Updated README image URLs pointing to actual demo repo files
- All Tachiagari .7.1 features

## Wala tayong babawasan

Pure additive feature — every existing capability stays
identical. The toggle row appears between Gaming Boost and the
Expand arrow in the Control Panel. Nothing was removed or
modified to make room.
