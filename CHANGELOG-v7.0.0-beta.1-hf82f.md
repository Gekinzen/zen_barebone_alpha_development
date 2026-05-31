# v7.0.0-beta.1-hf82f — Taskbar drag-to-reorder pinned apps

**Channel:** beta (hotfix patch on hf82e)
**Released:** 2026-05-24
**Branch:** `dev`
**Scope:** 2 files (Taskbar.qml + ZenVersion.qml)

---

## User request

> "pwd gawin yun taskbar ko dito sa qml bar draggable yun mga icons ? and please gawin smooth yun pag drag ah responsively"

The pinned app icons in the taskbar (kitty, brave, code, steam, discord, FileZilla, Brave Beta, Settings, etc — see screenshot) are now drag-to-reorder. Pick up an icon, drag it past its neighbors, drop it where you want it.

Pulled forward from the P0 immediate slot of the roadmap — was queued for hf83-87 but the user surfaced it directly.

---

## How it works

**Engage drag:**
- Press-and-hold any **pinned** icon for **350 ms**, OR
- Press and move the cursor **8+ px** in any direction.

Both paths fire `_startDrag()`. The 350 ms hold catches users who slow-roll the gesture, the 8 px nudge catches users who go straight into a decisive drag.

**While dragging:**
- The picked-up icon lifts: `z: 100`, `scale: 1.08`, `opacity: 0.92`. Cursor changes to `Qt.ClosedHandCursor`.
- The icon follows the cursor 1:1 with no animation delay (no `Behavior on x` on the dragged item).
- Neighbor icons animate aside in real time via `Behavior on x { NumberAnimation { duration: 180; easing.OutCubic } }` as the drag-target index changes.
- Window-list popups and context menus dismiss to keep the bar visually clean.

**Drop:**
- Release the mouse button → `_endDrag(true)` → reorders `pinnedApps` + fires `savePinned()` immediately. Persistence lands at `Quickshell.dataPath("pinned-apps.json")`.
- Cancel (`onCanceled` — focus loss, Esc) → `_endDrag(false)` → no save, icon snaps back via the same Behavior on x animation.

**Constraints:**
- Only pinned apps reorder. Running-but-not-pinned icons (the ones that appear at the end of `appList`) don't participate — their press behavior is normal click handling. Right-click → "Pin to taskbar" first if you want them in the order.
- One drag at a time (one cursor, one drag).
- Drag is clamped to taskbarRow bounds — the icon cannot escape the bar.
- Click handler is guarded with `if (ma._dragStarted) return` so a press-hold-release doesn't ALSO fire a click after the drop.

---

## Architectural change

`taskbarRow` switched from **`RowLayout`** to plain **`Item`** with manual positioning.

The previous structure was:
```qml
RowLayout {
    id: taskbarRow
    spacing: 4
    Repeater {
        model: taskbarRoot.appList
        Rectangle {
            id: appBtn
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            // ...
        }
    }
}
```

`RowLayout`'s `Layout.preferred*` properties are non-negotiable: any attempt to override `x` on a child during drag is undone on the next layout pass. Smooth drag is impossible without bypassing the layout.

The new structure:
```qml
Item {
    id: taskbarRow
    implicitWidth: N * (btnSize + btnSpacing) - btnSpacing
    height: 40
    Repeater {
        model: taskbarRoot.appList
        Rectangle {
            id: appBtn
            width: 40
            height: 40
            x: isDragging
               ? (cursorX - grabOffset)              // follows cursor
               : effectiveIndex * (40 + 4)           // layout slot
            Behavior on x {
                enabled: !appBtn.isDragging
                NumberAnimation { duration: 180; easing.OutCubic }
            }
        }
    }
}
```

Each icon computes its slot x from its `effectiveIndex` (which accounts for neighbors shifting during drag). The `Behavior on x` is the smooth-slide animation; it's disabled on the dragged icon itself so it tracks the cursor 1:1 with no lag.

`effectiveIndex` shifts neighbors when another icon is being dragged over their slot:
- Drag RIGHT: items in (start+1 .. curr) shift LEFT by one slot to fill the gap.
- Drag LEFT: items in (curr .. start-1) shift RIGHT by one slot.
- Items outside the affected range stay put.

Visual result: as the user drags, neighbors slide around the dragged icon in real time. On drop, the dragged icon's `isDragging` flips to false, its x snaps to the new `effectiveIndex` slot via the Behavior animation, and `savePinned()` commits the new order.

---

## What didn't break

The drag is a **purely additive layer** on top of the existing MouseArea click handling. Every existing behavior is preserved:

- Left-click → launch (if not running) / raise single window / open window-list popup (if multiple windows)
- Right-click → context menu (pin/unpin, new window, close all)
- Middle-click → unchanged (no handler)
- Window count badge → unchanged
- Workspace badge ("1,3") → unchanged (still anchored to parent.right/bottom)
- Minimize underline indicator → unchanged
- Overflow chevron scroll → unchanged (chevrons are siblings of taskbarRow, not children, so the Item/RowLayout swap doesn't affect them)
- Theme sync (ThemeService.blue active, ThemeService.bg3 hover, etc.) → unchanged
- Frosted background → unchanged
- Click-outside-to-dismiss popups → unchanged
- Live `pinnedApps` updates from external sources (programmatic pin/unpin) → unchanged

The only Layout-managed thing inside `taskbarRow` was the icons themselves; the chevrons + viewport are still in a `RowLayout` outer container, so the bar's overall structure is identical.

---

## Patched files

| File | hf82e | hf82f | Δ | Why |
|---|---:|---:|---:|---|
| `Taskbar.qml` | 948 | 1282 | +334 | Drag state on root, Item-based positioning, MouseArea state machine, effectiveIndex shift logic, drop commit + cancel paths |
| `ZenVersion.qml` | 110 | 110 | +0 | hf82e → hf82f string bumps |

All other files at their current versions (hf82e for QML, v6.13 for `zen-screenshot.sh`).

---

## Install

Drop-in over hf82e:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82f-patch-only.tgz

cp zen-shell-v7.0.0-beta.1-hf82f/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

After reload:
1. Press-and-hold any pinned icon for ~350 ms (or press + drag immediately) → icon lifts, follows cursor.
2. Drag horizontally past neighbors → neighbors slide aside smoothly.
3. Release → new order saved. Restart shell to confirm persistence.
4. Cancel mid-drag (move cursor off the bar / Esc) → icon snaps back.
5. Short click → unchanged: launches / raises / popup.
6. Right-click → unchanged: context menu.
7. Settings → User Profile → System Information → `v7.0.0-beta.1-hf82f · released 2026-05-24`.

Verify persistence by hand:

```fish
cat ~/.local/share/quickshell/zen-shell/pinned-apps.json
# Should show the new order: {"pinned":["brave","code","kitty",...]}
```

---

## Wala tayong babawasan

Three behavioral changes:

1. **`taskbarRow` is now an `Item`, not a `RowLayout`.** The computed implicitWidth matches what RowLayout would have produced (N * (btnSize + btnSpacing) - last spacing), so the parent viewport's clip + overflow detection see the same width.
2. **`appBtn` icons are positioned via `x: effectiveIndex * slotW`** instead of via the layout system. Same visual result when no drag is active. Smooth slide animation when drag is active. Click handling unchanged.
3. **MouseArea now has a drag state machine** with `pressHoldTimer` + `_dragArmed` + `_dragStarted` flags. Click handler is guarded so the click doesn't fire if drag engaged.

Zero removals. Headers bumped on both touched files.

---

## Known limitations / open threads

- **Overflow + drag interaction.** If you have so many pinned apps that the overflow chevron scroll is active (`taskbarRow.implicitWidth > maxVisibleWidth = 440`), the drag still works but the dragged icon's clamp range is the full taskbarRow width, not the visible viewport. Result: you can drag an icon "into" the clipped region. Edge case for users with 12+ pinned apps; can ship a follow-up that auto-scrolls during edge-hover if you hit this.
- **Cross-monitor drag.** The taskbar lives on the active monitor; dragging an icon doesn't move it to another monitor's bar (there's only one shared `pinnedApps` array anyway, so this would be a no-op even if attempted).
- **Touch input.** The drag uses standard `MouseArea` press/move/release, which Qt also synthesizes from touch. Not specifically tested on touchscreen but should work.
- **Drag during a window-list popup.** The drag dismisses any open popup on engage. If the user was in the middle of clicking inside the popup, that click registers normally (the popup is a separate Wayland surface and dismisses only via its own handlers or via `taskbarRoot.popupAppId = ""`).
