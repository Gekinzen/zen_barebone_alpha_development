# v6.16.4.12.6.53 — Hiraki (開き) · hotfix 1

**Channel:** alpha
**Release date:** 2026-04-29
**Branch:** `alpha-v6.16.4.12.6.53`
**Predecessor:** v6.16.4.12.6.52 — Hiraki (開き)

## Summary

Two follow-up fixes on top of the v6.16.4.12.6.52 click-to-open drop.
Both reported against .52:

1. The new Clock.qml was being silently overwritten on every install
   by `install.sh`'s size-aware auto-applier, leaving the clock
   non-clickable. Manual copy worked because it bypassed the
   auto-applier.
2. The calendar popup appeared near the screen's right edge instead
   of directly above the clock module.

Codename stays on **Hiraki** (開き). This is a hotfix within the
Hiraki cycle — version bumped from .52 to .53, no codename rotation.

## Files changed

| File | Change |
|---|---|
| `install.sh` | The `ZenClock.qml:Clock.qml` pair removed from the size-aware auto-applier loop. Pair entry preserved as a comment block for reference. Banner echo and top-of-file version echo bumped to v6.16.4.12.6.53. |
| `zen-shell-v5/Clock.qml` | New `reportPositionToPanelState()` function — computes the clock's global screen-X (center and right edge) using `mapToItem(null, ...)` and the same panel-mode offset reconstruction the StartMenu uses. Called from `onClicked` BEFORE toggling the calendar. Header bumped. |
| `zen-shell-v5/PanelState.qml` | Two new runtime properties — `clockCenterX` (-1 sentinel) and `clockRightEdgeX` (-1 sentinel) — plus the `reportClockPosition(centerX, rightX, sw)` function. Sits next to the existing `reportStartButtonPosition` plumbing. Not persisted. |
| `zen-shell-v5/shell.qml` | `calendarWindow.margins.right` is now a binding instead of the hardcoded `12`. Computes `screenW - clockRightEdgeX`, clamped between `12` and `screenW - implicitWidth - 12`. Falls back to `12` when the clock hasn't reported a position yet. |
| `zen-shell-v5/ZenVersion.qml` | `version` → v6.16.4.12.6.53, `versionRaw` → 6.16.4.12.6.53. Codename unchanged (still Hiraki). |
| `README.md` | New "What's new in Hiraki hotfix 1" section, codename history table updated, Hikari version timeline table extended. |

## Detail — install.sh auto-applier fix

### Reproduction (.52)

1. User extracts `zen-shell-v6_16_4_12_6_52-hiraki.tgz`.
2. User runs `./install.sh`.
3. install.sh copies all QML files from the tarball into
   `~/.config/quickshell/zen-shell/` (this includes the new 10KB
   `Clock.qml` AND the legacy 43KB `ZenClock.qml`).
4. The "auto-applying bar modules" step runs the size-aware
   diff/sync loop. For the `ZenClock.qml:Clock.qml` pair:
   - `src_size = 43000` (legacy ZenClock.qml)
   - `dst_size = 10000` (new Clock.qml)
   - `ratio = src_size * 100 / dst_size ≈ 430`
   - `ratio ≥ 80` → take src→dst path → **the new Clock.qml is
     overwritten by the legacy ZenClock.qml.**
5. User restarts the shell. The clock is non-clickable because
   the legacy ZenClock.qml has different binding plumbing
   (different MouseArea structure, different signal pathway to
   the calendar window).
6. User runs `cp Clock.qml ~/.config/quickshell/zen-shell/Clock.qml`
   manually after the install completes. This works — the
   auto-applier doesn't run again until the next install.

### Root cause

The size-aware heuristic was added in v6.16.4.12.6.13 to keep
`Clock.qml` and `ZenClock.qml` in lockstep during the early Hikari
development cycle, when the two modules were near-identical
near-clones in active sync. Hikari (.51) forked them: `Clock.qml`
became a small focused module (10KB) sourced from
`CalendarButton.qml`, while `ZenClock.qml` stayed as the legacy
big module (43KB) for back-compat. The heuristic — written
assuming the two files were always close in size — now does the
exact wrong thing: the legacy file is much bigger, so it wins the
"canonical" decision and clobbers the new module.

### Fix

The `ZenClock.qml:Clock.qml` pair is removed from the
auto-applier loop entirely:

```bash
# Before (.52):
for pair in "ZenClock.qml:Clock.qml" "ZenWorkspaces.qml:Workspaces.qml" "ZenSysMonitor.qml:SysMonitor.qml"; do
    # ... size-aware sync ...
done

# After (.53):
for pair in "ZenWorkspaces.qml:Workspaces.qml" "ZenSysMonitor.qml:SysMonitor.qml"; do
    # ... size-aware sync (Workspaces/SysMonitor only) ...
done

# Clock.qml is now ALWAYS taken straight from the tarball — no
# size heuristic, no ZenClock.qml pairing.
if [ -f "$SHELL_DIR/Clock.qml" ]; then
    echo "      Clock.qml installed direct from tarball (no auto-applier — Hikari/Hiraki canonical)"
fi
```

The pair entry is preserved as a comment block in install.sh for
reference. The Workspaces and SysMonitor pairs still go through
the heuristic since those modules haven't diverged the same way.

## Detail — calendar popup positioning

### Before (.52)

```qml
// shell.qml — calendarWindow
anchors.right: true
implicitWidth: 330
margins.right: 12        // ← always 12px from screen's right edge
```

The popup's right edge always sits 12px from the screen's right
edge. Visually correct in the common case (clock IS the rightmost
module in the right zone), but wrong whenever:

- User adds a system tray, weather widget, or any module to the
  right of the clock — popup floats away from its trigger.
- User changes panel mode (island / floating / fullwidth) — the
  bar's actual screen-X offset changes; popup doesn't follow.
- User has a multi-monitor setup with mixed widths — popup
  position visually inconsistent across monitors.

### After (.53)

#### Step 1 — Clock.qml reports its screen-space position

```qml
function reportPositionToPanelState() {
    const win = QsWindow.window
    if (!win) return

    const screenW = win.screen ? win.screen.width  : 1920
    const screenH = win.screen ? win.screen.height : 1080

    // Map clock's local coords into bar-window-local coords.
    const localCenter = root.mapToItem(null, root.width / 2, root.height / 2)
    const localRight  = root.mapToItem(null, root.width,     root.height / 2)

    // Reconstruct the bar window's actual screen X offset (layer
    // shell windows always report win.x = 0). Mirrors the StartMenu
    // pattern.
    let barScreenX = 0
    if (PanelState.panelMode === "island") {
        const barW = win.width || screenW
        barScreenX = (screenW - barW) / 2
    } else if (PanelState.panelMode === "floating") {
        barScreenX = PanelState.panelMarginSide
    }

    const globalCenterX = barScreenX + localCenter.x
    const globalRightX  = barScreenX + localRight.x

    PanelState.reportClockPosition(globalCenterX, globalRightX, screenW)
}

MouseArea {
    onClicked: (mouse) => {
        // ... right-click handler ...
        root.reportPositionToPanelState()    // ← NEW
        // ... toggle calendar ...
    }
}
```

#### Step 2 — PanelState.qml stores it

```qml
// New runtime properties (not persisted)
property real clockCenterX:    -1   // -1 = unknown sentinel
property real clockRightEdgeX: -1

function reportClockPosition(centerX: real, rightX: real, sw: int) {
    clockCenterX    = centerX
    clockRightEdgeX = rightX
    if (sw > 0) screenWidth = sw
}
```

#### Step 3 — shell.qml's calendarWindow consumes it

```qml
margins.right: {
    const sw = (PanelState.screenWidth > 0) ? PanelState.screenWidth : 1920
    if (PanelState.clockRightEdgeX <= 0) return 12   // unreported → fallback
    const want    = sw - PanelState.clockRightEdgeX
    const maxRight = sw - calendarWindow.implicitWidth - 12
    return Math.max(12, Math.min(want, maxRight))
}
```

### Layout math walkthrough

With `anchors.right: true`, the popup's right edge sits at
`screenW - margins.right`. We want that edge to align with the
clock's right edge:

```
margins.right = screenW - clockRightEdgeX
```

Then clamp:

- `margins.right >= 12` — always at least 12px from screen right.
  Prevents popup from clipping off the right edge of the screen
  if the clock is somehow positioned out-of-bounds.
- `margins.right <= screenW - 330 - 12` — popup's left edge stays
  at least 12px inside the screen. Prevents the 330px-wide popup
  from overflowing the left edge on narrow monitors or when the
  clock sits very close to the screen's right edge.

### Edge cases handled

| Scenario | Outcome |
|---|---|
| Clock not yet clicked since shell start | `clockRightEdgeX == -1` → fallback to historical `12` |
| Clock at far right of screen (right edge ≈ screenW) | `want ≈ 0`, clamped to `12` |
| Clock at far left of screen (right edge < 342) | `want > screenW - 342`, clamped to `screenW - 342` |
| Bar moved between top and bottom | `anchors.top`/`anchors.bottom` switches handle vertical; `margins.right` independent |
| Multi-monitor (different widths) | `screenW` carried in the report — each monitor's calendar window uses its own `clockRightEdgeX` |
| Bar layout rearranged at runtime | Position reported on next click — popup follows on next open |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.6.53
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

If the user previously hand-copied `Clock.qml` into
`~/.config/quickshell/zen-shell/` to work around the .52 install
bug, that copy is no longer needed in .53 — the tarball Clock.qml
is now installed directly.

## Rollback

To revert to .52 behaviour (broken installer + screen-edge popup):

1. Restore the `ZenClock.qml:Clock.qml` pair to the for-loop in
   `install.sh`.
2. Restore the hardcoded `margins.right: 12` in `shell.qml`.
3. Drop the `reportPositionToPanelState` function call from
   `Clock.qml`'s `onClicked` (the function itself is harmless to
   leave on disk — it's only invoked from one place).
4. Drop the `clockCenterX`/`clockRightEdgeX` properties and
   `reportClockPosition` function from `PanelState.qml`.

## Carry-forward from Hiraki .52

- Click-to-open Clock module (no hover open) — preserved verbatim
- Click-to-open StartMenu — preserved
- `z: 1` on Clock and StartMenu — preserved
- Wheel-month cycling only when calendar already open — preserved
- Plugin manager temporarily hidden — preserved
