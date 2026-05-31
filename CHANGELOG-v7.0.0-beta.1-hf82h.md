# v7.0.0-beta.1-hf82h — WorkspaceOverview first-open race fix

**Channel:** beta (hotfix patch on hf82g)
**Released:** 2026-05-24
**Branch:** `dev`
**Scope:** 2 files (WorkspaceOverview.qml + ZenVersion.qml)

---

## User report

> "yung super + tab show workspace unang execute ko dun wala laman tas pangalawa execute ulit dun palang lalabas"

First Super+Tab after shell start shows the Workspace Overview empty — no workspace tiles, or empty tile content. Press Esc to close, press Super+Tab again, NOW it shows the workspaces and windows correctly.

---

## Root cause — same family as hf82d sticky-note race

QML visibility-propagation race. The existing handler in `WorkspaceOverview.qml` was:

```qml
onVisibleChanged: {
    if (visible) {
        _refresh()
        // ... select current workspace ...
        if (workspacesList.length === 0) {
            _retryTimer.start()  // 250ms retry
        }
    }
}
```

This watches the Rectangle's OWN `visible` property. The Rectangle's `visible` is `true` by default and never reassigned. When the parent `PanelWindow.visible` flips (driven by `PanelState.workspaceOverviewVisible`), the inner Rectangle's effective rendering changes — but its `visible` property doesn't get reassigned.

**QML's visibility model:** parent visibility cascades down to children's effective rendering, but the child's own `visible` PROPERTY value doesn't change. So `visibleChanged` doesn't always emit on the child when parents flip. The exact behavior depends on QML version + Quickshell's PanelWindow + Wayland layer-shell timing.

**The asymmetric trigger pattern** that produces the user's exact bug:

1. **Shell start.** `PanelState.workspaceOverviewVisible = false`. PanelWindow.visible = false. Rectangle is mounted by `Variants { model: Quickshell.screens }` immediately — `Component.onCompleted` fires, but no `_refresh()` call there. Rectangle's own `visible = true` (default).
2. **First Super+Tab.** `workspaceOverviewVisible = true` → PanelWindow.visible flips false → true. Rectangle's effective rendering goes from hidden → visible. BUT — the Rectangle's own `visible` property never got reassigned (it was always true). No `visibleChanged` signal fires. `_refresh()` never runs. workspacesList stays `[]`. Empty overview.
3. **Close (Esc / click outside).** `workspaceOverviewVisible = false` → PanelWindow.visible = false. THIS cascade DOES propagate down — the Rectangle's `visible` gets set to false via parent-to-child cascade. `visibleChanged` fires with `visible === false`. Handler exits early (the `if (visible)` guard).
4. **Second Super+Tab.** Rectangle's `visible` flips from false → true. NOW `visibleChanged` fires properly. `_refresh()` runs. Populated.

The asymmetry: parent-to-child cascade SETS the child's visible (visible → false). When parent goes invisible-to-visible again, the child's visible was already false (set by the cascade) — so going back to true DOES register as a property change. That's why second open works.

But the first close → first reopen cycle is required to get the property "into sync" with parent. The first ever open finds the property already at true (default) so no change registers.

---

## Fix — three layers, defensive

### Layer 1 (primary): subscribe to `PanelState.workspaceOverviewVisible`

This is the singleton property that the toggle keybind / hot corner / IPC all mutate. As a Singleton's plain `property bool`, it ALWAYS emits its changed signal when reassigned. No visibility-propagation race.

```qml
Connections {
    target: PanelState
    function onWorkspaceOverviewVisibleChanged() {
        if (PanelState.workspaceOverviewVisible) {
            overview._onOverviewOpened()
        } else {
            overview.moveMenuVisible = false
        }
    }
}
```

`_onOverviewOpened()` is a factored-out function containing what the old `onVisibleChanged` body did — refresh, select current workspace, fire retry. Idempotent and safe to call multiple times (the second Super+Tab path also still hits it via the legacy `onVisibleChanged` handler, which is kept as a backup).

### Layer 2 (backup): `Component.onCompleted`

Handles the hypothetical case where the Rectangle mounts at a moment when `PanelState.workspaceOverviewVisible` is already `true` (e.g., if shell.qml is reloaded while the overview is open).

```qml
Component.onCompleted: {
    if (PanelState && PanelState.workspaceOverviewVisible) {
        _onOverviewOpened()
    }
}
```

### Layer 3 (data-arrival catchers)

Even if `_refresh()` runs at the right time, the data it reads may not be ready. Two new `Connections` blocks watch the Hyprland module data for live updates:

```qml
Connections {
    target: Hyprland.toplevels
    function onValuesChanged() {
        if (PanelState && PanelState.workspaceOverviewVisible) {
            overview._refreshTick++
        }
    }
}

Connections {
    target: Hyprland.workspaces
    function onValuesChanged() {
        if (PanelState && PanelState.workspaceOverviewVisible) {
            overview._refresh()
            overview._refreshTick++
        }
    }
}
```

These also handle the case where the user creates / closes a window or workspace while the overview is open — tiles refresh in real time.

### Layer 4: unconditional 250ms tick

The hf79 retry timer only fired when `workspacesList.length === 0`. But workspaces typically populate fast (Hyprland exposes them on initial sync); the slower data is `Hyprland.toplevels` (window info). If workspaces are populated but toplevels are not, the existing retry doesn't fire and tile windows stay empty.

A new `_refreshTickTimer` fires 250ms after every overview open, regardless of `workspacesList` content, so the second-pass tile re-read always happens. Cheap no-op if windows were already correct.

### Layer 5: tile delegates also subscribe to PanelState

The inner tile `Connections` already had `onVisibleChanged` and `on_RefreshTickChanged` handlers reading `overview.visible` and `overview._refreshTick`. Same `overview.visible` race applies inside the Repeater delegate. Added a third `Connections` block subscribing to `PanelState.workspaceOverviewVisible` directly so per-tile `windows` array refreshes reliably on first open:

```qml
Connections {
    target: PanelState
    function onWorkspaceOverviewVisibleChanged() {
        if (PanelState.workspaceOverviewVisible) {
            wsTile.windows = overview._windowsFor(modelData.id)
        }
    }
}
```

---

## Why so many layers?

Single-shot fixes for this kind of race typically fail in adjacent cases. The hf79 attempt added the retry timer alone — solved one case (empty workspaces), missed another (workspaces present, toplevels empty). The hf82h approach covers:

- First-open race (Layer 1: PanelState Connections)
- Shell-reload-while-open edge case (Layer 2: Component.onCompleted)
- Live data updates mid-view (Layer 3: toplevels/workspaces Connections)
- Slow-data scenario where Hyprland still streaming on shell start (Layer 4: unconditional retry)
- Tile-level same race (Layer 5: per-tile PanelState Connections)

Each layer is small (a few lines), idempotent (safe to fire multiple times), and well-scoped (only acts when `PanelState.workspaceOverviewVisible === true`). Net cost: a handful of small Connections blocks, no removal of any existing path.

The legacy `onVisibleChanged` handler is preserved as a no-op-safe alternate trigger — both paths now route through the same `_onOverviewOpened()` factored function, so calling twice just runs the (cheap, idempotent) refresh twice.

---

## Patched files

| File | hf82g | hf82h | Δ | Why |
|---|---:|---:|---:|---|
| `WorkspaceOverview.qml` | 569 (alpha.14-hf4) | 758 | +189 | 5 defensive layers + factored `_onOverviewOpened()` + extensive comments |
| `ZenVersion.qml` | 110 | 110 | +0 | hf82g → hf82h string bumps |

---

## Install

Drop-in over hf82g:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82h-patch-only.tgz

cp zen-shell-v7.0.0-beta.1-hf82h/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

After reload, verify:

1. **First Super+Tab after fresh shell start** should immediately show all workspaces + their window cards. No empty state, no need to close+reopen.
2. **Subsequent Super+Tab presses** continue working exactly as before.
3. **Live update test:** open the overview, then open/close a window in another monitor — the corresponding tile should update its window cards within a frame or two without needing to close+reopen.
4. **Switch workspace from overview** still works (click any tile).
5. **Right-click → move-to-workspace** menu still works.
6. **Keyboard nav** (arrows / Enter / 1-9 / Esc after first click) still works.
7. Settings → User Profile → System Information → `v7.0.0-beta.1-hf82h · released 2026-05-24`.

---

## Wala tayong babawasan

All existing behavior preserved. The old `onVisibleChanged` handler is intact (kept as belt-and-braces backup, calls the same idempotent `_onOverviewOpened()`). The hf79 `_retryTimer` is intact. The `_refreshTick` mechanism is intact. New layers are purely additive.

Five new Connections blocks (2 on the overview Rectangle, 1 on the tile delegate), 1 new Timer (`_refreshTickTimer`), 1 new Component.onCompleted, 1 factored helper function (`_onOverviewOpened()`). Zero removals.

---

## Pattern: class of bugs uncovered

This is the **third bug** in the hf82 series caused by the same QML "parent.visible flips but child.visible property doesn't reassign" race:

| Bug | Where | Hotfix | Fix pattern |
|---|---|---|---|
| Sticky note opens blank on first show | QuickNotesSticky + DesktopStickyNotes | hf82d | `Connections { target: stickyWindow; onNoteChanged } + onVisibleChanged` |
| Calendar list shows duplicate `📅 YYYY-MM-DD` instead of titles | ZenNotificationCenter calendar repeater | hf82e | Per-row `loadBody()` trigger + `(loading…)` fallback |
| Workspace overview empty on first Super+Tab | WorkspaceOverview | hf82h | `Connections { target: PanelState; onWorkspaceOverviewVisibleChanged }` + factored helper |

Common shape: a Repeater / TextArea / similar QML construct initializes its state in `Component.onCompleted` reading from a singleton service, but the singleton hasn't loaded data yet OR the visibility-propagation chain doesn't fire the change signal the handler depends on.

**Pattern to apply preemptively across the codebase:** any QML component that depends on a singleton service's data should:
1. Subscribe to that service's `Connections` directly, not rely on parent visibility cascade
2. Have a `Component.onCompleted` initial-read for the "already populated" case
3. Have a 250ms retry timer for the "data not ready yet" case
4. Be idempotent — re-reading the same data should be cheap

Documented as an open thread for a codebase-wide audit pass in the next session.

---

## Open threads still active

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting (`--screen N`)
- Drag + overflow auto-scroll (12+ pinned apps edge case)
- Build-time version auto-derivation (`git describe`)
- `Component.onCompleted` race audit across the codebase — pattern now confirmed in 3 places (QuickNotesSticky / DesktopStickyNotes hf82d, ZenNotificationCenter list hf82e, WorkspaceOverview hf82h). Likely more lurking.
