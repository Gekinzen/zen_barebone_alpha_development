# Zen Shell v6.15.6 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.5 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** two bugfixes — snap/blur/shadow settings wiping on theme
reload, and music string going orphaned during panel mode switches.
3 files touched. Walang ibang binawas.

---

## Fixes

### 1. Settings wiping on theme change (snap gaps, blur/shadow extras)

**Symptoms reported by Paul:**
> "yun sa pag change ng themes naaalis yun configuuration ko sa gap in
> gap out etc dapat hindi na apektuhan yun change ng theme"

Translation: when changing themes, my gap in/gap out (and related)
configuration gets wiped — theme change should not affect these.

**Root cause:**
`SettingsStateV2.applyToHyprland()` has been **incomplete since it was
written** — and probably got worse as new properties were added to the
singleton over time. The file's header comment documents the full
property set (44+ keywords across general + decoration), but
`applyToHyprland()` only wrote ~24 of them. The omitted keywords
include:

**General → snap (all omitted):**
- `general:snap:window_gap`
- `general:snap:monitor_gap`
- `general:snap:border_overlap`
- `general:snap:respect_gaps`

**Decoration → blur secondaries (omitted):**
- `decoration:blur:ignore_opacity`
- `decoration:blur:noise`
- `decoration:blur:contrast`
- `decoration:blur:brightness`
- `decoration:blur:vibrancy`
- `decoration:blur:vibrancy_darkness`
- `decoration:blur:special`
- `decoration:blur:popups`

**Decoration → shadow secondaries (omitted):**
- `decoration:shadow:ignore_window`
- `decoration:shadow:offset`
- `decoration:shadow:scale`
- `decoration:shadow:color`
- `decoration:shadow:color_inactive`

**Decoration → dim_special (omitted)**

When the user adjusts any of these in SettingsPage, the slider's
`onValueEdited` handler does call `scheduleHyprctl("keyword … X")`
live — so the change IS visible immediately. But the live write is
ephemeral; only `applyToHyprland()` on shell startup re-asserts
these from the persisted JSON. Since `applyToHyprland()` never
wrote them, they were never restored. Any subsequent `hyprctl
reload` (which Hyprland performs for various reasons — animations
preset change via AnimationsPage, external hypr-control-center
Python tool watching current-theme.json, user's own keybind, etc.)
re-reads hyprland.conf, replacing the live-tuned runtime values
with whatever defaults the user's conf file contains.

Theme change doesn't _directly_ trigger this — but theme apply
cascades through terminal-themer + swaync-themer scripts and
shell-reload IPC calls. Depending on the user's setup (notably
whether the external Python `hypr-control-center` is watching
`~/.config/hypr-control-center/current-theme.json`), one of those
cascades can trip a hyprctl reload, which is exactly when the
omitted keywords silently "disappear."

**Fix 1a (SettingsStateV2.qml — `applyToHyprland()`):**

Expanded the batch hyprctl write to cover the full property set
documented in the file's header. Now 44+ keywords go out on every
call instead of 24. The `hyprProc.command` batch includes every
general:snap:*, blur:*, and shadow:* keyword that the singleton
tracks, plus `dim_special` which was also missing. Every user
setting in GeneralPage and DecorationPage now properly round-trips
through saved state → Hyprland on every apply.

**Fix 1b (shell.qml — IPC `reloadThemeFromFile`):**

Defensively re-call `SettingsStateV2.applyToHyprland()` after the
theme FileView reloads. Even if something outside zen-shell-v5's
control triggers a `hyprctl reload` during the theme apply cascade,
this guarantees user settings are restored within a frame of the
reload completing.

```qml
function reloadThemeFromFile() {
    ThemeService.reload()
    Qt.callLater(SettingsStateV2.applyToHyprland)
}
```

`Qt.callLater` defers to the next event tick so ThemeService's own
reload propagates first, then settings re-assert on top.

### 2. Panel mode switching → music string orphaned at old coordinates

**Symptoms reported by Paul (with uploaded video):**
> "yan pre yung sa music string nugn nag palit ako ng panel floating
> or fuillwidth nag ka loko loko na yun string"

Translation: when switching panel modes (floating / fullwidth), the
music string goes haywire — stuck at old coordinates, floating
orphaned somewhere random on the screen.

**Root cause:**
When `PanelState.panelMode` changes, THREE coordinates involved in
stringsWindow positioning need to update simultaneously but they
arrive asynchronously:

1. `stringsWindow.barLeftOffset` (readonly property in shell.qml)
   — recomputes immediately via its binding on `PanelState.panelMode`
2. `ZenStringsState.barWindowLeft` — written by `barWindow._publishBarLeft()`
   via its own `PanelState.panelModeChanged` Connection (next event tick)
3. `ZenStringsState.musicSlotLocalX` — only updates when Bar.qml's
   layout-tracking signals fire, which happens AFTER the RowLayout
   has re-laid-out for the new bar geometry (multiple event ticks)

v6.15.5 added `Behavior on margins.left { NumberAnimation 180ms }`
for smooth runtime transitions on tray expand etc. The Behavior
animates ANY change to margins.left — including the inconsistent
intermediate states during panel mode change. Result: the string
smoothly swept across the screen through impossible coordinates
before settling. This is the "loko-loko" flight path Paul recorded.

Plus: `musicSlotLocalX` may hold a value valid for the OLD panel
mode's bar width (e.g. 800 for fullwidth's 1920px bar → music
position was bar-edge-200px-minus-sysrow-width). Plugged into the
NEW mode's `barLeftOffset` (e.g. 240 for island mode centered on
1920), we'd compute `margins.left = 240 + 800 = 1040` — which is
the middle of an island bar that only spans 500-1420. String ends
up visibly off-center or past the right edge.

**Fix 2a (shell.qml — `stringsWindow`):**

Added a `Connections { target: PanelState; function onPanelModeChanged() { ... } }`
that on every mode change:

1. Resets `positionReady = false` on both stringsWindow and
   ZenStringsState → stringsWindow.visible binding flips false
   (via the existing `&& positionReady` guard) → orphaned string
   immediately disappears.
2. MusicStrings Loading placeholder (bound to
   `!ZenStringsState.positionReady`) becomes visible in the bar
   slot. Because the placeholder lives inside the bar's RowLayout,
   it's always at the correct new slot position natively —
   RowLayout handles its own children's layout.
3. Invalidates `ZenStringsState.musicSlotLocalX = -1` → the
   shell.qml `_tryMarkReady` sanity gate (which refuses to commit
   if `musicSlotLocalX < 20`) ensures we don't commit to any stale
   value until Bar.qml reports a fresh read.
4. Restarts `stringsStabilityTimer` and `stringsMaxWaitTimer` →
   normal stability detection resumes.

**Fix 2b (Bar.qml — `cMusic`):**

Mirror handler on `PanelState.panelModeChanged` that kicks the full
position-discovery stack:

1. Clear cached positions: `barRoot.musicSlotLocalX = -1;
   ZenStringsState.musicSlotLocalX = -1`
2. Restart `posTimer` (16ms debounced mapToItem-replacement walk)
3. Restart `settleTimer` (8 ticks × 150ms)
4. Reset `safetyPoll` to 100ms fast mode + restart
5. Restart `layoutNudger` (forces RowLayout recompute every 250ms
   to unstick post-negotiation stale layouts — same mechanism that
   handles login)

**End-to-end flow on panel mode change (v6.15.6):**

```
T=0       User clicks Fullwidth in PanelPage
T=0       PanelState.panelMode = "fullwidth" → panelModeChanged fires
T=0       Bar.qml:  cache invalidated, discovery stack kicked
          shell.qml: positionReady = false → strings hidden
                     MusicStrings Loading placeholder shown
                     musicSlotLocalX = -1 (sanity gate armed)
T=0       barWindow._publishBarLeft() → barWindowLeft updated
T=0-500ms Wayland layer-shell negotiates new surface geometry
          Bar RowLayout re-lays-out for new mode
          layoutNudger toggles Layout.preferredWidth every 250ms
          safetyPoll + posTimer fire repeatedly on layout signals
T=~300ms  musicSlotLocalX reports fresh correct value
T=~900ms  stability timer (600ms since last write) fires
          → _tryMarkReady → passes sanity (>= 20) → positionReady = true
T=~900ms  Loading placeholder fades out (350ms)
          stringsWindow becomes visible at correct new-mode position
          ZenStrings fades in (400ms OutCubic)
```

Behavior animation on margins.left still works for RUNTIME changes
(tray expand etc., where positionReady stays true throughout — v6.15.5's
feature is preserved). It only "turns off" during the mode-change
transition window because `enabled: positionReady` is false then.

---

## Files changed

```
zen-shell-v5/SettingsStateV2.qml  v6.15.5 → v6.15.6 (applyToHyprland expanded)
zen-shell-v5/Bar.qml              v6.15.5 → v6.15.6 (PanelState Connection added)
zen-shell-v5/shell.qml            v6.15.5 → v6.15.6 (IPC + stringsWindow PanelState Connection)
```

`MusicStrings.qml`, `ZenStringsState.qml`, `ThemeService.qml`,
`PanelState.qml`, `Theme.qml`, all other QML — untouched.
`install.sh` / `bootstrap.sh` — only version banner + summary text
additions, no functional changes.

---

## Migration

No config migration, no schema changes, no new dependencies.

**Apply by drop-in replace (from v6.15.5):**

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5
cp /path/to/patch/zen-shell-v5/SettingsStateV2.qml .
cp /path/to/patch/zen-shell-v5/Bar.qml .
cp /path/to/patch/zen-shell-v5/shell.qml .

# Reload
pkill -f 'qs.*zen-shell' && sleep 0.3 && qs -c zen-shell &>/dev/null &
```

**Post-install recommendation:**
After upgrading, open Settings → General once and tweak any snap /
blur / shadow property by 1, then back — this forces a fresh save
of settings-state-v2.json with values the shell now knows how to
fully re-assert. (Not strictly required; existing state works fine,
but this guarantees the persisted JSON is self-consistent.)

---

## Behaviour summary

| Scenario                        | Before v6.15.6                  | After v6.15.6                   |
|---------------------------------|---------------------------------|---------------------------------|
| Theme change                    | Snap gaps quietly reset         | Snap gaps preserved ✓           |
| Theme change                    | Blur/shadow extras reset        | Blur/shadow extras preserved ✓  |
| hyprctl reload (any cause)      | V2 omitted keys reverted        | Re-asserted on next shell apply ✓|
| Panel mode switch island → fw   | String orphaned at old coord    | Loading → correct new coord ✓   |
| Panel mode switch fw → floating | String flies across screen      | Loading → correct new coord ✓   |
| Panel mode switch floating → is | String at wrong margin          | Loading → correct new coord ✓   |
| Runtime tray expand (same mode) | Smooth 180ms slide (unchanged)  | Smooth 180ms slide ✓            |

---

## Known unchanged behaviour (verified)

- Loading placeholder (pulsing dot + "Loading…") visual unchanged
- MusicStrings position tracking (parent-chain walk, layoutNudger,
  safetyPoll tiered) unchanged from v6.15.4/v6.15.5
- Tooltip bar-top anchor (v6.15.4) unchanged
- Smooth runtime transitions for tray expand / taskbar reflow
  (v6.15.5) unchanged — these still animate via Behavior since
  positionReady stays true throughout
- ThemeService.applyTheme flow unchanged — same cp + touch + IPC
  reload pattern
- Hyprland config files (hyprland.conf, modules/) untouched
- SettingsStateV2 schema / JSON format unchanged — existing saved
  state loads correctly
- Panel modes (fullwidth / floating / island) visual appearance
  unchanged — only the transition handling is fixed

---

**Tested matrix:**
- Theme change Nord → Tokyo Night → One Dark → Lovelace: snap gaps
  persist across all switches.
- Adjust snap window gap to 15px, change theme, verify 15px retained
  via `hyprctl getoption general:snap:window_gap`.
- Panel mode cycle fullwidth → floating → island → fullwidth: music
  string routes through Loading placeholder each time, arrives at
  correct new-mode position within ~1s.
- Runtime tray expand during island mode: smooth slide preserved
  (Behavior still active in steady state).
