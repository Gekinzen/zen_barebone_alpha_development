# v6.16.4.12.7 — Tachiagari (立ち上がり)

**Channel:** alpha
**Release date:** 2026-05-06
**Branch:** `alpha-v6.16.4.12.7`
**Predecessor:** v6.16.4.12.6.53 — Hiraki (開き) hotfix 1

## Codename — Tachiagari (立ち上がり)

"Standing up / rising up." Fits the headline change of this drop:
the panel can now genuinely stand at the top of the screen and every
hover-emitting popup (clock, sysrow tooltips, taskbar window-list,
music-strings, calendar) follows it — instead of trying to render
above the screen edge and getting clipped into invisibility.

## Summary

Six asks rolled into one drop:

1. **Module Shape "Pill" actually renders pill** — was visually
   identical to "Round" because the radius was clamped to height/2.
2. **Settings sidebar bottom shows user avatar + name** — same
   pattern as the StartMenu footer; clicking it jumps to the User
   Profile page.
3. **`zen-monitor-fix-v2` merged into the main installer** —
   stateful per-topology profiles, helper CLI, system resume hook,
   minimal `monitors.conf` seed.
4. **Smart Gaming Detection** — independent of GPU mode. New
   SettingsStateV2 toggle spawns a watcher daemon that auto-fires
   `PowerProfileService.setGamingBoost()` when known game/launcher
   processes appear; restores the previous profile when they exit.
5. **Start Button border tint** — optional toggle to adopt the
   panel's `borderColor` for the start button rim. Width slider too.
6. **Top-bar popups follow the bar** — every PopupWindow sourced
   from a bar module now uses position-aware `anchor.edges` /
   `anchor.gravity` so it drops DOWN when the bar is at the top
   and floats UP when the bar is at the bottom.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.7, codename Tachiagari, releaseDate 2026-05-06. |
| `zen-shell-v5/Theme.qml` | `moduleRadius` for pill mode 45 → 10 (was being clamped to height/2 = 20, making pill identical to round). `workspaceRadius` for pill 26 → 6 for matching flat look. |
| `zen-shell-v5/PanelState.qml` | New properties: `startButtonUseBorderColor`, `startButtonBorderWidth`. Persisted in `saveState()` / `applyState()`. New readonly helpers: `popupAnchorEdges`, `popupAnchorGravity` (for popup widgets to bind to). |
| `zen-shell-v5/StartMenu.qml` | Border color/width now bind to PanelState.startButtonUseBorderColor / startButtonBorderWidth. Hover state preserved (still flips to blue). Added Behavior on border.color. |
| `zen-shell-v5/ZenSettings.qml` | Sidebar footer rebuilt — replaced the single theme-status row with a new ColumnLayout containing (1) user avatar + username + @hostname row (clickable → User Profile page) and (2) a thinner theme-status row below. Added `import Qt5Compat.GraphicalEffects` for OpacityMask. |
| `zen-shell-v5/SysRowIcon.qml` | Tooltip popup `anchor.edges` / `anchor.gravity` now ternary on `PanelState.isTop`. |
| `zen-shell-v5/Taskbar.qml` | Both PopupWindows (window-list, context menu) now position-aware. |
| `zen-shell-v5/MusicStrings.qml` | Tooltip popup position-aware. |
| `zen-shell-v5/CalendarButton.qml` | Manual `anchor.rect.y` flips between `root.y - 540` (bottom bar) and `root.y + root.height + 8` (top bar). |
| `zen-shell-v5/ZenClock.qml` | Both PopupWindows (peekPopup, calPopup) edges position-aware. |
| `zen-shell-v5/shell.qml` | Two new IPC entry points: `gameBoostOn` and `gameBoostOff`, used by the new smart-gaming watcher. |
| `zen-shell-v5/SettingsStateV2.qml` | New property `smartGamingDetect` (persisted). `onSmartGamingDetectChanged` spawns/kills the watcher daemon via `pkill` + `nohup`. Startup also restarts the daemon if the saved value was true. |
| `zen-shell-v5/PanelPage.qml` | New SettingRows under Start Button: "Tint Start Button Border" (Switch + color preview) and "Start Button Border Width" (0–4 slider). |
| `zen-shell-v5/BatterySettingsPage.qml` | New HMSection "Smart Gaming Detection" with toggle + status indicator, sitting between GPU Switcher and Idle & Sleep sections. |
| `scripts/zen-smart-game-watcher.sh` | NEW — independent gaming watcher daemon. Polls pgrep for game/launcher patterns every 3s, fires `qs -c zen-shell ipc call zen gameBoostOn/Off` on edges. Single-instance guarded via PID file. |
| `scripts/zen-monitor-watcher.sh` | REPLACED with v2 (stateful per-topology profiles). |
| `scripts/zen-monitor-watcher.service` | REPLACED with v2 unit file. |
| `scripts/zen-monitor-resume.service` | NEW — system unit (sudo install) for post-resume reconcile. |
| `scripts/zen-monitor-profile` | NEW — helper CLI: `show / list / save / cat / edit / reload / clear`. |
| `hypr-config/monitor-v2-config/monitors.conf` | NEW — minimal fallback seed. |
| `hypr-config/monitor-v2-config/zen-monitor-watcher.env` | NEW — v2 env schema seed. |
| `install.sh` | Banner version bumped. New scripts (`zen-monitor-profile`, `zen-smart-game-watcher.sh`) added to install loop. Monitor section expanded with v2 additions: profiles dir, monitors.conf seed + hyprland.conf source-line, v2 env file, sudo install of resume.service, in-place watcher restart when in a Hyprland session. |
| `CHANGELOG-v6.16.4.12.7.md` | NEW (this file). |

## Detail — Module Shape Pill fix

### Reproduction (.6.53)

1. Open Settings → Panel → Background & Shape.
2. Set Module Shape dropdown to **Pill**.
3. Click around to confirm — settings save.
4. Restart shell. Settings page still shows "Pill", but **the bar
   modules look identical to Round.**

### Root cause

`Theme.qml` line 40 (pre-Tachiagari):

```qml
property real moduleRadius: styleMode === "round" ? 20 : 45
```

But `moduleHeight` is 40px. QML clamps `radius` to `height / 2` — so
radius effectively maxes out at 20px. Pill mode was asking for 45px,
which clamped to 20px = same as round.

The intent of pill mode is a *flatter, Waybar-style elongated module*
— which means a SMALLER radius (so corners are visible as actual
corners), not a bigger one.

### Fix

```qml
// v6.16.4.12.7 (Tachiagari)
property real moduleRadius: styleMode === "round" ? 20 : 10
property real moduleHeight: 40
property real workspaceRadius: styleMode === "round" ? 20 : 6
```

10px radius on a 40px-tall module = visible flat top/bottom edges
with rounded corners → genuine pill look. 6px on workspace dots
gives them the small-rounded-rectangle look that pill mode implied.

No data migration needed — `Theme.styleMode` is still loaded from
`PanelState.styleMode`, just with new visual constants.

## Detail — Settings sidebar user row

Mirrors the StartMenuPanel footer pattern (avatar circle + name +
@hostname). New in this drop: clicking the row jumps the active
settings page to "userprofile". Theme status indicator (was the
sole footer in .53) preserved as a slimmer secondary row below.

OpacityMask shader pattern reused verbatim from StartMenuPanel
because `layer.enabled` on transparent-bg Rectangles still doesn't
reliably produce a circular mask in this Quickshell build —
documented persistent QML pattern.

## Detail — Smart Gaming Detection

### Why a separate toggle from `gpuMode = "auto-gaming"`

`gpuMode` controls which GPU runs apps via env vars. A user might:

- Stay on iGPU (battery laptop) but still want CPU/blur tuning when
  a game pops up.
- Be on a single-GPU desktop but still want the compositor effects
  toned down for max FPS.

Splitting the responsibilities lets the user mix-and-match.

### Lifecycle

1. User toggles "Enable Smart Detection" in Settings → Battery →
   Smart Gaming Detection.
2. `SettingsStateV2.smartGamingDetect = true` — `onSmartGamingDetectChanged`
   handler runs:
   ```bash
   pkill -f zen-smart-game-watcher.sh   # idempotent guard
   nohup ~/.local/bin/zen-smart-game-watcher.sh \
     >> ~/.cache/zen-smart-game-watcher.log 2>&1 &
   ```
3. Daemon polls pgrep for the GAMING_PATTERNS list every 3s.
4. On rising edge (no-game → game): `qs -c zen-shell ipc call zen gameBoostOn`
5. On falling edge (game → no-game): `qs -c zen-shell ipc call zen gameBoostOff`
6. Both IPC calls route through `PowerProfileService.setGamingBoost()`
   so SettingsStateV2.gamingBoostActive, the bar PowerBadge icon, and
   the previous-profile bookkeeping all stay in sync — same code path
   as the existing manual toggle in ControlPanel / Battery page.
7. User toggles off → `pkill -TERM` → daemon's EXIT trap flushes
   any active boost back to OFF.

### GAMING_PATTERNS coverage (extended from v6.16.1's list)

steam, steamwebhelper, Lutris, lutris-wrapper, heroic, bottles,
minecraft, PrismLauncher, ATLauncher, dolphin-emu, cemu, rpcs3,
yuzu, ryujinx, Ryujinx, citra, PCSX2, duckstation, ppsspp,
retroarch, gamescope, wine, proton, gamemoderun, mangohud, DXVK_HUD.

### Coexistence with `gpuMode = "auto-gaming"`

Both daemons can run simultaneously — the original
`zen-game-watcher.sh` (tied to GPU mode) and this new
`zen-smart-game-watcher.sh` (independent). They emit redundant
boost-on calls when a game launches, but `setGamingBoost()` is
idempotent (gates on `gamingBoostActive`), so there's no double-tax
on the user's profile/blur state. Wasteful but harmless.

## Detail — Start Button border tint

Two new persisted PanelState properties:

| Property | Default | Range | Effect |
|---|---|---|---|
| `startButtonUseBorderColor` | `false` | bool | When true, idle-state border uses `PanelState.borderColor` instead of `Theme.bg1`. |
| `startButtonBorderWidth` | `1` | 0–4 | Border thickness. 0 = no border. |

Hover state (`ma.containsMouse`) ALWAYS flips to `Theme.blue` —
intentional. Click affordance must remain obvious regardless of the
idle tint. The settings UI reflects this in the description.

## Detail — Top-bar popup adaptation

Pre-Tachiagari, the bar itself was already top-aware (anchors
ternary on `PanelState.isTop`), as were the calendar/start menu
overlay PanelWindows. But the PopupWindows that emerge from
individual bar modules — the inline tooltips / drawers — were
hardcoded to `Edges.Top` / `Edges.Top`. So when the user moved the
bar to the top:

- Hovering a sysrow icon → tooltip rendered ABOVE the bar = above
  the top of the screen = clipped invisible.
- Hovering the clock → calendar same problem.
- Right-clicking a taskbar app → context menu floated above the bar.

### Files touched (popup edge changes)

```
SysRowIcon.qml      tooltip popup
Taskbar.qml         (x2: window list popup, context menu popup)
MusicStrings.qml    track-info tooltip
CalendarButton.qml  manual anchor.rect.y flip
ZenClock.qml        (x2: peekPopup [disabled but fixed for cleanliness], calPopup)
```

All now: `PanelState.isTop ? Edges.Bottom : Edges.Top`.

Why two attribute lines per popup (edges + gravity): Quickshell's
PopupWindow uses both — `edges` is the anchor point, `gravity` is
the growth direction. They're always the same value for our case
but we set them explicitly so the popup logic is self-documenting.

PanelState also exposes new `readonly property int popupAnchorEdges`
/ `popupAnchorGravity` helpers (encoded as Edges integer values:
1 = Top, 2 = Bottom). Future popup widgets can bind to those
instead of repeating the ternary.

## Detail — Monitor fix v2 merge

Previously the v2 monitor system was a separate tarball
(`zen-monitor-fix-v2.tgz`) that the user installed AFTER the main
shell. Now it's part of the main installer.

What v2 adds over the v1 watcher already in the tree:

- **Per-topology profiles**: each unique combination of
  CONNECTED outputs (sorted, joined with `+`) gets its own
  `~/.config/hypr/monitor-profiles/<key>.conf`. Plug/unplug
  between desktop/docked/laptop-only setups → the right layout
  auto-loads within ~200ms.
- **`zen-monitor-profile` CLI**: inspect / list / save / edit /
  reload / clear current and saved profiles.
- **System resume hook**: `/etc/systemd/system/zen-monitor-resume.service`
  fires SIGUSR1 to the user-level watcher after suspend → resume,
  so the right profile re-applies even when no socket2 event
  arrives (some hardware doesn't emit one on resume).
- **Minimal `monitors.conf` seed**: only installed if absent.
  Ensures `source = ~/.config/hypr/monitors.conf` in `hyprland.conf`
  doesn't error on first run.
- **In-place watcher restart**: if installer runs inside a
  Hyprland session, the old v1 daemon is restarted with the v2
  binary without waiting for a re-login.

### Migration

Existing users who installed `zen-monitor-fix-v2.tgz` standalone
already have the watcher running. Re-running the main installer:

1. Watcher script gets re-copied (no behavioral change — same v2 code).
2. `zen-monitor-watcher.env` is preserved if present.
3. Profiles directory is `mkdir -p` (no-op if it exists).
4. `monitors.conf` is preserved if present.
5. Resume.service is `cmp -s` — re-installed only if differs.

Idempotent. Safe to run on top of an existing v2 install.

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.7
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

If a previous shell instance had Smart Gaming Detection enabled
(from a prior build that pre-shipped this feature for testing),
the watcher will be restarted as part of the SettingsStateV2 init
when the shell boots — no manual action needed.

## Carry-forward from Hiraki .53

- Click-to-open Clock module — preserved
- Click-to-open StartMenu — preserved
- `z: 1` on Clock and StartMenu — preserved
- Wheel-month cycling only when calendar already open — preserved
- Plugin manager temporarily hidden — preserved
- Calendar popup positioning above the clock (rightX-aware) — preserved
- install.sh Clock.qml direct-from-tarball install — preserved

## Wala tayong babawasan

Every additive change in this drop layers ON TOP of existing
behavior. The pill-mode constant changes are the only "behavioral"
edit and they correct what was visibly broken — pill mode that
looked exactly like round mode was no behavior anyone was relying
on. No data migration. Old `panel-state.json` and
`settings-state-v2.json` files load cleanly into the new schema
(new properties default to safe values when absent).
