# Zen Shell v6.16.2.3.6 — Closeout of the v6.16.2.3 hotfix series

**Release date:** 2026-04-22
**Branch:** `beta-v12.6.16.2.3.6`
**Base:** v6.16.2.3 (released 2026-04-22 morning)
**Status:** Beta — superseded all v6.16.2.3.{1..5} hotfix iterations

---

## TL;DR

This is the cumulative release of every v6.16.2.3.x hotfix that landed
during the day, plus one new fix (duplicate bar on re-install).

Things that work now:
- Clicking outside Settings / Control Panel reaches the app behind
- Music rope no longer blocks clicks above the bar
- Clock hover popup appears, scroll wheel cycles months
- Island mode survives reboot (no more revert to fullwidth)
- Avatar upload actually displays (any aspect ratio → perfect circle)
- Mouse sensitivity is in BOTH Control Panel quick toggles AND main Settings
- Default wallpaper auto-applied on fresh installs (from Gekinzen/images-demo)
- Wallpaper repo browser shows online wallpapers from your GitHub repo
- `./install.sh` no longer leaves a stack of duplicate bars

---

## NEW in v6.16.2.3.6 — Duplicate bar on re-install fix

**The bug:** Each `./install.sh` run on an existing system added another
zen-shell bar on top of the running one. After 3 installs Paul had 3
bars stacked.

**Root cause:** The end-of-install sequence was:

```bash
pkill -f 'quickshell.*zen-shell'
sleep 0.5
setsid -f quickshell -p ~/.config/quickshell/zen-shell
```

`pkill` defaults to SIGTERM. Quickshell catches SIGTERM and does a
graceful Wayland surface teardown, which can take longer than 500ms.
During the gap between "spawn new shell" and "old shell finally dies",
BOTH shells are alive — and Wayland layer-shell happily renders both
surfaces, producing visibly stacked bars.

**The fix — bulletproof kill loop with verification:**

```bash
# Phase 1 — kill loop (5 attempts, SIGTERM ×3 → SIGKILL ×2)
for attempt in 1 2 3 4 5; do
    PIDS=$(pgrep -f 'quickshell.*zen-shell' 2>/dev/null)
    [ -z "$PIDS" ] && break
    if [ "$attempt" -le 3 ]; then
        kill $PIDS 2>/dev/null      # SIGTERM
    else
        kill -9 $PIDS 2>/dev/null   # SIGKILL
    fi
    sleep 0.3
done

# Phase 2 — verify NOTHING survived before spawning
SURVIVED=$(pgrep -f 'quickshell.*zen-shell' 2>/dev/null | wc -l)
if [ "$SURVIVED" -gt 0 ]; then
    # REFUSE to spawn a duplicate
    echo "WARNING: $SURVIVED process(es) survived. Not spawning another."
    echo "Manually run: pkill -9 -f 'quickshell.*zen-shell' && quickshell -p ..."
else
    setsid -f quickshell -p "${HOME}/.config/quickshell/zen-shell" \
        </dev/null >/dev/null 2>&1
fi
```

This guarantees exactly ONE shell at end of install. If something pathological
survives SIGKILL (rare — Quickshell stuck in uninterruptible sleep), the
script REFUSES to spawn another, prints diagnostic instructions, and exits
cleanly. Better one bar + a warning than five stacked bars.

Pattern still uses `quickshell.*zen-shell` (matches running quickshell
process, NOT the install.sh script even when run from a path containing
"zen-shell" like `~/Documents/.../zen-shell-v6.16.2.3.6/`).

---

## Cumulative content (everything from .3.1 → .3.6)

### Music rope click-through (.3.1)

`shell.qml`: `mask: Region {}` on stringsWindow makes the bar's
audio-reactive overlay fully input-transparent. Browsers, editors,
file managers below the bar receive clicks normally.

### Clock hover + wheel (.3.1)

- Hover peek popup shows weekday + date + week number after 350ms
- Right-click cycles `PanelState.clockFormatIndex` through formats
- `WheelHandler` scroll wheel cycles calendar months (calendar
  opens automatically if not already open)
- Same wheel handler on the open calendar itself

### Island mode persistence (.3.1)

`PanelState.qml` emits `panelStateLoaded()` after FileView completes
its first read. `shell.qml` gates the nuclear-restart trigger on
`_shellReady` which only flips true after that signal fires (or a
2000ms fallback). Initial-load mode transitions (e.g. default-fullwidth
→ persisted-island) no longer trigger a restart cascade.

### Avatar — versioned filename + diagnostics (.3.2 → .3.6)

`UserProfileService.qml`:
- Each upload writes `~/.config/zen-shell/user-avatar-<nanosecond-ts>.<ext>`
- Bare-name symlink `user-avatar.<ext>` → versioned file (back-compat)
- `user-profile.json` records the canonical versioned path
- Old files pruned (keep 3 newest)
- Verbose `set -x` trace to `/tmp/zen-avatar-debug.log` for debugging

Detection chain: glob versioned files (newest by mtime first), then
fall back to bare names, then `.face` / AccountsService / SDDM faces.

### Avatar — OpacityMask circular render (.3.6)

The original v6.16.2.3 fragment shader silently failed on Paul's Qt
build — file loaded fine but rendered as raw square (or invisible).
v6.16.2.3.6 replaces the shader with `OpacityMask` from
`Qt5Compat.GraphicalEffects` (same module ZenStrings already uses for
`Glow`, so it's proven to work):

```qml
Image { id: src; visible: false; ...source... }
Rectangle { id: mask; radius: width/2; visible: false; color: "white" }
OpacityMask { source: src; maskSource: mask }   // ← what user sees
```

Applied in 3 places: 96px UserProfilePage preview, 72px StartMenu footer,
104px StartMenu sys-info popover. Works on every Qt 6 + Quickshell setup.

Each Image also logs `onStatusChanged` to journalctl:

```bash
journalctl --user -f | grep -E "AvatarBigImg|FooterAvatar|PopoverAvatar"
```

Status codes: 0=Null, 1=Ready, 2=Loading, 3=Error.

### Settings + Control Panel click-through (.3.2)

Both windows have `mask: Region { item: <inner panel> }` so the
transparent backdrop around the panel passes clicks through to apps
below. Removed the click-outside-close MouseArea on Control Panel —
close via ✕ button or `Super+C` toggle, matches macOS / GNOME.

### Default wallpaper + repo browser (.3.2)

- `install.sh` downloads `123824381_p0 (Edited) compressed.png` from
  `Gekinzen/images-demo/wallpapers` on fresh installs, applies via swww
- `WallpaperRepoService.qml` (new singleton) fetches the GitHub
  contents API listing, caches to `~/.cache/zen-shell/wallpapers/`
- `WallpaperPicker.qml` has an "Online" toggle that switches the grid
  to repo wallpapers, one-click download + apply

### Mouse sensitivity (.3.2 + .3.6)

`MouseSettingsService.qml` (new singleton):
- sensitivity (-1.0 to +1.0)
- scroll_factor (0.1 to 3.0)
- natural_scroll (mouse wheel)
- touchpad natural_scroll (separate)
- Live via `hyprctl keyword`, persisted to `~/.config/hypr/zen-mouse.conf`

Two UIs both bound to the same singleton:
- **Settings → INPUT & DISPLAY → Input** — full page, descriptions, hyprctl verification commands
- **Control Panel → Input tab** (`Super+C` → Expand → Input) — compact sliders

### Hyprland version tooltip (.3.2)

`StartMenuPanel.qml` sys-info popover wraps the WM row in a `ToolTip`
that shows the full branch + commit string when the text truncates.

### Device + BIOS info (.3.1)

`UserProfileService.qml` reads `/sys/class/dmi/id/{sys_vendor,product_name,
product_version,bios_vendor,bios_version,bios_date}` (no sudo — those
files are world-readable on mainstream Linux). Filters out placeholder
values (`To be filled by O.E.M.`, `Default string`, `System Product Name`,
etc.). Rows hide if every relevant field is empty.

---

## Files changed since v6.16.2.3

```
zen-shell-v5/shell.qml                     mask:Region on settings/CP/strings
                                           panelStateLoaded gate
                                           StartMenu FocusGrab suspension
zen-shell-v5/Clock.qml                     WheelHandler, right-click cycle,
                                           positionChanged fallback peek
zen-shell-v5/PanelState.qml                panelStateLoaded() signal,
                                           calendarMonthDelta property
zen-shell-v5/ZenCalendar.qml               consumes calendarMonthDelta,
                                           local WheelHandler
zen-shell-v5/UserProfileService.qml        Versioned filenames + symlink,
                                           debug logging, DMI gather,
                                           placeholder filter
zen-shell-v5/UserProfilePage.qml           OpacityMask, Device/BIOS rows
zen-shell-v5/StartMenuPanel.qml            OpacityMask × 2, uploadInProgress
                                           flag, Hyprland version tooltip,
                                           QtQuick.Controls import
zen-shell-v5/ControlPanel.qml              Input tab in tab bar
zen-shell-v5/ZenSettings.qml               InputPage registered + indices shifted
zen-shell-v5/InputPage.qml                 NEW — full mouse settings page
zen-shell-v5/MouseSettingsService.qml      NEW — hyprctl keyword writer
zen-shell-v5/WallpaperRepoService.qml      NEW — GitHub API listing fetcher
zen-shell-v5/WallpaperPicker.qml           Online toggle + unified model
hypr-config/hyprland.conf.template         source = ~/.config/hypr/zen-mouse.conf
install.sh                                 Banner v6.16.2.3.6, full changelog,
                                           default wallpaper download,
                                           zen-mouse.conf seed + injection,
                                           BULLETPROOF kill loop (no dupes)
README.md                                  NEW — project overview
HOTFIX-v6.16.2.3.6.md                      NEW — this file
```

---

## Apply

```bash
tar -xzf zen-shell-v6.16.2.3.6-complete.tar.gz
cd zen-shell-v6.16.2.3.6
./install.sh
```

Installer auto-restarts the shell at the end with the bulletproof kill
loop. After install:

```bash
# Should print 1 (not 2 or 3)
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Verify avatar pipeline
ls -la ~/.config/zen-shell/user-avatar-*

# Verify mouse settings sourced
cat ~/.config/hypr/zen-mouse.conf
```

---

## What's NOT in this release (deferred)

- Bar profile badge widget
- Widget manual + auto resize (Lenovo X270 oversized widgets fix)
- Fuzzel auto-sizing per screen DPI
- Display resolution dropdown enumeration fix
- Power confirm icons → Material Design + theme-synced
- Lid-close black screen → separate `hypr-config/` patch (hypridle/hyprlock)

These are queued for v6.16.3.

---

## Cumulative version tally

| Version | Status | Focus |
|---|---|---|
| v6.16.2 | Released | StartMenu polish |
| v6.16.2.1 | Released | Footer layout |
| v6.16.2.2 | Released | Clock sync, avatar circle, persistence |
| v6.16.2.3 | Released | Shader-mask avatar (broken), singleton calendar toggle |
| v6.16.2.3.1 | Hotfix | Music-rope click-through, clock hover/wheel, island persist |
| v6.16.2.3.2 | Hotfix | Settings/CP click-through, avatar cache, wallpaper repo, mouse |
| v6.16.2.3.3 | (skipped) | — |
| v6.16.2.3.4 | (skipped) | — |
| v6.16.2.3.5 | (skipped) | — |
| **v6.16.2.3.6** | **THIS** | **OpacityMask avatar + duplicate-bar fix + cumulative roll-up** |
| v6.16.3 (next) | Planned | Widgets resize, Fuzzel sizing, display res, power icons, lid fix |
