# CHANGELOG — v6.16.4.12.6 "Hikari · Frosted"

**Released:** 2026-04-28
**Branch:** `main` (continuing the Hikari v4.12 series)
**Author:** Paul Hansen Yuki ([Gekinzen](https://github.com/Gekinzen))

This is a polish + opt-in features release on top of v6.16.4.12.5. No
new model jump (still Hikari · 光). No removals — wala tayo babawasan.

> **v6.16.4.12.6.1 hotfix appended at bottom** — Clock CPU/RAM moved to
> the live `Clock.qml` calPopup (was wrongly in dead `ZenClock.qml`),
> matugen empty-output now self-diagnoses via `/tmp/zen-matugen.log`,
> editable Palette Editor migrated to Themes page (was claimed in
> v6.16.4.11.2 changelog but never actually shipped).

---

## At a glance

| Area | Change |
|---|---|
| **Bar modules** | Music / Tray / Notification / PowerBadge / Taskbar backgrounds now read as part of the frosted bar instead of solid embedded pills. Hyprland's existing `layerrule = blur on, ignore_alpha 0.5, match:namespace zen-shell-bar` finally has surfaces it can blur through. |
| **Start menu** | Root panel alpha 0.92 → 0.72 + footer rebound to ThemeService. Live theme switches (and the new Matugen) repaint the footer instantly. |
| **Taskbar close** | Graceful `requestClose()` first, then a 250 ms watchdog runs `pkill -f -- <appId>` followed by `pkill -9 -f -- <appId>`. Stuck Electron / Lark windows can no longer ignore a close request indefinitely. Per-window X (single window) keeps graceful-only — pkill -f appId would also kill sibling windows. |
| **Clock hover** | Hover popup now appends a CPU / RAM / GPU stats row (live from `SystemMonitorService`, repaints every 2 s). GPU column self-hides on systems where `gpuName` hasn't been detected. |
| **Matugen toggle** | New opt-in feature: when ON, every wallpaper switch regenerates the theme from its dominant colors via `matugen image <path> --json hex`. When OFF, your selected theme stays untouched. Toggle lives at Settings → Themes → Matugen. |

---

## Files touched (drop-in replacements)

```
zen-shell-v5/
├── MusicWidget.qml         frosted bg, ThemeService bindings
├── SystemTray.qml          frosted bg, ThemeService bindings
├── NotificationIcon.qml    frosted bg, ThemeService bindings
├── PowerBadge.qml          frosted bg (right-side consistency)
├── Taskbar.qml             frosted bg + pkill watchdog close path
├── StartMenuPanel.qml      root alpha 0.92→0.72, footer rebound
├── ZenClock.qml            CPU/RAM/GPU rows in hover popup
├── ThemeService.qml        matugen plumbing (probe + apply + persist)
├── ThemesPage.qml          matugen toggle SettingsSection + status
└── shell.qml               WallpaperServiceV5 → matugen Connections hook

scripts/
└── zen-matugen-bootstrap.sh   (NEW) idempotent matugen config bootstrap

install.sh                  3 inserts (additive):
                            ─ [1/9] check_cmd matugen matugen-bin
                            ─ [5/9] zen-matugen-bootstrap.sh added to copy loop
                            ─ [8/9] smart-detect auto-runs bootstrap on first install
```

---

## Bar modules — the alpha math

The bar surface paints its own background at `Theme.barOpacity = 0.50`
across the whole bar. Modules paint their fills on top using QML
Source-Over blending, so the final per-pixel alpha at a module is:

```
A_final = A_module + A_bar * (1 - A_module)
```

Old modules at A_module = 0.90:  0.90 + 0.50 * 0.10 = **0.95** (effectively solid)
New modules at A_module = 0.32:  0.32 + 0.50 * 0.68 = **0.66** (above ignore_alpha 0.5 → blur applies)

So we get the frosted look without breaking Hyprland's blur threshold.
The inner 1px highlight rectangle on each module catches the top edge
for a subtle glass-pane depth cue.

If the modules look TOO see-through on your wallpaper, bump the alpha
in each module from `0.32` to `0.40`. Above ~0.55 you start losing the
frost effect again.

---

## Taskbar close — graceful then pkill

```
left-click "Close all"
    │
    ▼
safeCloseAll(appId)
    │
    ├─► safeClose(toplevel) for each window
    │       requestClose()  ──► well-behaved app shows "Save?" dialog
    │       (or close() / hyprctl fallback)
    │
    └─► pkillWatchdog: 250 ms timer
            │
            ▼
        pkillByAppId(appId)
            pkill -f -- <appId>      (graceful kill)
            sleep 0.2
            pkill -9 -f -- <appId>   (force if still alive)
```

**appId is sanitized** before reaching bash — only `[a-zA-Z0-9_\-\.]`
allowed, anything else stripped. Can't escape into the command line.

**Caveat to know about:** `pkill -f appId` matches the FULL command
line, not just the basename. If you have a kitty window named `kitty`
(appId), it'll also nuke any background `kitty -e <some script>` you
have running — including tmux launchers spawned from your dotfiles. If
this bites you, `safeCloseAll` can be swapped to PID-from-`hyprctl
clients -j` matching, which is surgical at the cost of one extra
subprocess. Mention pre and we'll switch.

**Per-window X button** in the popup keeps just the graceful path —
`pkill -f appId` would kill sibling windows of the same app.

---

## Clock hover — live stats

```
┌────────────────────────────────┐
│        Tuesday                 │
│      April 28, 2026            │
│        1:47:06 AM              │
│  ─────────────────────         │
│  Week 18 · Day 118 of 2026     │
│  Asia/Manila · UTC+08:00       │
│  ─────────────────────         │
│   CPU      RAM      GPU        │
│   12%      34%      8%         │
│   42°C   24/128 GB  47°C       │
│  ─────────────────────         │
│      Click for calendar        │
└────────────────────────────────┘
```

Stats bind to `SystemMonitorService.{cpuPercent,cpuTemp,ramPercent,ramUsedGb,
ramTotalGb,gpuUsage,gpuTemp,gpuName}`. The singleton already polls every 2 s —
the popup is a free passenger on that timer.

GPU column hides when `gpuName === "GPU"` (placeholder = no detection)
so VMs / headless boxes don't get a bogus 0% / 0°C row.

Color thresholds: green ≤ 50%, yellow 50–80%, red > 80% (RAM uses 65 / 85).

---

## Matugen — wallpaper-driven theming

### Setup

```bash
./install.sh
```

That's it. install.sh now handles matugen end-to-end:

1. **[1/9] Dependency check** offers `matugen-bin` alongside the other
   optional packages. Picks `paru` → `yay` → `pacman` (whichever is
   installed first). Uses `--needed` so re-runs are no-ops if matugen
   is already present.
2. **[5/9] Install scripts** copies `zen-matugen-bootstrap.sh` to
   `~/.local/bin/`.
3. **[8/9] First-run tasks** smart-detects: if `matugen` is now on
   PATH AND `~/.config/matugen/config.toml` doesn't exist, runs the
   bootstrap automatically. Otherwise prints "matugen detected" and
   moves on. **Idempotent** — re-installs don't overwrite your config.

If you skipped matugen at the [1/9] prompt and want to add it later:

```bash
paru -S --needed matugen-bin
~/.local/bin/zen-matugen-bootstrap.sh
```

### How it works

1. Toggle ON via Settings → Themes → Matugen. State persisted at
   `~/.config/hypr-control-center/matugen.state`.
2. `shell.qml` listens for `WallpaperServiceV5.wallpaperApplied(path)`.
3. When fired AND toggle is ON, calls
   `ThemeService.applyMatugenFromWallpaper(path)`.
4. That runs `matugen image <path> --json hex` and parses stdout.
5. Material You tokens get mapped to Zen's palette:

   | Zen token | M3 token (with fallbacks) |
   |---|---|
   | `bg0` | `surface_dim` → `surfaceDim` → `background` |
   | `bg1` | `surface` → `background` |
   | `bg2` | `surface_container` → `surfaceContainer` → `surface_variant` |
   | `bg3` | `surface_container_high` → `surfaceContainerHigh` |
   | `bg4` | `surface_container_highest` → `surfaceContainerHighest` |
   | `fg`  | `on_surface` → `onSurface` → `on_background` |
   | `grey0` | `on_surface_variant` → `outline` |
   | `grey1` | `outline` → `on_surface_variant` |
   | `grey2` | `outline_variant` → `outlineVariant` |
   | `blue` | `primary` |
   | `purple` | `secondary` |
   | `aqua` | `tertiary` |
   | `green` | `primary_container` |
   | `yellow` | `tertiary_container` → `secondary_container` |
   | `orange` | `secondary_container` → `tertiary` |
   | `red` | `error` |

   Fallbacks are walked in order so we work across matugen 1.x (snake_case)
   and 2.x (camelCase) output formats.

6. Result written to `~/.config/hypr-control-center/themes/custom/
   matugen-auto.json`, then applied through the normal `applyTheme()`
   path — terminal regen, swaync regen, and shell-reload all fire as
   if you'd picked the theme from the dropdown.

### Re-apply now button

If a wallpaper is already set when you flip the toggle ON, hit
**Re-apply now** in the Themes page to generate immediately without
having to switch wallpapers first.

### Turning OFF

Flip the toggle back. `matugen-auto.json` stays on disk (you can
re-apply it from the Themes dropdown anytime). Pick another theme
from the dropdown to leave Matugen-land.

### When matugen isn't installed

The toggle is disabled and shows: *"matugen binary not detected.
Install with: paru -S matugen-bin"*. Shell continues booting normally
— matugen is opt-in, not required.

---

## Known caveats

- **Matugen accent mapping is approximate.** Material You's primary/secondary/
  tertiary doesn't map cleanly to Tokyo Night-style 8-color palettes. Some
  wallpapers will produce muddy accents (especially low-saturation photos).
  Tune the mapping in `ThemeService._writeMatugenTheme()` if you want
  different priorities — it's a single function with explicit fallback
  arrays, easy to swap.
- **pkill -f appId** is full-command-line match. See the Taskbar close
  caveat above. If you tmux-via-kitty heavily, watch out. PID-based
  switch is a 10-line change away if needed.
- **Frosted alpha** assumes Hyprland's blur passes are configured. If
  you've set `blur:enabled = false` in `decoration {}`, the modules
  will look transparent (no frost). Re-enable blur, or bump module
  alpha back up to 0.55–0.65 to fall back to a tinted-glass look
  without compositor blur.

---

## Reset paths

If matugen produces a theme you hate and you want to bail:

```bash
# Pick a built-in
qs -c zen-shell ipc call zen reloadThemeFromFile   # (no-op force-reload)
# Or via Settings UI: Settings → Themes → Switch Theme dropdown

# Clear the matugen state file
echo 0 > ~/.config/hypr-control-center/matugen.state

# Optionally delete the auto-generated theme
rm ~/.config/hypr-control-center/themes/custom/matugen-auto.json
```

---

## Diagnostic commands

```bash
# Did matugen probe succeed?
cat ~/.config/hypr-control-center/matugen.state    # 1 = ON, 0 = OFF
command -v matugen                                  # path or empty

# What does matugen actually output for your current wallpaper?
matugen image "$(jq -r .currentWallpaper ~/.config/quickshell/zen-shell/wallpaper-v5.json)" --json hex | jq .

# What's the current generated theme?
cat ~/.config/hypr-control-center/themes/custom/matugen-auto.json | jq .colors

# Live shell logs — look for [Matugen] lines
journalctl --user -f -t quickshell | grep -i matugen
```

---

## v6.16.4.12.6.1 hotfix (2026-04-28)

Three issues caught during Paul's first install of v6.16.4.12.6.

### Clock CPU/RAM/GPU stats

**Bug:** Hover over the bar clock showed the calendar/notifs popup but no
system stats. CPU/RAM additions had been written to `ZenClock.qml`, which
is dead code — `Bar.qml` instantiates `Clock { }`, the live 656-line file
that holds the v6.16.4.12.4 calPopup.

**Fix:** New CPU/RAM/GPU stats strip injected into `Clock.qml`'s `calPopup`,
between the day grid and the system quick-action icons. Three pills, each
bordered, with label / value / sub-line (temp or GB used). Color-coded
thresholds (green ≤50%, yellow 50–80%, red >80%; RAM uses 65/85). GPU
pill auto-hides when `SystemMonitorService.gpuName === "GPU"` (placeholder).
calPopup height bumped 590 → 660. ZenClock.qml reverted to the v6.16.4.12.5
original — zero changes.

### Matugen "empty output" was unhelpful

**Bug:** `applyMatugenFromWallpaper()` redirected stderr to `/dev/null`,
so when matugen failed (CLI flag mismatch / config issue / template
error) the status banner just said "matugen returned empty output". No
way to diagnose.

**Fix:** New robust call chain in `ThemeService.applyMatugenFromWallpaper()`:

1. stderr now goes to `/tmp/zen-matugen.log` (was `/dev/null`)
2. Tries four flag variants in order, takes first non-empty stdout:
   - `--json hex` (matugen 2.x with config)
   - `--json hex --dry-run` (matugen 2.x without templates)
   - `--show-colors --json hex` (some 2.x builds)
   - `--json` (older 1.x bare)
3. New `matugenLogReader` Process — when all variants fail, reads tail of
   the log, strips marker lines, surfaces matugen's actual error in the
   status banner (truncated to 220 chars + log path).

Next failure now reads like *"matugen failed — Error: no \[config] section
in config.toml | hint: matugen --help (full log: /tmp/zen-matugen.log)"*
instead of a generic empty-output complaint.

### Editable Palette migrated to Themes page

**Bug:** v6.16.4.11.2 changelog claimed the Theme Palette had moved from
General → Themes ("single source of truth for palette edits"). Reality:
General page still showed the editable HMSection with `ColorSwatch`
widgets, Themes page only showed read-only `Rectangle` swatches. Two
sources of truth, opposite of what the changelog promised.

**Fix:**

- **GeneralPage.qml** — Theme Palette HMSection wrapped with
  `visible: false`. Code preserved verbatim for rollback safety. Wala
  tayo babawasan — flip `visible: true` to restore.
- **ThemesPage.qml** — "Palette Preview" section renamed to "Palette
  Editor". Each 60×60 swatch is now clickable: hover shows a pencil
  glyph + blue border accent, click opens a hex-input Popup positioned
  below the swatch. Apply calls `ThemeService.setAccent(key, hex)` for
  live preview and flips `palettedDirty`. New "Save edits as custom
  profile" row at the bottom — name field (optional) + Save button
  (disabled until edits exist), wires through the existing
  `ThemeService.saveAsCustomTheme()` cascade.

Now Themes page is the single source of truth, exactly what the
v6.16.4.11.2 changelog originally promised.

### Files touched in 12.6.1

```
zen-shell-v5/
├── Clock.qml          NEW: CPU/RAM/GPU stats strip in calPopup; height 590→660
├── ZenClock.qml       REVERTED to v6.16.4.12.5 original (was dead code anyway)
├── ThemeService.qml   matugen robustness: stderr capture, 4-variant fallback,
│                      log reader for diagnostic surfacing
├── ThemesPage.qml     "Palette Preview" → "Palette Editor" with clickable swatches +
│                      hex Popup + Save-as-profile row
└── GeneralPage.qml    Theme Palette HMSection wrapped visible: false (preserved)
```

### Diagnostic for next matugen failure

```bash
tail -200 /tmp/zen-matugen.log
```

The log shows each tried variant + matugen's actual stderr output for each.
Paste back to me and I'll lock in the right flag for a v6.16.4.12.6.2.
