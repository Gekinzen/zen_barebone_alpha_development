# Zen Shell v6.15 — Changelog

**Release date:** 2026-04-19
**Base:** v6.14 (clean) + v6.14.2 screenshotRope carried forward
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

---

## ⚠ Hyprland 0.54+ — Build Environment

Starting with v6.15, Zen Shell is built and tested against
**Hyprland 0.54**. Users on earlier versions should update, or pin
hyprland in pacman before running install.sh.

Syntax changes enforced by 0.53/0.54 that are already in this release:

| Old (≤0.52) | New (0.54+) | Status |
|---|---|---|
| `windowrulev2 = ...` | `windowrule = prop val, match:key regex` | ✅ fixed |
| `layerrule = blur, ns` | `layerrule = blur on, match:namespace ns` | ✅ fixed |
| `layerrule = ignorezero` | (removed — use ignore_alpha) | ✅ removed |
| `layerrule = noanim, ns` | `layerrule = no_anim on, match:namespace ns` | ✅ fixed in v6.15 |
| `bind = X, exec, foo,` (trailing comma) | `bind = X, exec, foo` | ✅ fixed in v6.15 |
| `idleinhibit` windowrule | (removed — use hypridle) | N/A — not used |

---

## What's New — Music Module → ZenStrings

### Overview

The `music` bar module is now toggleable as an audio-reactive string
visualizer. When enabled via Settings → General → Strings, the music
widget is replaced by `MusicStrings` — a transparent placeholder that
renders `ZenStrings` as a **floating PanelWindow** positioned over the
music slot, with extra vertical padding so beat-reactive curves bow
above and below the bar freely without being clipped.

---

## New Files

### `MusicStrings.qml`
Drop-in replacement for `MusicWidget` in the bar slot.
- Transparent — no background, floats inside bar
- Polls `playerctl status` every 2s for play state
- Polls `playerctl metadata` for artist + title
- Runs `zen-cava.sh` for beat data, restarts on exit
- Writes `isAudioActive` + `cavaData` to `ZenStringsState`
- Hover → `PopupWindow` tooltip (same pattern as `SysRowIcon.qml`)
  - Green dot + `Artist — Title` when playing
  - Grey dot when paused/stopped

### `zen-cava.sh` (scripts/)
Bundled cava wrapper. Generates a minimal cava config on the fly:
```
[general]    bars = <segments>  framerate = 60
[input]      method = pulse     source = auto
[output]     method = raw       raw_target = /dev/stdout
             data_format = ascii  ascii_max_range = 1000
             bar_delimiter = 59   frame_delimiter = 10
```

### `bootstrap.sh` (root)
**NEW in v6.15** — installs Hyprland + Quickshell + all dependencies
on a fresh Arch-based laptop (CachyOS / Arch / EndeavourOS / Manjaro).
Safe to run on systems currently running **KDE / GNOME / COSMIC** —
does NOT touch the display manager, does NOT change the default
session, does NOT remove any existing DE.

Installs in 4 tiers:
- **Tier 1** (Core): hyprland, quickshell-git, jq, xdg-desktop-portal-hyprland, polkit-gnome, qt6 stack
- **Tier 2** (System): pipewire, wireplumber, NetworkManager, bluez (skipped if present)
- **Tier 3** (Zen Shell): swww, swaync, fuzzel, cava, playerctl, grim, slurp, alacritty, thunar, pavucontrol, blueman, nwg-displays, nwg-look, bottom, libnotify
- **Tier 4** (Fonts): JetBrains Mono Nerd, Font Awesome, Noto, Papirus icons

Creates `/usr/share/wayland-sessions/hyprland.desktop` if missing so
Hyprland becomes selectable from the **existing** login screen.
Writes minimal `~/.config/hypr/hyprland.conf` only if none exists.

Usage:
```bash
./install.sh --bootstrap    # fresh laptop mode
./install.sh                # normal mode (Hyprland already installed)
```

---

## Modified Files

### `Bar.qml` — v6.15

**Position tracking rewrite:**

Previous implementation used `onXChanged` / `onWidthChanged` on
`musicSlotItem` — pero yung Item nested sa `Loader → Repeater delegate
→ RowLayout`, so its `x` within its own Loader parent is always 0,
at yung `width` only changes once when the inner module loads. Listeners
never fire kahit nag-rearrange yung layout. Bug: strings published
position (0, 0) kaagad → nag-a-appear sa far-left ng screen.

**v6.15 fix** listens to the signals that ACTUALLY fire when layout
changes:
- `Connections { target: innerLoader }` → `onItemChanged` +
  `onWidthChanged` + `onHeightChanged`
- `Connections { target: barRoot }` → `onWidthChanged` +
  `onContentImplicitWidthChanged`
- `Connections { target: ZenStringsState }` → `onEnabledChanged` +
  `onStringLengthChanged`
- Multi-stage settle Timer (500ms × 5 = 2.5s) to catch late-loading
  modules (cava boot, taskbar apps appearing)

### `ZenStrings.qml` — v6.15
- Root changed from `Rectangle` to `Item` — no background, no clip
- Added `slotCenterY` property — Y of the bar slot center within the
  ZenStrings item. Passed from shell.qml for correct curve alignment.
- Added `"theme"` color mode: auto `ThemeService.blue` → `ThemeService.purple`

### `ZenStringsState.qml` — v6.15
Simplified singleton. Removed v6.14.2 wing/position props.

**Removed:** `mode`, `leftEnabled`, `rightEnabled`, `leftAudioVisual`,
`rightAudioVisual`, `position`, `barPosition`

**Added:**
```
isAudioActive         bool    written by MusicStrings
cavaData              var     beat array from cava
musicSlotLocalX       real    bar-local X of music slot (from Bar.qml)
musicSlotLocalWidth   real    width of music slot
barWindowLeft         real    bar window left in screen coords (mode-aware)
colorMode             string  "theme" | "synced" | "custom"  (default: "theme")
verticalPadding       int     overflow px above/below bar slot (0 = auto)
```

### `shell.qml` — v6.15

**ZenStrings now in dedicated floating PanelWindow** (instead of
sibling of Bar inside barWindow). Reason: barWindow is a Wayland
layer-shell surface with fixed height, at anything drawn outside that
surface gets hard-clipped by Wayland. Beat curves that bowed above
the bar were napuputol.

The new `stringsWindow`:
- `WlrLayer.Overlay` (above bar)
- `exclusionMode: ExclusionMode.Ignore` (doesn't push other content)
- Namespace: `zen-shell-strings`
- Height = `barHeight + 2 × vPad` — curves bow freely above and
  below the bar slot
- Width = `musicSlotLocalWidth`
- Margins: positioned using `barWindowLeft + musicSlotLocalX` so
  alignment works correctly in fullwidth / floating / island modes
- `_publishBarLeft()` helper on barWindow writes the bar's left
  edge in screen coords to `ZenStringsState.barWindowLeft` on mode
  change and width change

**Screenshot rope — monitor-follow-cursor fix:**

Previous implementation used `Hyprland.focusedMonitor.name` in a live
binding. Timing issue: when pressing `Super+Shift+S`, Hyprland fires
the exec dispatch immediately, pero yung focusedMonitor property
baka hindi pa na-update to reflect where the cursor is NOW. Resulta:
screenshot rope appeared sa stale monitor, hindi sa monitor kung saan
si cursor.

**v6.15 fix:**
- New Process `cursorMonitorQuery` actively queries `hyprctl -j
  monitors` at trigger time to get the currently-focused monitor
- IPC handler `zenScreenshotRope()` triggers the Process instead
  of setting visible directly
- Process stdout handler sets `screenshotRopeTargetMonitor` and
  THEN sets `screenshotRopeVisible = true`
- screenshotRopeWindow's `isTargetMonitor` checks against
  `screenshotRopeTargetMonitor` (fresh, accurate)

### `GeneralPage.qml` — v6.15
New **Strings** section added (before Footer):

| Setting | Default | Description |
|---|---|---|
| Enable strings | off | Replaces music module with ZenStrings |
| Stroke width | 4px | Bezier line thickness |
| String length | 0 | 0 = fill slot width, >0 = fixed px |
| Curve height | 60px | Beat bow amplitude |
| Vertical padding | 0 | Overflow above/below bar (0 = auto) |
| Glow | on | Soft glow around string lines |
| Color | theme | theme / synced / custom |
| Start/End color | — | Shown when synced or custom |
| Screenshot ropes | on | Physics ropes during region screenshot |

### `ZenScreenshotOverlay.qml` — v6.15
- Added `"theme"` branch to `color1`/`color2` resolution
  (matches ZenStrings color mode handling)

### `hyprland-layer-rules.conf` — v6.15
- Added `layerrule = no_anim on, match:namespace zen-shell-strings`
  — uses Hyprland 0.54+ syntax (`no_anim on` not `noanim`)

### `keybinds-update.conf` — v6.15
**Keybind remap for screenshot rope:**
- `SUPER SHIFT + S` → screenshot rope (was `toggleStyle`)
- `SUPER ALT + S` → toggleStyle (moved from SHIFT)

Reason: user reported `SUPER SHIFT + S` conflict — the old bind was
toggleStyle, overriding the intended screenshot rope trigger.

### `binds.conf` — v6.15
- Removed trailing comma from `ALT, TAB, cyclenext` (Hyprland 0.54
  stricter about trailing commas — could warn or fail silently)

### `install.sh` — v6.15

**New features:**
- `--bootstrap` / `-b` flag → runs bootstrap.sh first then exits
- `--help` / `-h` flag → prints usage
- Better error message when required deps missing — suggests
  `--bootstrap` mode on Arch-based systems
- Preserves v6.14 verbose style: detailed pre-flight, install summary,
  Fixed in / New in sections, Quick test checklist

Full flow preserved: Pre-flight → Deps → Backup → Directories → QML
→ Scripts → Hypr configs → Themes → First-run → Restart → Summary.

---

## Behavior

| State | String |
|---|---|
| `enabled = false` | Normal `MusicWidget` loads |
| `enabled = true`, nothing playing | Static line + dots (decorative) |
| `enabled = true`, music playing + cava | Animated bezier curves reacting to beat |
| Hover | `PopupWindow` tooltip: dot + `Artist — Title` |

---

## Architecture

```
shell.qml
├── barWindow (WlrLayer.Top, namespace zen-shell-bar)
│   └── Bar.qml
│       └── cMusic (Component) → Item musicSlotItem
│           └── Loader
│               ├── MusicWidget.qml   (when strings disabled)
│               └── MusicStrings.qml  (when strings enabled)
│                   ├── playerctl poll (2s)
│                   ├── zen-cava.sh process
│                   ├── writes isAudioActive + cavaData → ZenStringsState
│                   └── PopupWindow tooltip on hover
│
└── stringsWindow (WlrLayer.Overlay, namespace zen-shell-strings)
    └── ZenStrings.qml — renders the curves
        x = barWindowLeft + musicSlotLocalX
        width = musicSlotLocalWidth
        height = barHeight + 2 × verticalPadding
```

---

## Keybinds

| Keybind | Action |
|---|---|
| `Super+,` | Settings → General → Strings |
| `Super+C` | Control Panel |
| `Super+W` | Wallpaper |
| `Super+A` | Start menu |
| `Super+/` | Keybind cheatsheet |
| `Super+Shift+S` | **Screenshot rope overlay** (new in v6.15) |
| `Super+Alt+S` | Toggle style (round ↔ pill) — moved from Shift+S |

---

## Requirements

| Dependency | Purpose | Required? |
|---|---|---|
| Hyprland 0.54+ | Compositor | **Yes** |
| Quickshell 0.2.1+ | Shell runtime | **Yes** |
| jq | JSON parsing | **Yes** |
| `cava` | Beat-reactive animation | Optional (static mode without it) |
| `playerctl` | Play state + track metadata | Optional |
| MPRIS-compatible player | Spotify, Rhythmbox, mpd, etc. | Optional |

Fresh laptop? `./install.sh --bootstrap` handles all of these + more.

---

## Migration from v6.14.2

`strings-state.json` auto-migrated by `install.sh`:
- Removes: `mode`, `leftEnabled`, `rightEnabled`, `leftAudioVisual`,
  `rightAudioVisual`, `position`, `barPosition`
- `colorMode`: reset to `"theme"` (unless was `"synced"` — preserved)
- `stringLength`: defaults to `0` if missing

---

## Install

```bash
tar -xzf zen-shell-v6_15-complete.tar.gz
cd zen-shell-v6.15

# Fresh Arch-based laptop (KDE/GNOME/COSMIC safe):
./install.sh --bootstrap

# Hyprland already running:
./install.sh
```

---

## Test checklist

- [ ] Super+, → General → Strings → Enable → music slot becomes a string
- [ ] String aligns inside the music slot (not far-left)
- [ ] Play music → curves bow above AND below bar without being clipped
- [ ] Hover → Artist — Title tooltip pops above the string
- [ ] Pause → string returns to static line
- [ ] Super+Shift+S → screenshot rope appears on the monitor where cursor is
- [ ] Move cursor to 2nd monitor → Super+Shift+S appears on 2nd monitor
- [ ] Super+Alt+S → bar style toggles (round ↔ pill)
- [ ] `hyprctl reload` → no layerrule / windowrule errors in notification
- [ ] `tail /tmp/zen-shell.log` → no QML warnings about noanim / invalid field

---

*WALA TAYONG BABAWASAN — all v6.14 and v6.14.2 modules carried forward.*
