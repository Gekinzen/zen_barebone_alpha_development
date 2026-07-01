import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/*
 * Taskbar.qml v7.0.0-beta.1-hf82g — Karui (軽い)
 *
 * v7.0.0-beta.1-hf82g — UNIVERSAL DRAG-TO-REORDER.
 *
 *   User report:
 *   "sa taskbar sa dulo last 2 icons hindi ko ma drag"
 *
 *   The hf82f drag implementation only enabled reorder for pinned
 *   apps. Running-but-not-pinned icons (which sit at the end of
 *   appList per the appList computation order) could not be picked
 *   up. The user expected every icon to be draggable, matching how
 *   GNOME / KDE / Windows 11 / Plasma all behave.
 *
 *   Fix: drag now accepts ANY icon. When you start dragging a
 *   running-but-not-pinned icon, it's auto-pinned to enable the
 *   reorder. If you cancel the drag, the auto-pin is reverted; the
 *   icon goes back to running-but-not-pinned. If you drop, the new
 *   pin sticks at the dropped position.
 *
 *   _dragAutoPinned flag added on taskbarRoot to track this state.
 *   _startDrag() pinApp()s if needed and reads the fresh pinnedIndex.
 *   _endDrag(false) calls unpinApp() to restore prior state.
 *
 * v7.0.0-beta.1-hf82f — drag-to-reorder for pinned apps.
 *
 *   User request:
 *   "pwd gawin yun taskbar ko dito sa qml bar draggable yun mga
 *    icons ? and please gawin smooth yun pag drag ah responsively"
 *
 *   Press-and-hold any pinned icon for 350 ms (or press + move 8+ px)
 *   to engage drag. Drag horizontally to reorder; neighbors animate
 *   aside in real time. Release to commit (savePinned fires). Esc /
 *   focus loss cancels with a smooth snap-back.
 *
 *   Only pinned apps reorder. Running-but-not-pinned apps appear
 *   after pinned ones in appList and don't participate in drag —
 *   pin them first (right-click → Pin to taskbar) if you want them
 *   in the order.
 *
 *   Architectural change: taskbarRow switched from RowLayout to a
 *   plain Item with manual x positioning per icon. RowLayout's
 *   Layout.preferred* properties are non-negotiable and fight any
 *   x override on the next layout pass, which made smooth drag
 *   impossible. With Item-based positioning, each icon computes
 *   its slot x from its effectiveIndex and animates through
 *   Behavior on x. The dragged icon overrides its own x to follow
 *   the cursor with z-lift + scale + opacity for the picked-up feel.
 *
 *   Wala tayong babawasan — every existing behavior (click to
 *   launch/raise, right-click context menu, middle-click new window,
 *   window count badge, workspace badge, minimize indicator, popup
 *   window list, overflow scroll, theme sync, frosted background)
 *   is preserved. Drag is a purely additive layer on top of the
 *   existing MouseArea click handling.
 *
 * v6.16.4.12.6 (Hikari · Frosted)
 *
 * v6.16.4.12.6:
 *   - Background switched to ThemeService.bg0 @ alpha 0.32 so it falls
 *     below Hyprland's `ignore_alpha 0.5` blur threshold for the
 *     zen-shell-bar layer. Frosted look matches the rest of the bar.
 *   - Close path is now graceful-then-pkill: requestClose() fires first
 *     (preserves "Save changes?" dialogs in well-behaved apps), then a
 *     250 ms watchdog calls `pkill -f <appId>` if the toplevel is still
 *     alive. Per-window close (the X button in the popup) keeps just
 *     the graceful path because pkill -f the appId would also kill
 *     sibling windows. Wala tayo babawasan — old safeClose preserved.
 *
 * v6.12: Fixed context menu — removed HyprlandFocusGrab that killed
 * popups before clicks could register. Added overflow auto-collapse
 * with < > chevron scroll buttons when too many apps are open.
 *
 * v6.9: Fixed close — uses Toplevel.requestClose() (Quickshell Wayland API)
 * instead of .close() which silently fails. Also falls back to hyprctl
 * dispatch closewindow if requestClose isn't available.
 *
 * Features: grouped apps, pinned apps persistence, window list popup,
 * context menu (pin/unpin, new window, close all), window count badge,
 * overflow scroll with chevron indicators.
 */
Rectangle {
    id: taskbarRoot

    // v7.0.0-beta.1-hf91: explicit vertical mode (end-4 style). When the
    // bar is zenVertical, BarVertical sets `vertical: true` on this module
    // and the icon strip becomes a COLUMN (slot axis = y, drag = y,
    // overflow = zenVertical). Default false → byte-identical horizontal
    // behavior for the top/bottom bar.
    property bool zenVertical: false

    // v6.12: maxVisibleWidth caps how wide the taskbar can grow.
    // Beyond this, chevron < > buttons appear and content scrolls.
    // v7.0.0-beta.1-hf95.31 — now driven by the PanelState slider.
    readonly property int maxVisibleWidth: (typeof PanelState !== "undefined"
        && PanelState.taskbarMaxWidth > 0) ? PanelState.taskbarMaxWidth : 440
    // v7.0.0-beta.1-hf95: vertical equivalent — caps how TALL the taskbar
    // column can grow before ▲/▼ scroll chevrons appear. Without this, a
    // long app list pushed the other bar modules (clock!) off-screen.
    readonly property int maxVisibleHeight: 360
    // v7.0.0-beta.1-hf84: content scales with the bar when Fit-contents
    // is on (Theme.barContentScale is 1.0 otherwise, so sizes are
    // identical to before for existing users). btnSize drives every
    // icon slot position, so scaling it reflows the whole taskbar.
    // v7.0.0-beta.1-hf88: btnSize + root height now track
    // Theme.moduleHeight so the taskbar lines up at the SAME height as
    // every other module (music widget, clock, sysrow, workspaces) —
    // uniform bar height. moduleHeight already folds in barContentScale.
    readonly property real _fit: (typeof Theme !== "undefined" && Theme.barContentScale)
                                 ? Theme.barContentScale : 1.0
    // v7.0.0-beta.1-hf95.30 — icons FLOAT inside the bar with padding all
    // around (same idea as the dock's contentPadding), instead of filling
    // the full bar height edge-to-edge. This leaves room so the window-
    // count / workspace / minimize badges below each icon are visible, and
    // gives the obvious floating look. ~7px each side keeps the icon a
    // sensible size on a typical ~40px bar (icon ≈ 26px) while clearly
    // floating; scales with the fit factor.
    readonly property int iconPadding: Math.round(7 * _fit)
    // btnSize was Math.round(Theme.moduleHeight) (full bar height). Now it
    // is the bar height MINUS padding top+bottom, so each icon sits in a
    // floating box with breathing room.
    readonly property int btnSize: Math.max(18, Math.round(Theme.moduleHeight) - iconPadding * 2)
    readonly property int btnSpacing: Math.round(4 * _fit)
    readonly property int chevronWidth: Math.round(24 * _fit)
    // v7.0.0-beta.1-hf95: overflow now handled on BOTH axes.
    readonly property bool hasOverflow: zenVertical
        ? (fullColH > maxVisibleHeight)
        : (taskbarRow.implicitWidth > maxVisibleWidth)

    // Clamp implicitWidth so bar doesn't stretch infinitely.
    // Vertical: the module is a fixed-width COLUMN whose height grows with
    // icon count; horizontal keeps the original width-clamp behavior.
    implicitWidth: zenVertical
        ? taskbarRoot.btnSize
        : Math.min(taskbarRow.implicitWidth + 60, maxVisibleWidth + (hasOverflow ? chevronWidth * 2 + 16 : 0) + 24)
    implicitHeight: zenVertical
        ? (taskbarColH + 8 + (hasOverflow ? chevronWidth * 2 + 8 : 0))
        : Math.round(Theme.moduleHeight)
    height: implicitHeight
    radius: Theme.moduleRadius

    // Full (uncapped) column height for ALL icons stacked.
    readonly property int fullColH: {
        const n = appList.length
        if (n <= 0) return 0
        return n * (btnSize + btnSpacing) - btnSpacing
    }
    // Visible column height — capped to maxVisibleHeight when overflowing
    // (the chevrons + scroll handle the rest), full height otherwise.
    readonly property int taskbarColH: zenVertical
        ? Math.min(fullColH, maxVisibleHeight)
        : fullColH

    // v6.16.4.12.6: Frosted bg — alpha 0.32 lets Hyprland layer blur through
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.32)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.10)

    // Subtle inner highlight for depth
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.04)
        z: 0
    }

    readonly property string nfPin: "\uf0403"
    readonly property string nfUnpin: "\uf0404"
    readonly property string nfClose: "\uf0156"
    readonly property string nfWindow: "\uf024d"

    property var pinnedApps: ["kitty", "firefox", "code"]
    property string popupAppId: ""
    property string ctxAppId: ""

    // ═══════════════════════════════════════════════════════════════
    // v7.0.0-beta.1-hf82f — TASKBAR DRAG-TO-REORDER
    // ═══════════════════════════════════════════════════════════════
    //
    // User request:
    //   "pwd gawin yun taskbar ko dito sa qml bar draggable yun mga
    //    icons ? and please gawin smooth yun pag drag ah responsively"
    //
    // Reorder rules:
    //   - Only PINNED apps reorder. Running-but-not-pinned apps
    //     trail at the end of the list — they don't participate.
    //     If you drag a running-but-not-pinned icon, nothing happens.
    //   - 350ms press threshold before drag activates. Short clicks
    //     still launch/raise/popup as before — drag only fires when
    //     the user actually wants to reorder, not on every click.
    //   - During drag, the picked-up icon follows the cursor with
    //     z-lift + slight scale + opacity dip for the "picked-up" feel.
    //   - Neighbors animate aside (Behavior on x) as the drag-target
    //     position changes, in real time.
    //   - On drop, pinnedApps is reordered and savePinned() fires
    //     immediately so the new order is persistent across restart.
    //   - Esc / drop-outside cancels the drag (snaps back to original
    //     position via the Behavior on x animation, no save).
    //
    // Wala tayong babawasan — all existing click handling, popup,
    // context menu, minimize restore, badge rendering, scroll
    // chevron, and overflow logic preserved. Drag layer is purely
    // additive.
    //
    // Drag state. All driven from MouseArea press/move/release on
    // the per-icon MouseArea (id: ma); a single drag at a time is
    // possible since you only have one cursor.
    property string _dragAppId: ""        // appId being dragged, "" when idle
    property int    _dragStartIndex: -1   // index in pinnedApps at drag start
    property int    _dragCurrentIndex: -1 // index where drop would land
    property real   _dragCursorX: 0       // taskbarRow-local cursor x while dragging
    property real   _dragOriginX: 0       // pre-drag x of the picked icon, for snap-back
    property real   _dragGrabOffsetX: 0   // cursor offset within icon at press
    // v7.0.0-beta.1-hf91 — zenVertical-mode drag axis (Y) counterparts.
    property real   _dragCursorY: 0       // taskbarRow-local cursor y while dragging (zenVertical)
    property real   _dragGrabOffsetY: 0   // cursor offset within icon at press (zenVertical)
    // hf82g — when set, the dragged app was NOT pinned before drag-
    // start, and we auto-pinned it to enable reorder. If the drag
    // is cancelled (not committed), we unpin to restore the prior
    // pinned/running state. On commit, this flag is cleared.
    property bool   _dragAutoPinned: false

    // Hit-test helper: given a taskbarRow-local x, return the
    // pinned-apps index where the dragged icon should INSERT if
    // dropped right now. Returns a value in [0, pinnedApps.length].
    // Treats the midpoint of each pinned icon as the boundary.
    function _dragHitIndex(localX) {
        const slotW = taskbarRoot.btnSize + taskbarRoot.btnSpacing
        // We only reorder within pinned apps; later (running-only)
        // icons in appList don't accept drops. Clamp to pinned range.
        let idx = Math.round(localX / slotW)
        if (idx < 0) idx = 0
        if (idx > pinnedApps.length - 1) idx = pinnedApps.length - 1
        return idx
    }

    // Apply a reorder: move `pinnedApps[fromIdx]` to position `toIdx`.
    // toIdx is the destination INDEX in the post-move array.
    function _applyReorder(fromIdx, toIdx) {
        if (fromIdx < 0 || fromIdx >= pinnedApps.length) return
        if (toIdx < 0) toIdx = 0
        if (toIdx > pinnedApps.length - 1) toIdx = pinnedApps.length - 1
        if (fromIdx === toIdx) return
        const next = pinnedApps.slice()
        const [moved] = next.splice(fromIdx, 1)
        next.splice(toIdx, 0, moved)
        pinnedApps = next
        savePinned()
    }

    // Drag end — invoked on release. If a valid target landed,
    // commit; either way, clear drag state so the icon snaps back
    // to its layout slot (which may now be the new sorted position).
    //
    // hf82g — if the app was auto-pinned at drag-start (because it
    // was a running-but-not-pinned icon), and the drag is being
    // cancelled (not committed), undo the auto-pin so the user's
    // pin state is restored to what it was before the drag.
    function _endDrag(committed) {
        if (_dragAppId === "") return
        const draggedId = _dragAppId
        const wasAutoPinned = _dragAutoPinned
        if (committed && _dragCurrentIndex >= 0 && _dragStartIndex >= 0) {
            _applyReorder(_dragStartIndex, _dragCurrentIndex)
        } else if (wasAutoPinned) {
            // Cancel — undo the auto-pin we performed at drag-start.
            // This restores the app back to running-but-not-pinned.
            unpinApp(draggedId)
        }
        _dragAppId = ""
        _dragStartIndex = -1
        _dragCurrentIndex = -1
        _dragCursorX = 0
        _dragOriginX = 0
        _dragGrabOffsetX = 0
        _dragCursorY = 0
        _dragGrabOffsetY = 0
        _dragAutoPinned = false
    }
    // ═══════════════════════════════════════════════════════════════

    // v6.12 fix: Removed HyprlandFocusGrab — it was grabbing focus for
    // barWindow only, but PopupWindow is a separate Wayland surface.
    // Clicking the popup triggered onCleared → reset ctxAppId → popup
    // vanished before the MouseArea inside could register the click.
    // Now popups dismiss via their own click handlers + a global dismiss
    // timer that fires on bar-level mouse events outside popup areas.

    // Global dismiss: any left-click on bar background closes popups
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            taskbarRoot.popupAppId = ""
            taskbarRoot.ctxAppId = ""
        }
    }

    property var groupedApps: {
        const groups = {}
        if (ToplevelManager.toplevels && ToplevelManager.toplevels.values) {
            for (const tl of ToplevelManager.toplevels.values) {
                const id = (tl.appId || "unknown").toLowerCase()
                if (!groups[id]) groups[id] = []
                groups[id].push(tl)
            }
        }
        // v7.0.0-beta.1-hf68 — supplement with Hyprland.toplevels.
        //
        // ToplevelManager (wlr-foreign-toplevel-management) may NOT
        // include windows on special workspaces (including
        // special:minimized). Hyprland.toplevels DO include them.
        // Cross-reference by class name to ensure minimized windows
        // still appear in the taskbar as "running" with non-zero
        // windowCount — otherwise the icon disappears when you
        // minimize and you can't click to restore.
        //
        // We add a lightweight shim object (with appId only) for any
        // Hyprland toplevel whose class exists on a special workspace
        // but ISN'T already in groupedApps. The shim is enough for
        // the taskbar to show the icon; actual restore uses hyprctl
        // clients (class-based, not toplevel-based).
        if (typeof Hyprland !== "undefined"
            && Hyprland.toplevels
            && Hyprland.toplevels.values) {
            for (const t of Hyprland.toplevels.values) {
                if (!t) continue
                const cls = ((t.lastIpcObject && t.lastIpcObject.class)
                             || t.class || "").toLowerCase()
                if (!cls) continue
                const wsId = (t.workspace && t.workspace.id) || 0
                if (wsId >= 0) continue   // not on special workspace — already in ToplevelManager
                // This window is on a special workspace. Check if
                // it's already counted in groups (some Quickshell
                // versions DO include special-ws windows in ToplevelManager).
                const existing = groups[cls] || []
                // Use address to deduplicate if available
                const addr = (t.lastIpcObject && t.lastIpcObject.address) || ""
                let isDupe = false
                for (const e of existing) {
                    if (addr && e._hyprAddr === addr) { isDupe = true; break }
                }
                if (!isDupe) {
                    if (!groups[cls]) groups[cls] = []
                    groups[cls].push({
                        appId: cls,
                        title: (t.lastIpcObject && t.lastIpcObject.title) || "",
                        _hyprAddr: addr,
                        _isMinimizedShim: true,   // flag for click handler
                        activate: function() {}    // no-op; use unminimizeByClass
                    })
                }
            }
        }
        return groups
    }

    // v7.0.0-beta.1-hf6: workspace map per app class.
    //
    // Cross-references Hyprland.toplevels (which expose workspace) with
    // the appId from ToplevelManager so the taskbar can show "ws 1,2,3"
    // badges per app. Result: { "brave": [1, 3, 5], "code": [2], ... }
    //
    // Refreshes on every Hyprland.toplevels change (workspace switches,
    // window opens/closes).
    property var workspacesByApp: {
        const map = {}
        if (typeof Hyprland !== "undefined"
            && Hyprland.toplevels
            && Hyprland.toplevels.values) {
            for (const t of Hyprland.toplevels.values) {
                if (!t) continue
                const cls = ((t.lastIpcObject && t.lastIpcObject.class)
                             || t.class || "").toLowerCase()
                if (!cls) continue
                const wsId = (t.workspace && t.workspace.id) || -1
                if (wsId < 0) continue
                if (!map[cls]) map[cls] = []
                if (map[cls].indexOf(wsId) < 0) map[cls].push(wsId)
            }
            // Sort each app's workspace list ascending
            for (const k in map) map[k].sort(function(a, b) { return a - b })
        }
        return map
    }

    // v7.0.0-beta.1-hf67 — track which apps have minimized windows.
    //
    // Windows sent to special:minimized (via Super+X keybind or
    // hyprbars minimize button) land on a special workspace with
    // a negative ID. This property tracks which app classes have
    // at least one window on ANY special workspace (wsId < 0).
    //
    // The taskbar uses this to:
    //   - Dim the icon (opacity 0.45)
    //   - Show an orange underline
    //   - Click fires unminimizeAndActivate to restore
    property var minimizedApps: {
        const set = {}
        if (typeof Hyprland !== "undefined"
            && Hyprland.toplevels
            && Hyprland.toplevels.values) {
            for (const t of Hyprland.toplevels.values) {
                if (!t) continue
                const cls = ((t.lastIpcObject && t.lastIpcObject.class)
                             || t.class || "").toLowerCase()
                if (!cls) continue
                const wsId = (t.workspace && t.workspace.id) || 0
                if (wsId < 0) {
                    set[cls] = true
                }
            }
        }
        return set
    }

    function workspacesForApp(appId) {
        if (!appId) return []
        const cls = appId.toLowerCase()
        return workspacesByApp[cls] || []
    }

    property var appList: {
        const list = []
        const seen = {}
        for (const appId of pinnedApps) {
            const id = appId.toLowerCase()
            const wins = groupedApps[id] || []
            list.push({
                id: appId,
                pinned: true,
                running: wins.length > 0,
                windowCount: wins.length
            })
            seen[id] = true
        }
        for (const id in groupedApps) {
            if (!seen[id]) {
                list.push({
                    id: id,
                    pinned: false,
                    running: true,
                    windowCount: groupedApps[id].length
                })
            }
        }
        return list
    }

    // ── Smart DesktopEntry lookup ──
    function findEntry(appId) {
        let entry = DesktopEntries.byId(appId)
        if (entry) return entry
        entry = DesktopEntries.byId(appId.toLowerCase())
        if (entry) return entry
        const variations = [appId, appId.toLowerCase(),
            "org.mozilla." + appId, "com." + appId + "." + appId]
        for (const v of variations) {
            entry = DesktopEntries.byId(v)
            if (entry) return entry
        }
        return null
    }

    // ── v6.9: Safe close — try requestClose first, fallback to hyprctl ──
    // Used by the per-window X button inside the popup (single window
    // close — never falls through to pkill because pkill -f appId would
    // also kill sibling windows of the same app).
    function safeClose(toplevel) {
        if (!toplevel) return
        // Try Quickshell Wayland API methods in order of preference
        if (typeof toplevel.requestClose === "function") {
            toplevel.requestClose()
        } else if (typeof toplevel.close === "function") {
            toplevel.close()
        } else {
            // Last resort: hyprctl with window address
            const addr = toplevel.address || ""
            if (addr) {
                closeHelper.command = ["hyprctl", "dispatch", "closewindow", "address:" + addr]
                closeHelper.running = true
            } else {
                // Try by title
                const title = toplevel.title || ""
                if (title) {
                    closeHelper.command = ["hyprctl", "dispatch", "closewindow", "title:" + title]
                    closeHelper.running = true
                }
            }
        }
    }

    // v6.16.4.12.6: graceful-then-pkill close-all path.
    //
    // Some apps refuse to die from requestClose() — Lark, electron apps
    // running a render-process freeze, anything stuck in a sync ipc
    // round-trip. Old behavior: dialog hung in the bar, Paul reaches
    // for kitty + pkill manually. New behavior: 250 ms after the
    // graceful attempt, watchdog fires `pkill -f <appId>`. Apps that
    // closed cleanly are no-ops for pkill (process already gone). Apps
    // still alive get killed without the user having to ctrl-shift-esc.
    //
    // Why pkill -f and not pkill: many Wayland appIds don't match the
    // process basename (firefox-esr → /usr/lib/firefox/firefox; lark
    // → larkmail). -f matches the full command line and catches both.
    function pkillByAppId(appId) {
        if (!appId) return
        // Sanitize — only allow alphanumerics, dash, underscore, dot.
        // Anything else gets stripped so the appId can't escape into the
        // bash command line.
        const safe = String(appId).replace(/[^a-zA-Z0-9_\-\.]/g, "")
        if (!safe) return
        pkillHelper.command = ["bash", "-c",
            "pkill -f -- '" + safe + "' 2>/dev/null; " +
            "sleep 0.2; " +
            "pkill -9 -f -- '" + safe + "' 2>/dev/null; " +
            "true"]
        pkillHelper.running = true
    }

    // v6.16.4.12.6: Renamed from immediate-loop close to graceful-then-pkill.
    // Step 1: fire requestClose() on every window of this app (gives well-
    //         behaved apps a chance to show "Save changes?" dialogs).
    // Step 2: watchdog timer fires after 250 ms, runs pkill -f appId.
    function safeCloseAll(appId) {
        const ws = groupedApps[appId.toLowerCase()] || []
        for (const w of ws) safeClose(w)
        // Arm the pkill watchdog
        pkillWatchdog.targetAppId = appId
        pkillWatchdog.restart()
    }

    Process { id: closeHelper; running: false }
    Process { id: pkillHelper; running: false }

    // v7.0.0-beta.1-hf65 — unminimize helper.
    //
    // When hyprbars minimize button sends a window to
    // `special:minimized` workspace, the standard Toplevel.activate()
    // can't pull it back — windows on special workspaces are hidden
    // from the compositor's focus list.
    //
    // Fix: before activating, move the window from special:minimized
    // to the current active workspace via hyprctl dispatch. This is
    // a no-op if the window isn't actually on special:minimized.
    Process { id: unminimizeHelper; running: false }

    // v7.0.0-beta.1-hf69 — proper restore sequence.
    //
    // hf68's restore moved the window back but it wasn't interactive
    // (stuck behind other windows, no input focus). Root cause:
    //   - `movetoworkspace e+0` is ambiguous on some Hyprland versions
    //   - `focuswindow` alone doesn't raise the window in z-stack
    //
    // Fixed sequence:
    //   1. Get current workspace ID explicitly (hyprctl activeworkspace)
    //   2. Move window to that specific workspace ID
    //   3. Brief sleep for Hyprland to settle
    //   4. Focus window (sets keyboard focus)
    //   5. Raise to top of z-stack (alterzorder top)
    //   6. Second focuswindow (belt-and-suspenders)
    //
    // This matches what happens when you manually drag a window from
    // another workspace — it's fully interactive immediately.

    function unminimizeAndActivate(toplevel) {
        const addr = toplevel.address || toplevel._hyprAddr || ""
        if (addr) {
            // hf79 FIX: OLD behavior moved the WINDOW to the current
            // workspace. NEW behavior switches the USER to the window's
            // workspace. Only exception: minimized windows (special
            // workspace) are restored to current workspace first.
            //
            // Flow:
            //   1. Get window's workspace ID from hyprctl clients
            //   2. If workspace < 0 (special/minimized) → restore to
            //      current workspace, then focus
            //   3. If workspace > 0 (regular) → switch to that workspace,
            //      then focus
            //   4. Cursor warp to window center
            unminimizeHelper.command = ["bash", "-c",
                "WIN_WS=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.address==\"" + addr + "\") | .workspace.id' 2>/dev/null); "
                + "if [ -z \"$WIN_WS\" ] || [ \"$WIN_WS\" = 'null' ]; then WIN_WS=0; fi; "
                + "if [ \"$WIN_WS\" -lt 0 ] 2>/dev/null; then "
                // Minimized → restore to current workspace
                + "  CUR_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo 1); "
                + "  hyprctl dispatch movetoworkspace \"$CUR_WS,address:" + addr + "\"; "
                + "  sleep 0.1; "
                + "else "
                // Regular workspace → switch to it
                + "  hyprctl dispatch workspace \"$WIN_WS\"; "
                + "  sleep 0.05; "
                + "fi; "
                // Focus + raise + cursor warp
                + "hyprctl dispatch focuswindow 'address:" + addr + "'; "
                + "hyprctl dispatch alterzorder 'top,address:" + addr + "'; "
                + "hyprctl dispatch focuswindow 'address:" + addr + "'; "
                + "WIN_XY=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.address==\"" + addr + "\") | \"\\(.at[0]+.size[0]/2) \\(.at[1]+.size[1]/2)\"' 2>/dev/null); "
                + "if [ -n \"$WIN_XY\" ]; then hyprctl dispatch movecursor $WIN_XY; fi"]
            unminimizeHelper.running = true
        } else {
            const cls = (toplevel.appId || "").toLowerCase()
            if (cls) {
                taskbarRoot.unminimizeByClass(cls)
            } else {
                toplevel.activate()
            }
        }
    }

    // v7.0.0-beta.1-hf68 — class-based unminimize.
    // v7.0.0-beta.1-hf79 — workspace-switch: if window is on a regular
    // workspace, switch USER to it instead of moving window to current.
    // Only minimized (special workspace) windows get restored to current.
    function unminimizeByClass(appClass) {
        const cls = appClass.toLowerCase()
        unminimizeHelper.command = ["bash", "-c",
            // Find first window of this class (any workspace, not just special)
            "INFO=$(hyprctl clients -j 2>/dev/null | jq -r '[.[] | select("
            + "(.class | ascii_downcase) == \"" + cls + "\")] | .[0] | "
            + "\"\\(.address) \\(.workspace.id)\"' 2>/dev/null); "
            + "ADDR=$(echo \"$INFO\" | awk '{print $1}'); "
            + "WIN_WS=$(echo \"$INFO\" | awk '{print $2}'); "
            + "if [ -z \"$ADDR\" ] || [ \"$ADDR\" = 'null' ]; then exit 0; fi; "
            + "if [ \"$WIN_WS\" -lt 0 ] 2>/dev/null; then "
            // Minimized → restore to current workspace
            + "  CUR_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo 1); "
            + "  hyprctl dispatch movetoworkspace \"$CUR_WS,address:$ADDR\"; "
            + "  sleep 0.1; "
            + "else "
            // Regular workspace → switch to it
            + "  hyprctl dispatch workspace \"$WIN_WS\"; "
            + "  sleep 0.05; "
            + "fi; "
            + "hyprctl dispatch focuswindow \"address:$ADDR\"; "
            + "hyprctl dispatch alterzorder \"top,address:$ADDR\"; "
            + "hyprctl dispatch focuswindow \"address:$ADDR\"; "
            + "WIN_XY=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.address==\"'\"$ADDR\"'\") | \"\\(.at[0]+.size[0]/2) \\(.at[1]+.size[1]/2)\"' 2>/dev/null); "
            + "if [ -n \"$WIN_XY\" ]; then hyprctl dispatch movecursor $WIN_XY; fi"]
        unminimizeHelper.running = true
    }

    // Watchdog: 250 ms after graceful close, force-kill anything still alive
    Timer {
        id: pkillWatchdog
        interval: 250
        repeat: false
        property string targetAppId: ""
        onTriggered: {
            if (targetAppId) taskbarRoot.pkillByAppId(targetAppId)
            targetAppId = ""
        }
    }

    function pinApp(appId) {
        if (pinnedApps.indexOf(appId) === -1) {
            pinnedApps = pinnedApps.concat([appId])
            savePinned()
        }
    }

    function unpinApp(appId) {
        pinnedApps = pinnedApps.filter(p => p !== appId)
        savePinned()
    }

    function savePinned() {
        pinnedSaver.command = ["bash", "-c",
            "echo '" + JSON.stringify({pinned: pinnedApps}) + "' > " + Quickshell.dataPath("pinned-apps.json")]
        pinnedSaver.running = true
    }

    Process { id: pinnedSaver; running: false }

    FileView {
        path: Quickshell.dataPath("pinned-apps.json")
        blockLoading: true
        onLoaded: {
            try {
                const d = JSON.parse(this.text())
                if (d.pinned) taskbarRoot.pinnedApps = d.pinned
            } catch(e) {}
        }
    }

    // v6.12: Overflow-aware layout with chevron scroll buttons
    property int scrollOffset: 0
    readonly property int scrollStep: (btnSize + btnSpacing) * 2  // scroll 2 icons at a time
    // v7.0.0-beta.1-hf95: axis-aware max scroll.
    readonly property int maxScroll: zenVertical
        ? Math.max(0, fullColH - maxVisibleHeight)
        : Math.max(0, taskbarRow.implicitWidth - maxVisibleWidth)

    // Clamp scroll when app list shrinks (e.g. windows close)
    onMaxScrollChanged: {
        if (scrollOffset > maxScroll) scrollOffset = maxScroll
    }

    // v7.0.0-beta.1-hf95: chevron container flips axis. Horizontal = a
    // row [‹ | viewport | ›]; vertical = a column [▲ / viewport / ▼].
    GridLayout {
        anchors.centerIn: parent
        columns: taskbarRoot.zenVertical ? 1 : 3
        rowSpacing: 4
        columnSpacing: 4

        // ── Up/Left chevron (scroll toward start) ──
        Rectangle {
            visible: taskbarRoot.hasOverflow && taskbarRoot.scrollOffset > 0
            Layout.preferredWidth: taskbarRoot.zenVertical ? taskbarRoot.btnSize : taskbarRoot.chevronWidth
            Layout.preferredHeight: taskbarRoot.zenVertical ? taskbarRoot.chevronWidth : 32
            Layout.alignment: Qt.AlignHCenter
            radius: 8
            // v7.0.0-beta.1-hf9: ThemeService (live) instead of static Theme
            color: chevLeftMa.containsMouse
                   ? ThemeService.bg3
                   : ThemeService.alpha(ThemeService.bg2, 0.85)
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: taskbarRoot.zenVertical ? "\u25B2" : "\u276E"  // ▲ / ❮
                color: ThemeService.fg
                font.pixelSize: 14
                font.bold: true
            }
            MouseArea {
                id: chevLeftMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    taskbarRoot.scrollOffset = Math.max(0, taskbarRoot.scrollOffset - taskbarRoot.scrollStep)
                }
            }
        }

        // ── Clipped viewport ──
        Item {
            // v7.0.0-beta.1-hf91.1 / hf95: axis-aware viewport. Horizontal
            // keeps the original fixed-height 44 strip. Vertical sizes to
            // the (capped) icon column; clips + scrolls on Y when the list
            // overflows maxVisibleHeight.
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: taskbarRoot.zenVertical
                ? taskbarRoot.btnSize
                : (taskbarRoot.hasOverflow ? taskbarRoot.maxVisibleWidth : taskbarRow.implicitWidth)
            Layout.preferredHeight: taskbarRoot.zenVertical
                ? taskbarRoot.taskbarColH
                : 44
            clip: taskbarRoot.zenVertical ? taskbarRoot.hasOverflow : true

            // v7.0.0-beta.1-hf82f — switched from RowLayout to Item
            // with manual positioning. RowLayout's Layout.preferred*
            // properties are non-negotiable; we can't override x on a
            // RowLayout child during drag without the layout snapping
            // it back on the next layout pass. By computing slot
            // positions ourselves and letting each icon animate its
            // own x via Behavior, we get:
            //   1. Drag interrupts cleanly (set x explicitly = follow
            //      cursor, no layout pass fights us)
            //   2. Smooth neighbor slide (Behavior on x is honored
            //      because nothing is forcing the position)
            //   3. Same visual layout as before (spacing 4, height 40,
            //      identical computed slot positions)
            Item {
                id: taskbarRow
                // v7.0.0-beta.1-hf91: axis-aware. Horizontal = original
                // (centered vertically, scrolls on x). Vertical = centered
                // horizontally, stacks on y.
                x: taskbarRoot.zenVertical ? (parent.width - width) / 2 : -taskbarRoot.scrollOffset
                y: taskbarRoot.zenVertical ? -taskbarRoot.scrollOffset : (parent.height - height) / 2
                width: taskbarRoot.zenVertical ? taskbarRoot.btnSize : implicitWidth
                height: taskbarRoot.zenVertical ? taskbarRoot.fullColH : taskbarRoot.btnSize
                // implicitWidth = N icons * (btnSize + btnSpacing) - last spacing
                implicitWidth: {
                    const n = taskbarRoot.appList.length
                    if (n <= 0) return 0
                    return n * (taskbarRoot.btnSize + taskbarRoot.btnSpacing) - taskbarRoot.btnSpacing
                }

                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Repeater {
                    model: taskbarRoot.appList

            Rectangle {
                id: appBtn
                property var appData: modelData
                // hf82f — capture Repeater's implicit `index` into a
                // named property so child scopes can reference it
                // unambiguously (effectiveIndex, etc.).
                property int btnIndex: index
                property string appId: appData.id
                property bool isRunning: appData.running
                property bool isPinned: appData.pinned
                property int windowCount: appData.windowCount
                property bool isActive: {
                    const atl = ToplevelManager.activeToplevel
                    return atl ? (atl.appId || "").toLowerCase() === appId.toLowerCase() : false
                }
                property var entry: taskbarRoot.findEntry(appId)
                // v7.0.0-beta.1-hf67 — minimized detection.
                property bool isMinimized: {
                    return isRunning && !isActive
                           && !!taskbarRoot.minimizedApps[appId.toLowerCase()]
                }

                // v7.0.0-beta.1-hf82f — drag participation
                // Is THIS icon currently being dragged?
                readonly property bool isDragging: taskbarRoot._dragAppId === appId
                // Index in pinnedApps array (-1 if running-only, not pinned).
                // Cached so we don't recompute on every position update.
                readonly property int pinnedIndex: {
                    if (!isPinned) return -1
                    return taskbarRoot.pinnedApps.indexOf(appId)
                }

                // Effective render index — when ANOTHER icon is being
                // dragged over this slot, this icon may need to shift
                // left or right by one slot to "make room" visually.
                // Animated through the Behavior on x below.
                readonly property int effectiveIndex: {
                    if (taskbarRoot._dragAppId === "" || isDragging) return btnIndex
                    if (!isPinned || pinnedIndex < 0) return btnIndex
                    const start = taskbarRoot._dragStartIndex
                    const curr  = taskbarRoot._dragCurrentIndex
                    if (start < 0 || curr < 0 || start === curr) return btnIndex
                    // Dragging to the right: items between (start+1..curr)
                    // shift LEFT one slot to fill the gap.
                    if (curr > start && pinnedIndex > start && pinnedIndex <= curr) {
                        return btnIndex - 1
                    }
                    // Dragging to the left: items between (curr..start-1)
                    // shift RIGHT one slot.
                    if (curr < start && pinnedIndex >= curr && pinnedIndex < start) {
                        return btnIndex + 1
                    }
                    return btnIndex
                }

                width: taskbarRoot.btnSize
                height: taskbarRoot.btnSize
                // Position computed from effectiveIndex (or follows
                // cursor when this icon is being dragged).
                // v7.0.0-beta.1-hf91: vertical mode positions on the Y
                // axis (x stays 0, centered by taskbarRow); horizontal is
                // the original X-axis logic verbatim.
                x: {
                    if (taskbarRoot.zenVertical) {
                        if (isDragging) {
                            const rawY = taskbarRoot._dragCursorY - taskbarRoot._dragGrabOffsetY
                            const slotV = taskbarRoot.btnSize + taskbarRoot.btnSpacing
                            const maxV = (taskbarRoot.appList.length - 1) * slotV
                            return 0   // x fixed in zenVertical
                        }
                        return 0
                    }
                    if (isDragging) {
                        // Hover-with-cursor — clamp within taskbarRow bounds
                        // for safety so the icon never escapes the bar.
                        const raw = taskbarRoot._dragCursorX - taskbarRoot._dragGrabOffsetX
                        const slotW = taskbarRoot.btnSize + taskbarRoot.btnSpacing
                        const maxX = (taskbarRoot.appList.length - 1) * slotW
                        return Math.max(0, Math.min(maxX, raw))
                    }
                    return effectiveIndex * (taskbarRoot.btnSize + taskbarRoot.btnSpacing)
                }
                y: {
                    if (taskbarRoot.zenVertical) {
                        if (isDragging) {
                            const rawY = taskbarRoot._dragCursorY - taskbarRoot._dragGrabOffsetY
                            const slotV = taskbarRoot.btnSize + taskbarRoot.btnSpacing
                            const maxV = (taskbarRoot.appList.length - 1) * slotV
                            return Math.max(0, Math.min(maxV, rawY))
                        }
                        return effectiveIndex * (taskbarRoot.btnSize + taskbarRoot.btnSpacing)
                    }
                    return 0
                }

                // Smooth slide for neighbor animation. The dragged
                // icon itself uses no behavior (follows cursor 1:1).
                Behavior on y {
                    enabled: taskbarRoot.zenVertical && !appBtn.isDragging
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                // Smooth slide for neighbor animation. The dragged
                // icon itself uses no behavior (follows cursor 1:1).
                Behavior on x {
                    enabled: !appBtn.isDragging
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                // Lift on drag — z above siblings, slight scale-up
                // and a hint of transparency for the "picked up" feel.
                z: isDragging ? 100 : 1
                scale: isDragging ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                radius: 13
                // v7.0.0-beta.1-hf6: bind icon bg to ThemeService (live theme)
                // instead of static Theme constants. This way the taskbar
                // icon backgrounds repaint when matugen switches palette or
                // user picks a new theme.
                color: isActive
                       ? ThemeService.blue
                       : ma.containsMouse
                         ? ThemeService.bg3
                         : ThemeService.alpha(ThemeService.bg1, 0.85)
                Behavior on color { ColorAnimation { duration: 200 } }
                // hf67 — dim icon when minimized
                // hf82f — combined with drag-lift opacity. Drag wins
                // over minimize so the picked-up icon doesn't disappear
                // if you happen to pick up a minimized one.
                opacity: isDragging ? 0.92
                         : (isMinimized ? 0.45 : 1.0)
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Image {
                    anchors.centerIn: parent
                    width: Math.round(taskbarRoot.btnSize * 0.6); height: Math.round(taskbarRoot.btnSize * 0.6)
                    source: entry && entry.icon
                        ? Quickshell.iconPath(entry.icon)
                        : (Quickshell.iconPath(appId, true) || Quickshell.iconPath("application-x-executable"))
                    sourceSize: Qt.size(24, 24)
                }

                // Window count badge
                Rectangle {
                    visible: windowCount > 1
                    width: 14; height: 14; radius: 7
                    color: Theme.purple
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -2
                    Text { anchors.centerIn: parent; text: windowCount; color: Theme.bg0; font.pixelSize: 9; font.bold: true }
                }

                // v7.0.0-beta.1-hf6: WORKSPACE BADGE
                //
                // Shows the workspace numbers where this app has windows,
                // as a small pill at the bottom-right of the icon. e.g.
                // if Brave is running on workspaces 1 and 3, shows "1,3".
                //
                // Hidden when the app isn't running or when there's nothing
                // to display.
                Rectangle {
                    id: wsBadge
                    readonly property var _wsList: taskbarRoot.workspacesForApp(appId)
                    readonly property string _wsLabel: {
                        if (!_wsList || _wsList.length === 0) return ""
                        if (_wsList.length === 1) return _wsList[0].toString()
                        if (_wsList.length <= 3) return _wsList.join(",")
                        // Compact form for many workspaces: "1,2…5"
                        return _wsList[0] + "…" + _wsList[_wsList.length - 1]
                    }
                    visible: isRunning && _wsLabel.length > 0
                    height: 12
                    width: wsBadgeText.implicitWidth + 8
                    radius: 6
                    color: ThemeService.alpha(ThemeService.blue, 0.92)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.bg0, 0.4)
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -3
                    anchors.bottomMargin: -3

                    Text {
                        id: wsBadgeText
                        anchors.centerIn: parent
                        text: wsBadge._wsLabel
                        color: ThemeService.bg0
                        font.pixelSize: 8
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }

                // Running dot
                Rectangle {
                    visible: isRunning && !isActive && windowCount <= 1
                    width: 5; height: 5; radius: 2.5; color: Theme.fg; opacity: 0.7
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                }

                // Running bar (multi)
                Rectangle {
                    visible: isRunning && !isActive && windowCount > 1
                    width: 16; height: 3; radius: 1.5; color: Theme.fg; opacity: 0.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                }

                // Active bar
                Rectangle {
                    visible: isActive
                    width: 16; height: 3; radius: 1.5; color: Theme.bg0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                }

                // v7.0.0-beta.1-hf67 — Minimized indicator bar (orange)
                // Shows when window is on special:minimized workspace.
                // Distinct from running dot (grey) and active bar (blue bg).
                // Click the icon to restore (unminimizeAndActivate).
                Rectangle {
                    visible: isMinimized
                    width: 16; height: 3; radius: 1.5
                    color: ThemeService.orange || ThemeService.yellow || "#ff9e64"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: appBtn.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    // v7.0.0-beta.1-hf82f — drag state machine.
                    //
                    // The icon enters drag mode after a 350 ms press
                    // hold. Before that, click handling is normal
                    // (launch / raise / popup). If the user releases
                    // before the timer fires, it's a click. If the
                    // user moves the cursor > 8 px before the timer
                    // fires, we ALSO enter drag immediately — this
                    // matches user expectation (decisive drag intent
                    // shouldn't have to wait for the timer).
                    //
                    // Only pinned apps drag. Running-only icons:
                    // press behavior is identical, but the drag
                    // never engages (timer fires but _dragAppId
                    // stays empty).
                    property real _pressX: 0
                    property real _pressY: 0
                    property bool _dragArmed: false   // press recorded, drag not yet started
                    property bool _dragStarted: false // drag active

                    Timer {
                        id: pressHoldTimer
                        interval: 350
                        repeat: false
                        onTriggered: {
                            if (!ma._dragArmed) return
                            // hf82g — used to skip if !appBtn.isPinned.
                            // Now all icons are draggable; running-but-
                            // not-pinned icons get auto-pinned on drag-
                            // start so they can join the pinnedApps array.
                            ma._startDrag()
                        }
                    }

                    function _startDrag() {
                        // hf82g — accept any icon (pinned or not).
                        // If not pinned, auto-pin first so the icon
                        // joins pinnedApps and can participate in the
                        // reorder. If the user cancels the drag, the
                        // auto-pin will be reversed in _endDrag(false).
                        //
                        // Why: user expectation matches every modern DE
                        // (GNOME / KDE / Windows 11) — every icon in
                        // the taskbar should be draggable. The previous
                        // pinned-only restriction surprised users who
                        // had running apps trailing pinned ones and
                        // couldn't figure out why dragging those didn't
                        // work.
                        let autoPinned = false
                        if (!appBtn.isPinned) {
                            // pinApp() appends to the end of pinnedApps
                            // and saves. The dragged app is now the
                            // LAST entry in pinnedApps, which means its
                            // pinnedIndex is (pinnedApps.length - 1).
                            // We then read the fresh index below.
                            taskbarRoot.pinApp(appBtn.appId)
                            autoPinned = true
                        }
                        const freshIndex = taskbarRoot.pinnedApps.indexOf(appBtn.appId)
                        if (freshIndex < 0) {
                            // Shouldn't happen — pinApp guarantees the
                            // app is now in pinnedApps. But guard
                            // against a possible array race anyway.
                            return
                        }
                        taskbarRoot._dragAppId = appBtn.appId
                        taskbarRoot._dragStartIndex = freshIndex
                        taskbarRoot._dragCurrentIndex = freshIndex
                        taskbarRoot._dragOriginX = appBtn.x
                        taskbarRoot._dragGrabOffsetX = ma._pressX
                        taskbarRoot._dragCursorX = appBtn.x + ma._pressX
                        // v7.0.0-beta.1-hf91 — vertical axis grab/cursor.
                        taskbarRoot._dragGrabOffsetY = ma._pressY
                        taskbarRoot._dragCursorY = appBtn.y + ma._pressY
                        taskbarRoot._dragAutoPinned = autoPinned
                        ma._dragStarted = true
                        // Dismiss popups so the dragged icon's lift
                        // isn't visually fighting with the window-list
                        // popup that would otherwise be anchored to it.
                        taskbarRoot.popupAppId = ""
                        taskbarRoot.ctxAppId = ""
                    }

                    onPressed: (mouse) => {
                        if (mouse.button !== Qt.LeftButton) return
                        ma._pressX = mouse.x
                        ma._pressY = mouse.y
                        ma._dragArmed = true
                        ma._dragStarted = false
                        pressHoldTimer.restart()
                    }

                    onPositionChanged: (mouse) => {
                        if (!ma._dragArmed) return
                        if (!ma._dragStarted) {
                            // Pre-drag: did the user move enough to
                            // commit to a drag without waiting for
                            // the hold timer?
                            const dx = mouse.x - ma._pressX
                            const dy = mouse.y - ma._pressY
                            if (Math.abs(dx) > 8 || Math.abs(dy) > 8) {
                                pressHoldTimer.stop()
                                // hf82g — used to skip non-pinned;
                                // now any icon enters drag (auto-pin
                                // happens inside _startDrag).
                                ma._startDrag()
                            }
                            return
                        }
                        // Drag in progress: update cursor position in
                        // taskbarRow coordinates. mouse.x is local to
                        // appBtn; convert to taskbarRow x by adding
                        // the icon's current x.
                        // We use the icon's pre-drag origin as the
                        // reference frame so cursor → row x conversion
                        // is stable even as the icon itself moves.
                        // v7.0.0-beta.1-hf91 — vertical uses the Y axis.
                        if (taskbarRoot.zenVertical) {
                            const rowY = appBtn.y + mouse.y
                            taskbarRoot._dragCursorY = rowY
                            const hitV = taskbarRoot._dragHitIndex(rowY - taskbarRoot._dragGrabOffsetY
                                                                   + (taskbarRoot.btnSize / 2))
                            if (hitV !== taskbarRoot._dragCurrentIndex) {
                                taskbarRoot._dragCurrentIndex = hitV
                            }
                            return
                        }
                        const rowX = appBtn.x + mouse.x
                        taskbarRoot._dragCursorX = rowX
                        const hit = taskbarRoot._dragHitIndex(rowX - taskbarRoot._dragGrabOffsetX
                                                              + (taskbarRoot.btnSize / 2))
                        if (hit !== taskbarRoot._dragCurrentIndex) {
                            taskbarRoot._dragCurrentIndex = hit
                        }
                    }

                    onReleased: (mouse) => {
                        const wasDragging = ma._dragStarted
                        pressHoldTimer.stop()
                        ma._dragArmed = false
                        ma._dragStarted = false
                        if (wasDragging) {
                            // Commit reorder (savePinned fires inside).
                            taskbarRoot._endDrag(true)
                        }
                    }

                    onCanceled: {
                        pressHoldTimer.stop()
                        ma._dragArmed = false
                        if (ma._dragStarted) {
                            // Cancel (Esc / focus lost) — no commit,
                            // icon snaps back via Behavior on x.
                            taskbarRoot._endDrag(false)
                        }
                        ma._dragStarted = false
                    }

                    onClicked: (mouse) => {
                        // v7.0.0-beta.1-hf82f — only fire click handler
                        // if we did NOT engage drag during this press.
                        // (Qt fires onClicked even after a drag-release
                        // since the press/release pair completed inside
                        // the MouseArea; we guard explicitly.)
                        if (ma._dragStarted) return
                        if (mouse.button === Qt.LeftButton) {
                            // v7.0.0-beta.1-hf68 — check minimized FIRST.
                            // When app is minimized (on special workspace),
                            // use class-based restore via hyprctl clients.
                            // This works even when ToplevelManager doesn't
                            // have the window address.
                            if (isMinimized) {
                                taskbarRoot.unminimizeByClass(appId)
                            } else if (!isRunning && entry) {
                                entry.execute()
                            } else if (windowCount === 1) {
                                const w = taskbarRoot.groupedApps[appId.toLowerCase()] || []
                                if (w.length > 0) taskbarRoot.unminimizeAndActivate(w[0])
                            } else if (windowCount > 1) {
                                taskbarRoot.ctxAppId = ""
                                taskbarRoot.popupAppId = (taskbarRoot.popupAppId === appId) ? "" : appId
                            }
                        } else {
                            taskbarRoot.popupAppId = ""
                            taskbarRoot.ctxAppId = (taskbarRoot.ctxAppId === appId) ? "" : appId
                        }
                    }
                }

                // ── Window List Popup ──
                // v6.16.4.12.6.51 (Hikari):
                //   • Theme-synced via ThemeService (was Theme.alpha/Theme.bg1)
                //   • Repeater wrapped in Flickable for scrolling when many
                //     windows of the same app are open. Max popup height
                //     bumped from 300 → 420 with internal scroll past that.
                PopupWindow {
                    anchor.item: appBtn
                    // v6.16.4.12.7.1: 4-direction-aware popup edges.
                    // PanelState.popupAnchorEdges resolves to Top/Bottom/
                    // Left/Right based on the current panel position so
                    // the popup always grows AWAY from the bar.
                    anchor.edges: PanelState.popupAnchorEdges
                    anchor.gravity: PanelState.popupAnchorGravity
                    visible: taskbarRoot.popupAppId === appId && windowCount > 1
                    implicitWidth: 240
                    implicitHeight: Math.min(winCol.implicitHeight + 16, 420)
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.12)

                        ColumnLayout {
                            id: winCol
                            anchors.fill: parent; anchors.margins: 8; spacing: 4

                            Text {
                                text: entry ? entry.name : appId
                                color: ThemeService.alpha(ThemeService.fg, 0.7)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11; font.bold: true; leftPadding: 4
                            }

                            // Scrollable list — Flickable with content column.
                            // Allows >7 windows of the same app to be reachable
                            // via mouse-wheel or drag scroll.
                            Flickable {
                                id: winFlick
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: Math.min(winListCol.implicitHeight, 360)
                                contentWidth: width
                                contentHeight: winListCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.VerticalFlick

                                ColumnLayout {
                                    id: winListCol
                                    width: winFlick.width
                                    spacing: 2

                                    Repeater {
                                        model: taskbarRoot.groupedApps[appId.toLowerCase()] || []

                                        Rectangle {
                                            Layout.fillWidth: true; height: 32; radius: 8
                                            color: wma.containsMouse
                                                   ? ThemeService.alpha(ThemeService.fg, 0.08)
                                                   : "transparent"
                                            property var tl: modelData

                                            // wma FIRST (bottom of z-stack) so close X is on top
                                            MouseArea {
                                                id: wma
                                                anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { taskbarRoot.unminimizeAndActivate(tl); taskbarRoot.popupAppId = "" }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                                z: 1

                                                Text {
                                                    Layout.fillWidth: true
                                                    // hf79: append workspace ID so user knows
                                                    // which workspace each window lives on.
                                                    text: {
                                                        const t = tl.title || "Untitled"
                                                        const trimmed = t.length > 25 ? t.substring(0, 22) + "…" : t
                                                        // Get workspace ID from toplevel
                                                        const wsId = (tl.workspace && tl.workspace.id > 0) ? tl.workspace.id : ""
                                                        if (wsId) return trimmed + " — " + wsId
                                                        return trimmed
                                                    }
                                                    color: tl.activated ? ThemeService.blue : ThemeService.fg
                                                    elide: Text.ElideRight
                                                    font.family: Theme.fontFamily; font.pixelSize: 12
                                                }

                                                // Close button — larger click area, on top of wma
                                                Rectangle {
                                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                                    radius: 12
                                                    color: closeWinMa.containsMouse
                                                           ? ThemeService.alpha(ThemeService.red, 0.2)
                                                           : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\u2715"
                                                        color: closeWinMa.containsMouse
                                                               ? ThemeService.red
                                                               : ThemeService.alpha(ThemeService.fg, 0.55)
                                                        font.pixelSize: 11
                                                    }
                                                    MouseArea {
                                                        id: closeWinMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: taskbarRoot.safeClose(tl)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Slim scrollbar — only visible when content overflows
                                Rectangle {
                                    visible: winFlick.contentHeight > winFlick.height
                                    width: 3
                                    height: Math.max(20, winFlick.height * (winFlick.height / winFlick.contentHeight))
                                    radius: 1.5
                                    color: ThemeService.alpha(ThemeService.fg, 0.25)
                                    anchors.right: parent.right
                                    anchors.rightMargin: 1
                                    y: winFlick.contentY * (winFlick.height / winFlick.contentHeight)
                                }
                            }
                        }
                    }
                }

                // ── Context Menu ──
                // v6.16.4.12.6.51 (Hikari): theme-synced via ThemeService
                // (was Theme.alpha/Theme.bg1/Theme.bg2). Same approach as
                // start menu and ZenNotificationCenter.
                PopupWindow {
                    anchor.item: appBtn
                    // v6.16.4.12.7.1: 4-direction-aware popup edges.
                    anchor.edges: PanelState.popupAnchorEdges
                    anchor.gravity: PanelState.popupAnchorGravity
                    visible: taskbarRoot.ctxAppId === appId
                    implicitWidth: 180
                    implicitHeight: ctxCol.implicitHeight + 16
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.12)

                        ColumnLayout {
                            id: ctxCol
                            anchors.fill: parent; anchors.margins: 8; spacing: 2

                            // Pin/Unpin
                            Rectangle {
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: pma.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                    Text { text: isPinned ? taskbarRoot.nfUnpin : taskbarRoot.nfPin; color: ThemeService.fg; font.family: Theme.monoFont; font.pixelSize: 14 }
                                    Text { text: isPinned ? "Unpin" : "Pin to taskbar"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (isPinned) taskbarRoot.unpinApp(appId); else taskbarRoot.pinApp(appId); taskbarRoot.ctxAppId = "" }
                                }
                            }

                            // New window
                            Rectangle {
                                visible: entry !== null
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: nma.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                    Text { text: taskbarRoot.nfWindow; color: ThemeService.fg; font.family: Theme.monoFont; font.pixelSize: 14 }
                                    Text { text: "New window"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (entry) entry.execute(); taskbarRoot.ctxAppId = "" }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: ThemeService.alpha(ThemeService.fg, 0.08) }

                            // v6.9: Close all — uses safeCloseAll
                            Rectangle {
                                visible: isRunning
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: cma.containsMouse ? ThemeService.alpha(ThemeService.red, 0.15) : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                    Text { text: taskbarRoot.nfClose; color: ThemeService.red; font.family: Theme.monoFont; font.pixelSize: 14 }
                                    Text { text: windowCount > 1 ? "Close all (" + windowCount + ")" : "Close"; color: ThemeService.red; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { taskbarRoot.safeCloseAll(appId); taskbarRoot.ctxAppId = "" }
                                }
                            }
                        }
                    }
                }
            }
        }
        }  // end Item (taskbarRow — was RowLayout pre-hf82f)
        }  // end Item (clip viewport)

        // ── Down/Right chevron (scroll toward end) ──
        Rectangle {
            visible: taskbarRoot.hasOverflow && taskbarRoot.scrollOffset < taskbarRoot.maxScroll
            Layout.preferredWidth: taskbarRoot.zenVertical ? taskbarRoot.btnSize : taskbarRoot.chevronWidth
            Layout.preferredHeight: taskbarRoot.zenVertical ? taskbarRoot.chevronWidth : 32
            Layout.alignment: Qt.AlignHCenter
            radius: 8
            // v7.0.0-beta.1-hf9: ThemeService (live) instead of static Theme
            color: chevRightMa.containsMouse
                   ? ThemeService.bg3
                   : ThemeService.alpha(ThemeService.bg2, 0.85)
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: taskbarRoot.zenVertical ? "\u25BC" : "\u276F"  // ▼ / ❯
                color: ThemeService.fg
                font.pixelSize: 14
                font.bold: true
            }
            MouseArea {
                id: chevRightMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    taskbarRoot.scrollOffset = Math.min(taskbarRoot.maxScroll, taskbarRoot.scrollOffset + taskbarRoot.scrollStep)
                }
            }
        }
    }
}
