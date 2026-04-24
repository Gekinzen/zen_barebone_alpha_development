# Zen Shell v6.16.4.7 — Super+T fix + Dark Mode toggle

**Release date:** 2026-04-24
**Base:** v6.16.4.6
**Severity:** MEDIUM — missing keybind + new feature

---

## Paul's report

> *"ay hindi na pala ng auto on yung super + terminal ko anu
>   nangyari and pwd paki integrate nanatin yun dark mode or not
>   darkmode? add nanatin sa panel natin?"*

Two separate items: fix the broken terminal binding, plus add
a dark/light mode toggle to the Control Panel.

---

## Fix 1 — Super+T hardcoded to `kitty`

### Root cause

`hypr-config/keybinds-update.conf` line 11:

```
bind = $mainMod, T, exec, kitty
```

Hardcoded to `kitty`, but Zen Shell's default terminal everywhere
else is `alacritty` (termrun.sh, wifi-toggle.sh, btm-toggle.sh all
use alacritty). If `kitty` isn't installed, Super+T silently fails.

### Fix

New helper: `~/.local/bin/zen-terminal.sh`. Auto-detects in order:

1. `$ZEN_TERMINAL` env var (user override)
2. `~/.config/zen-shell/terminal.conf` file (persistent per-user)
3. Auto-detect: `alacritty → kitty → wezterm → foot → ghostty → x-terminal-emulator`
4. If nothing found: `notify-send` warning, logs to `~/.cache/zen-shell/terminal.log`

Bind updated to:

```
bind = $mainMod, T, exec, ~/.local/bin/zen-terminal.sh
```

Script added to install.sh's script-copy loop.

### User override

If you want a specific terminal regardless of what's installed:

```bash
# One-shot (env var):
ZEN_TERMINAL=foot ~/.local/bin/zen-terminal.sh

# Persistent (config file):
mkdir -p ~/.config/zen-shell
echo "wezterm" > ~/.config/zen-shell/terminal.conf
```

---

## Feature 2 — Dark Mode / Light Mode toggle

### Why

Zen Shell's own theming already switches the bar/panel/settings/
control-center palette, but GTK apps (Thunar, GNOME apps,
libadwaita apps) follow a separate dark/light preference via
gsettings. Without this, you'd have Zen Shell running in dark
mode with Thunar still rendering in Adwaita light. Jarring.

### What it does

A new toggle row in the Control Panel (Super+C), right after
Gaming Boost, labeled **Dark Mode** / **Light Mode** with a
🌙 / ☀️ icon. Click → flips mode.

What "flipping mode" means under the hood:

1. **gsettings `color-scheme`** → `prefer-dark` or `default`
   - This is what libadwaita + GTK4 apps read
2. **gsettings `gtk-theme`** → `Adwaita-dark` or `Adwaita`
   - Covers legacy GTK3 apps that read this
3. **`~/.config/gtk-3.0/settings.ini`** updated with:
   ```ini
   [Settings]
   gtk-theme-name=Adwaita-dark
   gtk-application-prefer-dark-theme=1
   ```
4. **`~/.config/gtk-4.0/settings.ini`** same structure
5. **State persisted** to `~/.local/share/zen-shell/darkmode.state`
   so next shell restart knows the current mode without re-probing

### New files

- `scripts/zen-darkmode.sh` — the worker script. Accepts
  `dark`, `light`, `toggle`, `status` args.
- `zen-shell-v5/DarkModeService.qml` — QML singleton that probes
  state on load + bridges toggle/setDark to the script.

### Customize your GTK theme

By default uses `Adwaita` / `Adwaita-dark`. Override via env:

```bash
# ~/.config/environment.d/zen-gtk.conf
ZEN_GTK_DARK=Gruvbox-Material-Dark-BL
ZEN_GTK_LIGHT=Gruvbox-Material-Light-BL
```

(Requires the theme to be installed — `paru -S gruvbox-material-gtk-theme-git`
or equivalent for your pick.)

### Safe to toggle mid-session

- `zen-darkmode.sh` is idempotent. Running `dark` when already dark
  is a no-op plus fresh state write.
- `DarkModeService.setDark(bool)` updates the QML property
  optimistically (UI feels instant), then runs the script in the
  background. If the script fails, next shell restart re-probes
  actual state.

---

## Files changed from 4.6

```
NEW
  scripts/zen-terminal.sh                    ← terminal auto-detect
  scripts/zen-darkmode.sh                    ← GTK dark/light switcher
  zen-shell-v5/DarkModeService.qml           ← QML singleton
  CHANGELOG-v6.16.4.7.md                      ← this file
UPDATED
  hypr-config/keybinds-update.conf            ← $mod+T → zen-terminal.sh
  zen-shell-v5/ControlPanel.qml               ← Dark Mode toggle row
  zen-shell-v5/ZenVersion.qml                 ← bump to v6.16.4.7
  install.sh                                   ← adds the two new scripts
```

All v6.16.4.6 features carry byte-identical. Still on alpha channel.

---

## Install + verify

```bash
tar -xzf zen-shell-v6.16.4.7.tar.gz
cd zen-shell-v6.16.4.7
./install.sh
~/.local/bin/zs-restart.sh
```

### Test 1 — Super+T

```bash
# Verify script installed
ls -la ~/.local/bin/zen-terminal.sh

# Verify it detects your terminal
~/.local/bin/zen-terminal.sh --version 2>/dev/null || true
tail -5 ~/.cache/zen-shell/terminal.log
```

Press Super+T → terminal opens. If you have both alacritty and
kitty, alacritty wins. Create the config file to override:

```bash
echo "kitty" > ~/.config/zen-shell/terminal.conf
# Now Super+T opens kitty
```

### Test 2 — Dark Mode toggle

1. Super+C → Control Panel opens
2. Scroll to the row RIGHT AFTER Gaming Boost
3. Should say "🌙 Dark Mode" or "☀️ Light Mode" with a toggle
4. Click the row → mode flips
5. Open Thunar / any GTK app → should render in the new mode
6. Check state: `cat ~/.local/share/zen-shell/darkmode.state`

If the row is hidden, check: `~/.local/bin/zen-darkmode.sh status`
— if that errors, the install didn't copy the script. Re-run
`./install.sh`.

---

## Running tally

```
v6.16.4   — Panic keybind (3 bugs)
v6.16.4.1 — Panic script hotfix (LAST STABLE ON MAIN)
v6.16.4.2 — Widget scale + display resolution (incomplete)
v6.16.4.3 — Widget scale actually working + oscillation killed
v6.16.4.4 — Gaps preserved after Displays apply
v6.16.4.5 — Start Menu pinned tile breathing room
v6.16.4.6 — Wallpaper cols + WiFi Connect + ColorPicker
v6.16.4.7 — Super+T + Dark Mode toggle ← YOU'RE HERE
```
