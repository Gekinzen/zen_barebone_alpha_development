# Zen Shell — Quickshell-native desktop for Hyprland

**Current version: v6.16.2.3.6** (beta)
**Repo branch:** `beta-v12.6.16.2.3.6`
**Author:** Paul Hansen Yuki ([Gekinzen](https://github.com/Gekinzen))

A QML desktop environment built on [Quickshell](https://quickshell.outfoxxed.me/)
for [Hyprland](https://hyprland.org/) 0.54+. Includes a configurable bar,
start menu, control panel, settings UI, system monitoring, wallpaper
manager, and audio-reactive music visualization.

---

## What v6.16.2.3.6 ships

This release closes out the v6.16.2.3 hotfix series. Everything from
.3.1 → .3.6 is rolled in, plus the duplicate-bar-on-reinstall fix:

| Area | Fix |
|---|---|
| Music rope click-through | `mask: Region {}` on stringsWindow → clicks fall through to apps below the strings overlay |
| Clock hover + wheel | Peek tooltip works (was blocked by strings overlay). Scroll wheel cycles calendar months. Right-click cycles clock formats. |
| Island mode persistence | `panelStateLoaded` signal gates nuclear restart against startup-load transient — no more revert-to-fullwidth on reboot |
| Avatar upload | Versioned filename (`user-avatar-<timestamp>.<ext>`) + bare-name symlink. Survives source-file deletion. **Diagnostic logging** to `/tmp/zen-avatar-debug.log`. |
| Avatar circular mask | `OpacityMask` from `Qt5Compat.GraphicalEffects` replaces the GLSL shader that silently failed on some Qt builds |
| Settings click-through | `mask: Region { item: zenSettingsPanel }` → desktop apps receive clicks while Settings is open |
| Control Panel click-through | Same mask pattern — file pickers, browsers, etc. all work behind the panel |
| Default wallpaper | Fresh installs download `123824381_p0` from `Gekinzen/images-demo/wallpapers` and apply via swww |
| Wallpaper repo browser | "Online" toggle in WallpaperPicker fetches Gekinzen/images-demo via GitHub API |
| Mouse sensitivity | Settings → INPUT & DISPLAY → Input + Control Panel → Input tab. Both backed by `MouseSettingsService`, persists to `~/.config/hypr/zen-mouse.conf`. |
| Hyprland version tooltip | Hover the truncated WM row in StartMenu sys-info popover → full branch/commit visible |
| Device + BIOS info | New rows in User Profile sourced from `/sys/class/dmi/id` (no sudo). Placeholder strings filtered. |
| **install.sh duplicate-bar fix** | **Bulletproof kill loop with SIGKILL escalation + verify-then-spawn. Refuses to spawn a duplicate if anything survives.** |

---

## Install

### Quick

```bash
tar -xzf zen-shell-v6.16.2.3.6-complete.tar.gz
cd zen-shell-v6.16.2.3.6
./install.sh
```

`install.sh` auto-detects whether bootstrap is needed (missing
Hyprland / Quickshell / grim / slurp / wl-copy / swww / cava /
playerctl / jq / notify-send), runs bootstrap if any are missing,
then installs. At the end, kills any existing zen-shell process
and spawns exactly ONE new instance.

### Verify after install

```bash
# Should print 1
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Watch avatar uploads
tail -f /tmp/zen-avatar-debug.log
```

---

## Keybinds (defaults)

```
Super+A          Start menu
Super+,          Settings
Super+C          Control Panel (quick toggles)
Super+W          Wallpaper picker
Super+/          Keybind cheatsheet
Super+SHIFT+S    Screenshot rope (region capture with annotation)
```

---

## Project structure

```
zen-shell-v6.16.2.3.6/
├── install.sh              Smart installer (auto-detects bootstrap need)
├── bootstrap.sh            One-time system setup (deps via paru)
├── zen-shell-v5/           QML files for Quickshell
│   ├── shell.qml           Root shell (windows + IPC handlers)
│   ├── Bar.qml             The status bar
│   ├── ControlPanel.qml    Quick-toggles popup (Super+C)
│   ├── ZenSettings.qml     Full settings UI (Super+,)
│   ├── StartMenuPanel.qml  App launcher (Super+A)
│   ├── WallpaperPicker.qml Wallpaper grid + Online repo tab
│   ├── *Service.qml        Singleton state services
│   └── *Page.qml           Settings page components
├── hypr-config/            Hyprland config modules + template
├── scripts/                Helper scripts (zs-restart.sh, etc.)
├── themes-builtin/         Pre-installed theme JSON files
├── bin/                    Toggle scripts copied to ~/.local/bin
├── HOTFIX-v6.16.2.3.6.md   Detailed changelog for THIS release
└── CHANGELOG-v6.15.*.md    Historical release notes
```

---

## Locations & state files

| Path | Purpose |
|---|---|
| `~/.config/quickshell/zen-shell/` | All QML files |
| `~/.config/zen-shell/user-avatar-*.png` | Versioned uploaded avatars |
| `~/.config/zen-shell/wallpapers/` | Local wallpaper folder |
| `~/.config/zen-shell/user-profile.json` | Avatar override JSON |
| `~/.config/hypr/zen-mouse.conf` | Mouse sensitivity (sourced by hyprland.conf) |
| `~/.config/quickshell/zen-shell/panel-state.json` | Panel mode, bar layout, etc. |
| `~/.config/quickshell/zen-shell/wallpaper-state.json` | Current wallpaper path |
| `~/.cache/zen-shell/wallpapers/listing.json` | Cached GitHub API repo listing |
| `~/.local/bin/zs-restart.sh` | Restart helper (used by nuclear-restart logic) |
| `/tmp/zen-avatar-debug.log` | Avatar upload diagnostic trace |
| `/tmp/zs-restart.log` | Restart helper trace |

---

## Diagnostic commands

```bash
# What zen-shell processes are running?
pgrep -fa 'quickshell.*zen-shell'

# What did the last avatar upload do?
tail -50 /tmp/zen-avatar-debug.log

# What did the last nuclear restart do?
tail -50 /tmp/zs-restart.log

# Live shell logs (errors, warnings, console.log output)
journalctl --user -f -t quickshell

# Avatar Image status (after install — will show file load errors if any)
journalctl --user -f | grep -E "AvatarBigImg|FooterAvatar|PopoverAvatar"

# Verify current mouse settings reached Hyprland
hyprctl getoption input:sensitivity
hyprctl getoption input:scroll_factor
hyprctl getoption input:natural_scroll
```

---

## Re-install (replace running shell cleanly)

The installer's end-of-install launch sequence (v6.16.2.3.6+):

1. Lists all existing `quickshell.*zen-shell` processes
2. SIGTERM × 3 rounds (300ms apart) — graceful shutdown chance
3. SIGKILL × 2 rounds — forced termination
4. **Verifies** nothing survived. If anything did, REFUSES to spawn another.
5. `setsid -f quickshell -p ~/.config/quickshell/zen-shell`

Result: exactly ONE shell, every time. No more stacked duplicate bars.

---

## Known caveats

- **Quickshell version**: Tested on Quickshell built from master near
  Hyprland 0.54.x. Older Quickshell may not support `mask: Region` —
  if Settings/Control Panel still blocks click-through, update Quickshell.
- **GitHub API rate limit**: Wallpaper repo browser uses unauthenticated
  GitHub API (60 req/hr per IP). The cached listing means normal use
  never hits this.
- **DMI sysfs**: Device / BIOS rows in User Profile read from
  `/sys/class/dmi/id/*`. On VMs / containers / WSL these files may be
  empty or contain placeholder strings — the rows hide automatically.

---

## License

Personal project by Paul Hansen Yuki. No license attached at the moment;
contact Paul (`paulyuki.com`) before redistributing.
