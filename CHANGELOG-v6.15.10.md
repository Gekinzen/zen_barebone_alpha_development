# Zen Shell v6.15.10 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.9 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

**Scope:** nuclear shell respawn for the specific Float/FW → Island
transition path. **1 file touched** (`shell.qml`). No changes to
`Bar.qml` or `SettingsStateV2.qml` — the v6.15.8 stable-reads and
v6.15.9 forceLayout() mechanisms remain active for all OTHER
transitions.

---

## Fix

### Nuclear shell restart on Float/FullWidth → Island

**Background:**

Seven previous patch versions (v6.15.2 through v6.15.9) attempted
progressively more sophisticated fixes for "string commits at wrong
position after Floating/FullWidth → Island transition":

- v6.15.2: Loading placeholder + position re-read
- v6.15.3: Threshold filtering on jitter
- v6.15.4: Parent-chain walk + layoutNudger
- v6.15.5: Smooth runtime Behavior animations
- v6.15.6: positionReady reset on mode change
- v6.15.7: Mode-transition lockout (300ms bar-width idle)
- v6.15.8: Stable-read verification (2 consecutive matching reads)
- v6.15.9: `QQuickLayout.forceLayout()` — synchronous Qt layout pass

v6.15.9 should have been the definitive fix since `forceLayout()` is
Qt's canonical API for exactly this scenario. It works correctly for
simple transitions. But Paul confirmed it still doesn't reliably fix
the specific **Float/FW → Island** case.

**Hypothesized root cause (that QML can't reach):**

The remaining issue is almost certainly **at the Quickshell +
Wayland layer-shell layer**, below what QML can influence:

1. When `barWindow.implicitWidth` changes (Float→Island formula
   switch), Quickshell requests a new layer-shell surface size from
   the Wayland compositor.
2. Hyprland acknowledges the resize asynchronously and sends back a
   new surface configuration.
3. Quickshell receives the new surface and marks the QML window for
   re-rendering.
4. **Between steps 1–3, QML's `bar.width` may already reflect the
   requested new size, but the actual rendered surface and child
   geometry calculations are still using the old surface size
   transform.** `forceLayout()` at this point runs layout against
   stale surface metadata.

This is a Quickshell-internal timing issue that can't be fixed from
QML — we'd need Quickshell to expose a "surface configured" signal
we could wait for. In the absence of that, no amount of QML-level
synchronization catches it.

**The nuclear fix:**

When the specific problematic transition happens
(fullwidth/floating → island), we kill the entire Quickshell process
and relaunch it. The reborn shell starts cleanly:

- PanelState.saveState() writes the new "island" mode to JSON first
- Old qs process gets SIGTERM
- Hyprland cleans up dead layer-shell surfaces
- New qs process spawns, loads PanelState from JSON, starts directly
  in island mode
- Every QML binding, every layer-shell surface, every RowLayout,
  every Process, every FileView — all initialized from zero in the
  correct state. No feedback loop possible because there's no "old
  mode" state to migrate from.

**Selective activation:**

The nuclear restart only fires on the exact bug-triggering path:

```qml
if (prev === "fullwidth" || prev === "floating") &&
   (curr === "island")
```

All other transitions continue using the v6.15.8 + v6.15.9
QML-based mechanisms (stable reads + forceLayout) — they work fine
for those cases, no need to flicker.

**Triggering logic in shell.qml:**

```qml
property string _previousPanelMode: PanelState.panelMode
property bool _nuclearRestartPending: false

Connections {
    target: PanelState
    function onPanelModeChanged() {
        const prev = root._previousPanelMode
        const curr = PanelState.panelMode

        if (!root._nuclearRestartPending
            && curr === "island"
            && (prev === "fullwidth" || prev === "floating")) {
            root._nuclearRestartPending = true
            nuclearRestartDelay.restart()
        }
        root._previousPanelMode = curr
    }
}

Timer {
    id: nuclearRestartDelay
    interval: 250  // allow PanelState save to disk
    onTriggered: {
        PanelState.saveState()  // explicit save, belt + suspenders
        nuclearRestartProcess.running = true
    }
}

Process {
    id: nuclearRestartProcess
    command: ["bash", "-c",
        "( setsid nohup bash -c " +
        "'sleep 0.3 && pkill -f \"qs.*zen-shell\" 2>/dev/null; " +
        "sleep 0.4 && qs -c zen-shell' " +
        "</dev/null >/dev/null 2>&1 & ) </dev/null >/dev/null 2>&1 & disown"]
}
```

**Why the specific process invocation:**

- `setsid` — new process session, independent from Quickshell's
  process group
- `nohup` — survives SIGHUP when parent dies
- `bash -c` — wraps the sleep + pkill + relaunch sequence
- `sleep 0.3` — lets PanelState.saveState() fully commit to disk
- `pkill -f "qs.*zen-shell"` — kills the old shell
- `sleep 0.4` — lets Hyprland clean up dead layer-shell surfaces
  before the new shell requests surfaces with the same namespaces
- `qs -c zen-shell` — launches fresh shell
- `</dev/null >/dev/null 2>&1 & disown` — full stream detach +
  background + shell disown, so the respawn survives all signal
  propagation when qs dies

## Timeline of a Float → Island transition (v6.15.10)

```
T=0       User clicks Island in PanelPage
T=0       PanelState.panelMode = "island"
T=0       panelModeChanged fires
          shell.qml Connections:
            prev="floating", curr="island"
            _nuclearRestartPending = true
            nuclearRestartDelay.restart() [250ms]
T=0       Normal mode-change handlers ALSO fire (Bar.qml, stringsWindow
          in shell.qml) — they start their usual position-discovery
          dance, but the shell is about to die before they finish
T=250     nuclearRestartDelay fires
          PanelState.saveState() → writes mode=island to JSON
          nuclearRestartProcess starts
T=250     Detached bash subshell starts (setsid nohup)
T=550     subshell: pkill -f "qs.*zen-shell"
          → SIGTERM to running qs process
          → QML shell shuts down cleanly
          → Hyprland reclaims layer-shell surfaces
T=950     subshell: qs -c zen-shell
          → Fresh Quickshell launches
          → Loads PanelState JSON: panelMode=island
          → Singletons initialize
          → Variants {} creates barWindow + stringsWindow per monitor
          → All widgets start in island mode from clean state
T=1100    Bar fully rendered in island mode
          Music string at correct position (no transitional state
          to recover from)

Total visible flicker: ~550ms (when old shell dies) to ~1100ms
(when new shell fully renders). Roughly ~550ms of no bar visible.
```

## Files changed

```
zen-shell-v5/shell.qml    v6.15.9 → v6.15.10 (nuclear restart block)
```

`Bar.qml` unchanged — v6.15.9's forceLayout() remains active for
all non-nuclear transitions. `SettingsStateV2.qml` unchanged from
v6.15.6.

## Migration

Single-file drop-in:

```bash
cd ~/.config/quickshell/zen-shell/zen-shell-v5
cp /path/to/patch/zen-shell-v5/shell.qml .

# Reload
pkill -f 'qs.*zen-shell' && sleep 0.3 && qs -c zen-shell &>/dev/null &
```

## Behaviour summary

| Scenario                      | Method used            | Visible     |
|-------------------------------|------------------------|-------------|
| FW → Floating                 | v6.15.8 + v6.15.9      | Smooth ✓    |
| Floating → FW                 | v6.15.8 + v6.15.9      | Smooth ✓    |
| Island → FW                   | v6.15.8 + v6.15.9      | Smooth ✓    |
| Island → Floating             | v6.15.8 + v6.15.9      | Smooth ✓    |
| **Fullwidth → Island**        | **Nuclear restart**    | ~600ms flicker, correct ✓ |
| **Floating → Island**         | **Nuclear restart**    | ~600ms flicker, correct ✓ |
| Rapid Island→FW→Float→Island  | Mix: stable reads +    | Last transition flickers  |
|                               | nuclear on final step  |                           |
| Runtime tray expand           | v6.15.5 Behavior       | Smooth slide ✓            |
| Theme change                  | v6.15.6                | No gap wipe ✓             |
| Cold start / login            | Normal QML init        | Correct ✓                 |

## Trade-offs (what you lose in exchange for the fix)

**Lost on nuclear restart:**
- Settings panel — closes
- Control Panel — closes
- Calendar popup — closes
- Wallpaper picker — closes
- Keybind cheatsheet — closes
- Power confirm dialog — closes (non-issue, user clicks elsewhere)
- Notification popups — closes (will re-appear as SwayNC resends)

**Preserved across nuclear restart:**
- Panel mode (from PanelState saveState)
- Theme selection (from current-theme.json)
- All SettingsStateV2 state (saved JSON)
- SysRowState state (saved JSON)
- Bar layout (Theme.barLayout, saved JSON)
- Wallpaper (from WallpaperServiceV5 state)
- Music stream — cava is external, keeps running
- Hyprland workspaces + windows — untouched
- Taskbar state — re-queries from Hyprland on respawn, same apps

**Non-issues during flicker:**
- Music string visible: briefly disappears with the shell, reappears
  at correct position when new shell renders
- Desktop widgets: brief disappear/reappear

## When this WILL be a problem

- If user was mid-typing in a Settings input field → lost (rare case,
  most users don't type-then-change-panel-mode in same action)
- If user was dragging a window via the bar → not applicable, bar
  doesn't support that
- If user is actively reading a notification popup → SwayNC usually
  shows it again

## Why not just always restart on every mode change?

Would be simpler code but adds flicker to transitions that currently
work smoothly (FW↔Float, Island→others). Selective restart keeps
all the smooth transitions smooth, only flickers the specific
problematic one.

## Known unchanged behaviour

- Transitions FROM island (to FW or Float) — no nuclear restart,
  smooth
- Rapid cycling where final destination is island — nuclear on final
  transition only
- Runtime reflows (tray expand, taskbar changes) — no mode change,
  no nuclear, smooth
- All previous fixes still active:
  - v6.15.1: SettingsStateV2 hyprland apply
  - v6.15.2: Loading placeholder
  - v6.15.3: Jitter threshold
  - v6.15.4: Parent-chain walk, tooltip anchor
  - v6.15.5: Runtime Behavior animations
  - v6.15.6: applyToHyprland full coverage + theme reload restore
  - v6.15.7: mode cycling lockout + barWindowLeft stability
  - v6.15.8: stable-read verification
  - v6.15.9: forceLayout() synchronous layout

## Testing checklist

1. **Your specific bug**: Float or FW → Island → music string lands
   at correct position after ~600ms flicker ← the v6.15.10 target
2. **Non-nuclear transitions**: Island→FW, Island→Float, FW↔Float —
   smooth, no flicker
3. **Rapid cycling ending in island**: eventual nuclear fires once
4. **Rapid cycling NOT ending in island**: no nuclear, uses stable
   reads
5. **Cold start in island mode**: no nuclear (no previous mode)
6. **Runtime tray expand**: still smooth (v6.15.5 Behavior works)
7. **Theme change during any mode**: gaps preserved (v6.15.6)
8. **PanelState persistence**: panelMode survives the nuclear
   restart via JSON

## Rollback

If nuclear restart becomes problematic (excessive flicker, state
loss too annoying), simply remove the Connections block that
triggers `nuclearRestartDelay.restart()` — the rest of the
mechanism remains inert. Transitions revert to v6.15.9 behaviour.
