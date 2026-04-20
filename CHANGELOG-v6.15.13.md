# Zen Shell v6.15.x — Consolidated Changelog

**Release window:** 2026-04-19 → 2026-04-20
**Base:** v6.14.2 (clean)
**Current version:** **v6.15.13** (fresh-install and upgrade ready)
**Built & tested on:** **Hyprland 0.54+** (Arch Linux / CachyOS)
**Quickshell:** v0.2.1+

This is the rolled-up changelog covering the entire v6.15 patch
series. Individual per-patch changelogs are preserved in this
repository as `CHANGELOG-v6.15.md` and `CHANGELOG-v6.15.<n>.md` for
historical reference.

---

## Highlights

The v6.15 series introduced the **Strings music module + screenshot
ropes** (heavily inspired by
[flickowoa's Hyprland Zephyr dotfiles](https://github.com/flickowoa/dotfiles/tree/hyprland-zephyr) —
[demo video](https://www.youtube.com/watch?v=7Miis9I25q4)) and
produced a long tail of patch releases (v6.15.1 → v6.15.13) hardening
the feature across every layout edge case, fixing a separate
theme-change-wipes-settings bug, and finally adding a selective shell
respawn mechanism for the one corner case Qt's layout engine couldn't
solve on its own.

**Scope added over v6.14.2:**
- Audio-reactive bezier music-string visualizer replacing the music
  module (toggleable in Settings → General → Strings)
- Screenshot region overlay with physics-simulated rope ornaments
  from the screen corners, clipboard-integrated capture
- Hyprland 0.54+ syntax fixes across all bundled config
- `--bootstrap` flag on `install.sh` for fresh-laptop setup (safe
  to run on systems currently running KDE / GNOME / COSMIC)
- Complete `SettingsStateV2.applyToHyprland()` coverage — ~20
  previously-omitted keywords now actually persist
- Nuclear-restart helper script for the one layout edge case that
  QML-level fixes couldn't solve

---

## v6.15 — Music Module → ZenStrings (2026-04-19)

The flagship feature of the series. The `music` bar module becomes
toggleable as an audio-reactive visualizer. When enabled, a
transparent `MusicStrings` placeholder replaces `MusicWidget` in the
bar, and a dedicated floating `PanelWindow` (`stringsWindow`) renders
bezier curves that react to beat data from `cava`.

**Architecture:**
```
shell.qml
├── barWindow (WlrLayer.Top, namespace zen-shell-bar)
│   └── Bar.qml
│       └── cMusic Component → musicSlotItem
│           └── Loader
│               └── MusicStrings.qml (when strings enabled)
│                   ├── playerctl polling (2s)
│                   ├── zen-cava.sh process
│                   ├── ZenStringsState.isAudioActive / cavaData
│                   └── Hover tooltip: Artist — Title
│
└── stringsWindow (WlrLayer.Overlay, namespace zen-shell-strings)
    └── ZenStrings.qml
        margins.left = barWindowLeft + musicSlotLocalX
        implicitWidth = musicSlotLocalWidth
        implicitHeight = barHeight + 2 × verticalPadding  ← curves bow above/below
```

**New files shipped:**
- `MusicStrings.qml` — bar slot placeholder + cava process manager
- `ZenStrings.qml` — the visualizer itself (replaces `Rectangle` with `Item` — no background)
- `ZenStringsState.qml` — singleton holding runtime state
- `bootstrap.sh` — fresh-laptop dependency installer (Hyprland +
  Quickshell + pipewire + network stack + fonts)
- `scripts/zen-cava.sh` — cava wrapper generating minimal config on
  the fly

**New settings (Settings → General → Strings):**
Enable strings, stroke width, string length, curve height, vertical
padding, glow, color mode (theme / synced / custom), start/end color
pickers, screenshot ropes toggle.

**Keybind:** `Super+Shift+S` for screenshot rope overlay (remapped —
previous binding `toggleStyle` moved to `Super+Alt+S`).

**Hyprland 0.54 syntax fixes** across bundled `hypr-config/`:
- `windowrulev2` → `windowrule = prop val, match:key regex`
- `layerrule = blur, ns` → `layerrule = blur on, match:namespace ns`
- `layerrule = noanim, ns` → `layerrule = no_anim on, match:namespace ns`
- Removed trailing commas from `binds.conf`

---

## v6.15.1 — Screenshot Clipboard + Rope Physics (2026-04-19)

Three fixes to polish the v6.15 screenshot rope feature.

**1. Copy → Paste failed after screenshot capture.**
`wl-copy` was invoked with stdin file redirection inside a
`nohup ... & disown` chain. When Quickshell's Process reaped the
parent bash, the stdin fd closed before `wl-copy` could finalize
clipboard ownership. Switched to `setsid bash -c 'cat file | wl-copy
--type image/jpeg'` — `setsid` fully detaches from Quickshell's
process tree, `cat | wl-copy` pipe keeps data flowing independent of
parent fd lifecycle. Settle time bumped 0.3s → 0.8s with
`wl-paste --list-types` verification loop.

**2. Stale state on re-trigger.**
`ZenScreenshotOverlay` is created once per screen inside a
`Variants`, never destroyed between sessions. Session state (phase,
annotations, anchors, ropes) carried over to the next trigger. Added
`resetState()` called from `onVisibleChanged: if (visible)`.

**3. Rope physics too stiff — not smooth like flicko's Zephyr.**
v6.15 used `segments: 30, segment_length: 50` with `gravity: 9.8` —
rigid rod behavior, no catenary sag. Reverted to flicko's original
10 × 5 with `gravity: 3.2`, `inertia: 0.65`, `springForce: 0.35`.
Added `resetPhysics()` for clean re-init. State migration in
`install.sh` unconditionally resets rope defaults.

**Files changed:** `ZenRope.qml` (rewrite), `ZenScreenshotOverlay.qml`,
`ZenStringsState.qml`, `install.sh`.

---

## v6.15.2 — Music String Position Live-Update + Loading Placeholder (2026-04-20)

After fresh login, the music string visualizer appeared at the
wrong position (far-left) until the user interacted with the bar.

**Root cause:** `musicSlotItem.x` is relative to its immediate Loader
parent, always 0. When the grandparent `rightRow` (right-anchored)
shifts left as async-loading sysrow icons populate, `onXChanged`
never fires. The sole fallback (`barRoot.onContentImplicitWidthChanged`)
missed cases where row widths cancelled out.

**Fix in `Bar.qml`:**
- Direct `Connections` on each zone row (`leftRow`, `centerRow`,
  `rightRow`) listening to width/implicitWidth/x — the zone
  RowLayout's own properties fire synchronously on child changes
- Continuous 500ms `safetyPoll` Timer guaranteeing convergence
- `Qt.callLater` wrapping `mapToItem` to defer until after layout pass

**Fix in `shell.qml` + `MusicStrings.qml`:**
- Replaced fixed 1.5s fade-in timer with stability-based detection
  (600ms since last position change = layout settled)
- Added pulsing "Loading…" placeholder in the bar slot with
  `ThemeService`-matched colors and a sequential pulse animation
- Cross-fade choreography: Loading 350ms out + ZenStrings 400ms in,
  both triggered by `positionReady` flip

---

## v6.15.3 — Loading Loop Fix + Clock Jitter (2026-04-20)

v6.15.2's stability detection stuck in an infinite "Loading…" loop.

**Root cause:** `ZenClock` updates every 1000ms with live seconds.
Font glyph advance widths differ slightly between digits (non-strict
monospace), producing ~0.5-2px `implicitWidth` jitter on every tick.
That jitter propagated through Layout bindings and restarted the
600ms stability timer more often than it could complete.

**Fix in `Bar.qml`:**
- Write threshold bumped 0.5px → 2.0px (invisible visually, above
  all natural jitter sources)
- `safetyPoll` auto-stops once `positionReady` flips true; restarts
  on user-driven setting changes

**Fix in `shell.qml`:**
- Added absolute 4s max-wait fuse (`stringsMaxWaitTimer`) — Loading
  never hangs forever even in pathological scenarios
- Once-ready-stays-ready semantics — removed the v6.15.2 "large
  jump re-enters Loading" heuristic which was unreliable
- User-driven resets preserved (enable/disable, stringLength change)

---

## v6.15.4 — Layout-Stuck Position + Tooltip Anchor (2026-04-20)

After v6.15.3's Loading resolved, the string still appeared at the
wrong position until the user hovered any bar element. Tooltip also
floated ~60px above the bar.

**Position bug — Wayland surface negotiation race.** The barWindow
goes through async layer-shell geometry negotiation. Qt's `RowLayout`
caches initial child positions for right-anchored children and
doesn't recompute until *something* invalidates the layout. User
hover incidentally triggered binding re-eval → cache invalidation
→ fresh positions. Also, `mapToItem()` reads from the scene graph
which has its own lag vs QML property state.

**Fix in `Bar.qml`:**
- **Parent-chain walk** replaces `mapToItem` — direct `.x` property
  sum up the parent tree, no scene-graph dependency
- **`layoutNudger` Timer** toggles `Layout.preferredWidth` by 0.1px
  every 250ms for 30s — forces RowLayout recompute automatically
  (same mechanism as hover, running every quarter-second)
- `safetyPoll` reverted to forever-running with tiered interval
  (100ms first 3s, 500ms steady-state)

**Fix in `shell.qml`:**
- Max-wait fuse bumped 4s → 15s + `musicSlotLocalX < 20` sanity gate
  (refuses to commit at pre-layout coordinates, unless max-wait force)
- Added invisible `barTopAnchor` 1px Item at the bar's actual top edge
  within stringsWindow; tooltip now anchors to `barTopAnchor` instead
  of `stringsWindow.contentItem` (which was 60px above the bar due to
  vertical padding for curve overflow)

---

## v6.15.5 — Smooth Runtime Transitions (2026-04-20)

Enhancement (not a bugfix). When the tray expands or the taskbar
gains/loses an app, the physical ~40-60ms delay between layout
change and margin update was visible as a perceptible "snap." Added
`Behavior on margins.left` and `Behavior on implicitWidth` with
180ms `NumberAnimation { easing.type: Easing.OutCubic }` so the
string glides smoothly into its new position instead.

**Design detail:** `enabled: stringsWindow.positionReady` — the
Behavior only animates runtime changes, not the initial placement.
Without this guard, users would see the string sweep across the
whole screen on login.

---

## v6.15.6 — Theme-Change-Wipes-Config + Panel Mode Transition (2026-04-20)

Two unrelated fixes bundled.

**Bug 1: Snap gaps / blur / shadow settings wiped on theme change.**

Discovered that `SettingsStateV2.applyToHyprland()` had always been
incomplete — the file's header comment documented ~44 keywords, but
the implementation only wrote 24. The omitted ones:

- `general:snap:window_gap`, `snap:monitor_gap`, `snap:border_overlap`,
  `snap:respect_gaps`
- Eight `decoration:blur:*` secondaries
  (`ignore_opacity`, `noise`, `contrast`, `brightness`, `vibrancy`,
  `vibrancy_darkness`, `special`, `popups`)
- Five `decoration:shadow:*` secondaries
  (`ignore_window`, `offset`, `scale`, `color`, `color_inactive`)
- `decoration:dim_special`

Live slider changes via `scheduleHyprctl` worked fine, but any
subsequent `hyprctl reload` (triggered by animations preset change,
external theme watcher, or user keybind) reverted the omitted
keywords to `hyprland.conf` defaults. Theme change itself didn't
directly write them, but the theme apply cascade (terminal themer,
swaync reload, shell reload IPC) could trip a Hyprland reload on some
setups.

**Fix:** Expanded `applyToHyprland()` to the full 44+ keyword set.
Also added defensive re-call of `SettingsStateV2.applyToHyprland()`
in the `reloadThemeFromFile` IPC handler (via `Qt.callLater`) — so
any theme reload cascade can't wipe user settings.

**Bug 2: Panel mode switch → orphaned music string.**

When `PanelState.panelMode` changes, three coordinates update
asynchronously:
- `stringsWindow.barLeftOffset` (from PanelState binding)
- `ZenStringsState.barWindowLeft` (from `barWindow._publishBarLeft()`)
- `ZenStringsState.musicSlotLocalX` (from Bar.qml re-read)

v6.15.5's `Behavior` animated margins.left through the inconsistent
intermediate states → string flew across the screen. Plus stale
`musicSlotLocalX` from the old mode would land at nonsense positions
in the new mode.

**Fix:** Added `PanelState.panelModeChanged` handlers in both
`stringsWindow` (resets `positionReady = false`, shows Loading
placeholder during transition) and `Bar.qml::cMusic` (invalidates
cache + kicks the full discovery stack).

---

## v6.15.7 — Rapid Mode Cycling Lockout (2026-04-20)

Rapid mode cycling (Island → FW → Floating → Island within ~2s) still
produced orphaned strings despite v6.15.6. Each mode change reset
`musicSlotLocalX = -1`, then `posTimer` fired 16ms later and started
writing mid-resize stale values. The stability timer's last committed
write was typically a bad intermediate.

**Fix in `Bar.qml`:** Added `_modeTransitioning` lockout. On
`panelModeChanged`, set `_modeTransitioning = true`, start 300ms
`barSettlingTimer`. On `barRoot.widthChanged` with delta > 20px,
restart the settle timer. `_doUpdatePos` short-circuits while
`_modeTransitioning` is true. Small width deltas (≤ 20px,
layoutNudger's 0.1px toggle, runtime reflows) don't reset the timer.

**Fix in `shell.qml`:** Added `onBarWindowLeftChanged` to the
stringsWindow stability Connections block, so stability also waits
for `barWindowLeft` to settle (not just `musicSlotLocalX`).

---

## v6.15.8 — Stable-Read Verification (2026-04-20)

v6.15.7 still failed for transitions INTO island mode. Island has a
layout feedback loop: `barWindow.implicitWidth` reads
`bar.contentImplicitWidth`, bar re-lays-out when resized, which can
change contentImplicitWidth, triggering another width pass. The
`barRoot.width` stabilizes before children's `.x` positions finish
propagating across frames. First `_doUpdatePos` after unlock caught
intermediate stale positions.

**Fix:** Require TWO consecutive stable reads (within 2px) AND
bar-width-idle before lifting the lockout:

```qml
if (_modeTransitioning) {
    if (!_barWidthStable) {
        _lastReadX = x; _lastReadWidth = width
        return  // bar still resizing
    }
    if (|x - _lastReadX| < 2 && |width - _lastReadWidth| < 2) {
        _modeTransitioning = false  // two stable reads = unlock
    } else {
        _lastReadX = x; _lastReadWidth = width
        return  // still propagating
    }
}
```

Plus bounds sanity: `if (x < 0 || x > barRoot.width) return` —
filters stale `rightRow.x` from previous wide-bar modes.

---

## v6.15.9 — `RowLayout.forceLayout()` (2026-04-20)

v6.15.2 through v6.15.8 were all workarounds for the same underlying
issue: **Qt's QQuickLayout updates are asynchronous**. When parent
sizes change, child `.x` positions update on a subsequent frame.
Each patch added detection + wait logic.

v6.15.9 addresses the root cause directly. Qt provides
`QQuickLayout::forceLayout()` specifically for this case — runs the
entire layout pass synchronously, so reads after it returns are
guaranteed fresh.

**Fix:** Call `barMainLayout.forceLayout()` + each zone row's
`forceLayout()` in two places:
1. Preemptively in the `panelModeChanged` handler (via `Qt.callLater`)
2. At the top of `_doUpdatePos` whenever `_modeTransitioning` is true

Steady-state reads skip this (no overhead when not transitioning).
Loading duration dropped from ~1.0-1.2s to ~700-900ms typical. The
v6.15.8 stable-read check is preserved as a safety net.

---

## v6.15.10, v6.15.11, v6.15.12 — Nuclear Restart (corrected three times)

v6.15.9's `forceLayout()` fixed most transitions but still failed for
Float/FullWidth → Island on some setups. The remaining issue is
Quickshell-internal Wayland layer-shell surface renegotiation timing
that QML can't synchronize with.

**v6.15.10 — First attempt:** Selective shell respawn when
`(prev === "fullwidth" || prev === "floating") && curr === "island"`.
Used `qs -c zen-shell` as the respawn command.
**Didn't fire** on Paul's setup — he uses `quickshell -p PATH`, not
`qs -c`, so the pkill pattern `qs.*zen-shell` didn't match anything.

**v6.15.11 — Command fix:** Corrected to `quickshell -p
"$HOME/.config/quickshell/zen-shell"` + broader pkill pattern
`zen-shell`. Helper script written at runtime to
`/tmp/zen-shell-nuclear-restart.sh`.
**Self-suicide bug:** The script's filename contained "zen-shell",
and `pkill -f zen-shell` matched its own bash process cmdline
(`/bin/bash /tmp/zen-shell-nuclear-restart.sh`). Script killed
itself mid-execution. `quickshell -p ...` relaunch line never ran.

**v6.15.12 — Definitive fix:**
- Safe filename: renamed to `zs-restart.sh` (no "zen-shell" substring)
- Tightened pkill pattern to `quickshell.*zen-shell` — matches only
  actual quickshell invocations, not arbitrary helper scripts
- New file `scripts/zs-restart.sh` shipped in the package, installed
  by `install.sh` step 5 to `~/.local/bin/zs-restart.sh`
- Inline `/tmp/zs-restart.sh` fallback if user applied hotfix only
- Added `testNuclearRestart` IPC endpoint for manual verification

**What nuclear restart means:** When the bug-triggering transition
happens, `PanelState.saveState()` persists `mode = "island"` to JSON,
then a detached `setsid -f` helper script SIGTERMs Quickshell and
relaunches it. The reborn shell loads `mode = island` from the JSON
on startup, initializing every binding / surface / RowLayout from a
clean slate. Total visible flicker: ~550-900ms.

**Preserved across restart:** Panel mode, theme, all SettingsStateV2
state, SysRowState, bar layout, wallpaper, music stream (cava is
external), Hyprland workspaces and windows.
**Lost on restart:** Ephemeral shell UI — open Settings panel,
Control Panel, wallpaper picker, calendar popup.

---

## v6.15.13 — Install Automation Polish (2026-04-20)

Three quality-of-life improvements for the `zs-restart.sh` helper.

**1. Fully generic script.** Removed remaining `/home/paul/...`
examples from comments. Script consistently uses `$HOME` and `$USER`
throughout. Works for any user on any system out-of-box.

**2. Pre-flight checks.** Before attempting kill+respawn, the script
now verifies:
- `quickshell` binary exists in PATH (resolves to absolute path
  via `command -v`, uses the resolved path for the launch)
- `~/.config/quickshell/zen-shell` config directory exists

If either is missing, the script fails fast with a FATAL line in
`/tmp/zs-restart.log`.

**3. Stale file cleanup on upgrade.** `install.sh` step 5 now
detects and removes `~/.local/bin/zen-shell-nuclear-restart.sh`
from old v6.15.11 installs (no-op on fresh installs). Prevents
users upgrading from v6.15.11 from ending up with both files.

**Enhanced diagnostic log format.** `/tmp/zs-restart.log` now
includes pre-flight info (user, home, script path, cmdline,
quickshell binary path, config dir) alongside the kill+respawn
trace, making silent-failure diagnosis straightforward.

---

## Cumulative file-change summary (v6.14.2 → v6.15.13)

| File                                    | Status                 |
|-----------------------------------------|------------------------|
| `zen-shell-v5/Bar.qml`                  | Significantly reworked |
| `zen-shell-v5/shell.qml`                | Significantly reworked |
| `zen-shell-v5/SettingsStateV2.qml`      | Full keyword coverage  |
| `zen-shell-v5/MusicStrings.qml`         | New                    |
| `zen-shell-v5/ZenStrings.qml`           | New                    |
| `zen-shell-v5/ZenStringsState.qml`      | New                    |
| `zen-shell-v5/ZenRope.qml`              | New (screenshot ropes) |
| `zen-shell-v5/ZenScreenshotOverlay.qml` | New                    |
| `zen-shell-v5/ZenAnnotationToolbar.qml` | New                    |
| `scripts/zen-cava.sh`                   | New                    |
| `scripts/zen-screenshot.sh`             | New                    |
| `scripts/zs-restart.sh`                 | New                    |
| `hypr-config/*.conf`                    | Hyprland 0.54+ syntax  |
| `install.sh`                            | `--bootstrap` flag, zs-restart install, stale cleanup |
| `bootstrap.sh`                          | New (fresh-laptop mode) |

---

## Migration

**Fresh install (first-timer):**
```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development
git fetch --tags
git checkout v6.15.13
./install.sh
```
Fresh Arch-based laptop with KDE/GNOME/COSMIC currently installed:
```bash
./install.sh --bootstrap
```
Bootstrap installs Hyprland, Quickshell, pipewire stack, fonts, and
creates a Wayland session entry without touching the display manager.

**Upgrade from v6.14.2:**
```bash
./install.sh
```
Idempotent. Migrates `strings-state.json` schema and rope defaults.

**Upgrade from any v6.15.x:**
```bash
./install.sh
```
Also idempotent. Installs `zs-restart.sh` and removes the stale
`zen-shell-nuclear-restart.sh` from v6.15.11 if present.

---

## Testing matrix (v6.15.13 verified)

- Fresh login with 5+ open apps: music string lands correctly
  within ~1s via Loading placeholder → positionReady flip
- Idle bar with clock ticking: no spurious animations (2px threshold
  filters sub-pixel jitter)
- Single mode change (any → any): smooth, correct position
- Rapid mode cycling (Island → FW → Float → Island in 1.5s):
  Loading placeholder rides the transition, final position correct
- Floating/FullWidth → Island: selective nuclear restart ~600ms
  flicker, shell reborn in island mode with correct string position
- Runtime tray expand: smooth 180ms `Behavior` slide, no
  `_modeTransitioning` engagement
- Theme cycle (Nord → Tokyo Night → One Dark → Lovelace):
  snap gaps / blur / shadow preserved across all switches
- Screenshot region (Super+Shift+S): ropes anchor from correct
  monitor's corners, copy works on first try (wl-copy setsid path)
- Multi-monitor: per-screen strings with independent stability
  timers; screenshot rope follows cursor monitor

---

*WALA TAYONG BABAWASAN — nothing removed across the series. Every
feature from v6.14.2 is preserved through v6.15.13.*
