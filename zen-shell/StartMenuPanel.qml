import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

/*
 * StartMenuPanel.qml v7.0.0-alpha.4-hf1 — dual-pane (Win11-inspired)
 *
 * v7.0.0-alpha.4-hf1 (User feedback fixes):
 *
 *   1. PINNED GRID ALIGNMENT — was using GridLayout (which expanded
 *      to fill its parent height, distributing N rows across all
 *      configured slots and leaving gaps). Replaced with QtQuick.Grid
 *      which packs naturally top-left → bottom-right with no gap
 *      distribution. Items always start from row 0.
 *
 *   2. AVATAR — was placeholder first-letter circle. Now uses
 *      UserProfileService.effectiveAvatarSource (matches v6 behavior:
 *      custom avatar → /var/lib/AccountsService → fallback to letter).
 *
 *   3. FOLDER → THUNAR — was xdg-open ~. Now invokes thunar directly
 *      (Paul's file manager). Fallback to xdg-open if thunar missing.
 *
 *   4. SETTINGS BUTTON RESTORED — was missing in alpha.4. Re-added
 *      between folder + power, opens Zen Settings panel via the
 *      same IPC call v6 used (toggleSettings).
 *
 *   5. POWER POPUP — was a single logout click. Now expands an
 *      inline 5-action menu: Lock / Suspend / Logout / Restart /
 *      Shutdown. Each fires powerActionRequested() with the matching
 *      action name + command, which shell.qml + PowerConfirmDialog
 *      already handle (no shell.qml change needed).
 *
 *   6. RIGHT-CLICK CONTEXT MENU — was direct toggle on right-click.
 *      Now shows a small floating popup at cursor position with:
 *        - "Pin to Start"   + "Cancel"  (when target is unpinned)
 *        - "Unpin from Start" + "Cancel" (when target is pinned)
 *      Cancel just closes; Pin/Unpin commits the action.
 *
 * Otherwise unchanged from alpha.4: dual-pane layout, dynamic
 * grid (PanelState.pinnedGridCols/Rows), AppLauncherService-driven
 * auto-detect + auto-refresh, RecentFilesService-driven recents,
 * memory/perf optimizations, Densho-aware, ThemeService-bound colors.
 *
 * Wala tayong babawasan — public surface (closeRequested,
 * appLaunched, powerActionRequested, uploadInProgress) preserved.
 */
Rectangle {
    id: menuRoot

    // ── PUBLIC INTERFACE (shell.qml depends on these) ──
    signal closeRequested()
    signal appLaunched()
    signal powerActionRequested(string action, string command)
    property bool uploadInProgress: false

    // ── Visual tokens — track ThemeService live ──
    //
    // v7.0.0-alpha.4-hf3: per-corner radius. The bar-facing corners
    // become FLAT (radius 0) so the panel's edge that touches the bar
    // is a perfectly straight line — no triangular cutout from the
    // curve. The corners on the side AWAY from the bar keep the full
    // rounded radius, matching Win11/macOS startmenu behavior.
    //
    // Mapping:
    //   bar at bottom (isBottom) → bottom corners flat, top rounded
    //   bar at top    (isTop)    → top corners flat, bottom rounded
    //   bar at left   (isLeft)   → left corners flat, right rounded
    //   bar at right  (isRight)  → right corners flat, left rounded
    //
    // Per-corner radius requires Qt 6.7+, which Quickshell currently
    // ships against. The fallback `radius: _cornerRadius` keeps the
    // panel functional (all rounded) on older Qt; only the visual
    // refinement is lost.
    readonly property int _cornerRadius:
        (PanelState.propagateStyleToModules && Theme.styleMode === "round") ? 22 : 16

    radius: _cornerRadius
    topLeftRadius:     (PanelState.isTop    || PanelState.isLeft)   ? 0 : _cornerRadius
    topRightRadius:    (PanelState.isTop    || PanelState.isRight)  ? 0 : _cornerRadius
    bottomLeftRadius:  (PanelState.isBottom || PanelState.isLeft)   ? 0 : _cornerRadius
    bottomRightRadius: (PanelState.isBottom || PanelState.isRight)  ? 0 : _cornerRadius

    // v8: sync the start-menu background with the panel's custom color +
    // opacity when set (border already follows PanelState.borderColor), so
    // it matches your panel/dock color setup. Falls back to the theme bg.
    // v8.0.0-alpha-hf148 — start menu follows the look: frosted white body on
    // Glass+, its own colour on every other look.
    color: LookService.bodyColor(PanelState.bgOverrideEnabled
           ? Qt.rgba(PanelState.bgOverrideColor.r, PanelState.bgOverrideColor.g, PanelState.bgOverrideColor.b, PanelState.startMenuOpacity)
           : Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, PanelState.startMenuOpacity))

    // hf2: Border feature.
    //   PanelState.startMenuBorderMode controls behavior:
    //     "off"       — no border (clean glass look)
    //     "match-bar" — same color + width as the bar's border
    //                   (so when the panel is sticky-anchored to the bar,
    //                   the two borders form one continuous line)
    //     "thick"     — 2× the bar's border width with same color
    //                   (emphasized panel outline)
    //
    // When "match-bar" is selected AND the bar's borderEnabled is on,
    // we read PanelState.borderColor + borderWidth directly so the
    // panel and bar look like a single visual unit. When the bar has
    // its border disabled, "match-bar" falls back to the subtle
    // ThemeService outline so the panel still has a visible edge.
    // v8.0.0-alpha-hf148 — Glass+ drops the border; other looks keep the mode logic.
    border.width: LookService.bodyBorderWidth((function() {
        const mode = PanelState.startMenuBorderMode || "match-bar"
        if (mode === "off") return 0
        if (mode === "thick") return Math.max(2, (PanelState.borderWidth || 1) * 2)
        return PanelState.borderEnabled ? (PanelState.borderWidth || 1) : 1
    })())
    border.color: LookService.bodyBorderColor((function() {
        const mode = PanelState.startMenuBorderMode || "match-bar"
        if (mode === "off") return "transparent"
        if (mode === "match-bar" && PanelState.borderEnabled)
            return PanelState.borderColor
        if (mode === "thick" && PanelState.borderEnabled)
            return PanelState.borderColor
        return ThemeService.alpha(ThemeService.fg, 0.14)
    })())
    clip: true

    // Densho conveniences
    readonly property bool densho: DenshoService.denshoMode
    readonly property color accentColor: densho ? ThemeService.red : ThemeService.blue
    readonly property string fontPrimary: densho
        ? "Noto Serif CJK JP, " + Theme.fontFamily
        : Theme.fontFamily

    // ── Internal state ──
    property string searchQuery: ""
    property string pendingSearch: ""

    // Dynamic grid — read from PanelState; defaults if unset
    readonly property int gridCols: Math.max(3, Math.min(6, PanelState.pinnedGridCols || 4))
    readonly property int gridRows: Math.max(1, Math.min(8, PanelState.pinnedGridRows || 4))

    // Tile sizing — derived from left-pane width
    readonly property real leftPaneWidth: width * 0.58
    readonly property real rightPaneWidth: width * 0.42
    readonly property real tileSize: Math.floor((leftPaneWidth - 48 - (gridCols - 1) * 8) / gridCols)

    // ── Right-click context menu state (hf1) ──
    property bool contextMenuOpen: false
    property var  contextApp: null
    property bool contextIsPinned: false
    property int  contextX: 0
    property int  contextY: 0

    function openContextMenu(app, isPinned, globalX, globalY) {
        contextApp = app
        contextIsPinned = isPinned
        // Clamp to panel bounds — popup is 200×88
        const menuW = 200, menuH = 88
        contextX = Math.max(8, Math.min(globalX, menuRoot.width  - menuW - 8))
        contextY = Math.max(8, Math.min(globalY, menuRoot.height - menuH - 8))
        contextMenuOpen = true
    }
    function closeContextMenu() { contextMenuOpen = false; contextApp = null }

    // ── Inline power-menu state (hf1) ──
    property bool powerMenuOpen: false

    // Search debounce — 100ms
    Timer {
        id: searchDebounce
        interval: 100; repeat: false
        onTriggered: menuRoot.searchQuery = menuRoot.pendingSearch
    }

    onVisibleChanged: {
        RecentFilesService.active = menuRoot.visible
        if (menuRoot.visible) {
            RecentFilesService.refresh()
            searchInput.forceActiveFocus()
        } else {
            menuRoot.searchQuery = ""
            menuRoot.pendingSearch = ""
            searchInput.text = ""
            menuRoot.contextMenuOpen = false
            menuRoot.powerMenuOpen = false
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // TWO-PANE LAYOUT
    //
    // hf3: internal margins are smaller on the bar-facing side (8px
    // vs the default 16px on the away sides). The user pill at the
    // bottom of the left pane already provides visual breathing room,
    // so the extra 16px padding at the bar-facing edge created
    // wasted space when the panel is sticky-anchored. 8px keeps the
    // content from touching the panel border while letting the
    // visual surface feel tightly bonded to the bar.
    // ═══════════════════════════════════════════════════════════════
    RowLayout {
        anchors.fill: parent
        anchors.topMargin:    PanelState.isTop    ? 8 : 16
        anchors.bottomMargin: PanelState.isBottom ? 8 : 16
        anchors.leftMargin:   PanelState.isLeft   ? 8 : 16
        anchors.rightMargin:  PanelState.isRight  ? 8 : 16
        spacing: 12

        // ─────────────────────────────────────────────────────────
        // LEFT PANE — Pinned grid + Recent + User pill
        // ─────────────────────────────────────────────────────────
        ColumnLayout {
            id: leftPane
            Layout.fillHeight: true
            Layout.preferredWidth: menuRoot.leftPaneWidth - 24
            spacing: 12

            // ── PINNED HEADER ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: menuRoot.densho
                    text: "固定"
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: menuRoot.accentColor
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: menuRoot.densho ? "Pinned · Kotei" : "Pinned"
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                    Layout.fillWidth: true
                }
            }

            // ── PINNED GRID — hf1 fix: replaced GridLayout (which
            //    distributes children across the configured row count
            //    and leaves visible gaps when fewer items than slots)
            //    with QtQuick.Grid (packs top-left, no distribution).
            //    Always anchored to the top so partial fills look right.
            Item {
                Layout.fillWidth: true
                // Reserve space for the configured grid size, but the
                // Grid below sits at the TOP — it will only fill the
                // rows it has items for.
                Layout.preferredHeight: menuRoot.gridRows * (menuRoot.tileSize + 8) - 8

                // Empty state — visible only when nothing pinned
                ColumnLayout {
                    visible: AppLauncherService.pinnedIds.length === 0
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf08d"   // pin icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 28
                        color: ThemeService.alpha(ThemeService.fg, 0.3)
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: menuRoot.densho ? "アプリを右クリックで固定" : "Right-click an app to pin"
                        font.family: menuRoot.fontPrimary
                        font.pixelSize: 11
                        color: ThemeService.grey1
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // ═══════════════════════════════════════════════════
                // v7.0.0-alpha.8 — Pinned tiles: SCROLLABLE + DRAGGABLE
                //
                // Replaces v6.16's static Grid with a GridView so that:
                //   1. When pinned items exceed gridCols * gridRows, the
                //      grid scrolls internally instead of overflowing into
                //      the Recent section below
                //   2. Tiles are draggable — long-press + drag rearranges
                //      the order
                //   3. New order persists via AppLauncherService.reorderPinned()
                //      → state file → survives shell restart
                //
                // Drag implementation:
                //   - Each tile has a Drag attached property
                //   - DropArea on the underlying cell receives drops
                //   - On drop, splice the dragged ID into the target position
                //     and call reorderPinned(newOrder)
                // ═══════════════════════════════════════════════════
                GridView {
                    id: pinnedGrid
                    visible: AppLauncherService.pinnedIds.length > 0
                    anchors.fill: parent
                    anchors.topMargin: 0
                    cellWidth: menuRoot.tileSize + 8
                    cellHeight: menuRoot.tileSize + 8
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 200

                    // GridView width is the visible area; cellWidth includes
                    // spacing so columns auto-flow at gridCols
                    width: menuRoot.gridCols * cellWidth

                    // v7.0.0-beta.1-hf2: PINNED DRAG FIX
                    //
                    // Was: `model: AppLauncherService.pinnedApps()` — a
                    // bare function call evaluated ONCE at component
                    // load. When user drags and reorderPinned() mutates
                    // pinnedIds, the function returns a new ordering
                    // but the GridView's model property doesn't see it
                    // because there's no reactive trigger on pinnedIds.
                    //
                    // Fix: bind model to a property that explicitly
                    // depends on AppLauncherService.pinnedIds, so any
                    // mutation forces re-evaluation → GridView rebuilds
                    // delegates in new order → moveDisplaced animates.
                    //
                    // The `+ pinnedIds.length` trick forces dependency
                    // tracking even if pinnedApps() is a plain JS func.
                    readonly property var _pinnedTrigger: AppLauncherService.pinnedIds
                    model: {
                        // Touch the trigger so the binding tracks it
                        const _ = _pinnedTrigger.length
                        return AppLauncherService.pinnedApps()
                    }

                    // Scrollbar — only visible if grid overflows
                    ScrollBar.vertical: ScrollBar {
                        policy: pinnedGrid.contentHeight > pinnedGrid.height
                                ? ScrollBar.AsNeeded
                                : ScrollBar.AlwaysOff
                        width: 5
                        contentItem: Rectangle {
                            radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.3)
                        }
                    }

                    // Smooth move animations when items reorder via drag
                    moveDisplaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                    }

                    delegate: Item {
                        id: tileWrap
                        required property var modelData
                        required property int index

                        width: pinnedGrid.cellWidth
                        height: pinnedGrid.cellHeight

                        // DropArea: detects when another tile is dragged over
                        // this cell. On drop, the source tile's id is spliced
                        // into this position.
                        DropArea {
                            id: tileDrop
                            anchors.fill: parent
                            keys: ["zen-pinned-tile"]

                            onDropped: function(drop) {
                                const sourceId = drop.getDataAsString("zen-pinned-tile")
                                if (!sourceId) return
                                if (sourceId === tileWrap.modelData.id) return

                                // Compute the new ordered list
                                const ids = AppLauncherService.pinnedIds.slice()
                                const fromIdx = ids.indexOf(sourceId)
                                if (fromIdx < 0) return
                                ids.splice(fromIdx, 1)
                                const toIdx = ids.indexOf(tileWrap.modelData.id)
                                if (toIdx < 0) ids.push(sourceId)
                                else ids.splice(toIdx, 0, sourceId)

                                AppLauncherService.reorderPinned(ids)
                                drop.accept()
                            }
                        }

                        // The actual tile rectangle. Has a Drag attached
                        // property so it can be dragged AS a source.
                        Rectangle {
                            id: tile

                            // Slight inset from cell so spacing feels right
                            x: 0
                            y: 0
                            width: menuRoot.tileSize
                            height: menuRoot.tileSize
                            radius: 10

                            // Tile state: highlight when DropArea is active
                            // (something hovering over it), or on hover
                            color: tileDrop.containsDrag
                                ? ThemeService.alpha(menuRoot.accentColor, 0.22)
                                : tileMa.containsMouse
                                  ? ThemeService.alpha(menuRoot.accentColor, 0.14)
                                  : LookService.surfaceColor(ThemeService.bg2, 0.5)
                            border.color: tileDrop.containsDrag
                                ? menuRoot.accentColor
                                : tileMa.containsMouse
                                  ? ThemeService.alpha(menuRoot.accentColor, 0.3)
                                  : ThemeService.alpha(ThemeService.fg, 0.06)
                            border.width: tileDrop.containsDrag ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            // Slightly raised + dimmed appearance while dragging
                            opacity: tileMa.drag.active ? 0.6 : 1.0
                            scale: tileMa.drag.active ? 1.05 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            z: tileMa.drag.active ? 100 : 0

                            // Drag attached property — provides the drag
                            // payload (the app id) and the visual surface
                            // that follows the cursor.
                            Drag.active: tileMa.drag.active
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2
                            Drag.keys: ["zen-pinned-tile"]
                            Drag.mimeData: { "zen-pinned-tile": modelData.id }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    source: Quickshell.iconPath(modelData.icon || "application-x-executable", true)
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                }

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    text: modelData.name || ""
                                    Layout.maximumWidth: menuRoot.tileSize - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: menuRoot.fontPrimary
                                    font.pixelSize: 10
                                    color: ThemeService.fg
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: drag.active
                                             ? Qt.ClosedHandCursor
                                             : Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                // Drag config — drag.target is the tile
                                // itself. drag.threshold ensures a quick
                                // click still launches the app (drag only
                                // engages on sustained movement).
                                drag.target: tile
                                drag.threshold: 8
                                drag.smoothed: false

                                onClicked: function(m) {
                                    if (drag.active) return  // ignore if drag was happening
                                    if (m.button === Qt.RightButton) {
                                        const p = mapToItem(menuRoot, m.x, m.y)
                                        menuRoot.openContextMenu(modelData, true, p.x, p.y)
                                    } else {
                                        AppLauncherService.launch(modelData)
                                        menuRoot.appLaunched()
                                    }
                                }

                                // v7.0.0-beta.1-hf6: PINNED DRAG ACTUALLY-MOVES FIX
                                //
                                // Previous version relied on DropArea.onDropped
                                // to fire on tile release. That requires
                                // `Drag.dragType: Drag.Automatic` plus an
                                // explicit `Drag.drop()` call — neither was
                                // present. So onDropped never fired, and
                                // pinned tiles snapped back without reorder.
                                //
                                // New approach: on release, find the cell
                                // whose center is under the dropped tile and
                                // perform the reorder manually using the
                                // tile's current bounds.
                                onReleased: {
                                    if (drag.active || tile.x !== 0 || tile.y !== 0) {
                                        // Compute the absolute center of the dropped tile
                                        const tileCenterX = tileWrap.x
                                            + tile.x + tile.width / 2
                                        const tileCenterY = tileWrap.y
                                            + tile.y + tile.height / 2

                                        // Convert to GridView local coords (already in GridView)
                                        // and find which cell index that falls into
                                        const colsCount = Math.max(1,
                                            Math.floor(pinnedGrid.width
                                                       / pinnedGrid.cellWidth))
                                        const targetCol = Math.floor(tileCenterX
                                                                     / pinnedGrid.cellWidth)
                                        const targetRow = Math.floor(tileCenterY
                                                                     / pinnedGrid.cellHeight)
                                        const targetIdx = Math.max(0,
                                            Math.min(AppLauncherService.pinnedIds.length - 1,
                                                     targetRow * colsCount + targetCol))

                                        if (targetIdx !== tileWrap.index
                                            && targetIdx >= 0) {
                                            const ids = AppLauncherService.pinnedIds.slice()
                                            const sourceId = tileWrap.modelData.id
                                            const fromIdx = ids.indexOf(sourceId)
                                            if (fromIdx >= 0) {
                                                ids.splice(fromIdx, 1)
                                                ids.splice(Math.min(targetIdx, ids.length),
                                                           0, sourceId)
                                                AppLauncherService.reorderPinned(ids)
                                            }
                                        }
                                    }
                                    // Always snap tile back to home position;
                                    // the GridView re-render will move the delegate
                                    // to its correct new spot.
                                    tile.x = 0
                                    tile.y = 0
                                }
                            }
                        }
                    }
                }
            }

            // ── RECENT HEADER ──
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: menuRoot.densho
                    text: "最近"
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: menuRoot.accentColor
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: menuRoot.densho ? "Recent · Saikin" : "Recent"
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                    Layout.fillWidth: true
                }
            }

            // ── RECENT LIST ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: RecentFilesService.entries.length === 0
                    anchors.centerIn: parent
                    text: menuRoot.densho ? "最近の項目なし" : "No recent files"
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }

                ListView {
                    anchors.fill: parent
                    visible: RecentFilesService.entries.length > 0
                    clip: true
                    spacing: 2
                    cacheBuffer: 200
                    reuseItems: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    model: RecentFilesService.entries.slice(0, 6)

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 40
                        radius: 6
                        color: recMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.06)
                               : "transparent"
                        opacity: modelData.exists ? 1.0 : 0.45

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Image {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                source: Quickshell.iconPath(modelData.iconName, true)
                                sourceSize.width: 44
                                sourceSize.height: 44
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    text: modelData.name || ""
                                    font.family: menuRoot.fontPrimary
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: ThemeService.fg
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    text: {
                                        const age = RecentFilesService.relativeAge(modelData.modified)
                                        const app = modelData.application
                                        if (app && age) return age + " · " + app
                                        return age || app || ""
                                    }
                                    font.family: menuRoot.fontPrimary
                                    font.pixelSize: 10
                                    color: ThemeService.grey1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            id: recMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: modelData.exists
                            onClicked: {
                                RecentFilesService.openEntry(modelData)
                                menuRoot.appLaunched()
                            }
                        }
                    }
                }
            }

            // ── USER PILL — hf1: full row with avatar + folder + settings + power ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 10
                color: LookService.surfaceColor(ThemeService.bg2, 0.6)
                border.color: ThemeService.alpha(ThemeService.fg, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 10

                    // ── AVATAR — hf2: canonical OpacityMask circular pattern,
                    //    matching ZenSettings sidebar + UserProfilePage. The
                    //    previous `clip: true + radius` approach didn't
                    //    actually round the image on all GPU/Quickshell
                    //    builds — this three-component pattern is the
                    //    canonical Qt 5/6 fix for circular avatars.
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: width / 2
                        color: ThemeService.alpha(menuRoot.accentColor, 0.22)
                        border.color: ThemeService.alpha(menuRoot.accentColor, 0.4)
                        border.width: 1
                        antialiasing: true

                        // Hidden source — OpacityMask reads pixels from this
                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            anchors.margins: 2
                            source: (typeof UserProfileService !== "undefined")
                                ? UserProfileService.effectiveAvatarSource
                                : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(64, 64)
                            visible: false   // OpacityMask renders the visible copy
                        }

                        // Hidden circular mask — defines the alpha shape
                        Rectangle {
                            id: avatarMask
                            anchors.fill: avatarImg
                            radius: width / 2
                            color: "white"
                            visible: false
                        }

                        // Visible composited result
                        OpacityMask {
                            anchors.fill: avatarImg
                            source: avatarImg
                            maskSource: avatarMask
                            visible: avatarImg.status === Image.Ready
                                  && avatarImg.source.toString().length > 0
                        }

                        // Fallback letter — only when no avatar image loaded
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            visible: avatarImg.status !== Image.Ready
                                  || avatarImg.source.toString().length === 0
                            text: {
                                const u = (UserProfileService && UserProfileService.userName)
                                    ? UserProfileService.userName
                                    : (Quickshell.env("USER") || "user")
                                return u.length > 0 ? u.charAt(0).toUpperCase() : "?"
                            }
                            font.family: menuRoot.fontPrimary
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: menuRoot.accentColor
                        }
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: (UserProfileService && UserProfileService.userName)
                            ? UserProfileService.userName
                            : (Quickshell.env("USER") || "user")
                        font.family: menuRoot.fontPrimary
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: ThemeService.fg
                        Layout.fillWidth: true
                    }

                    // ── FILES (Thunar) — hf1: invoke thunar directly ──
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: filesMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.08)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "\uf07b"   // folder
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: filesMa.containsMouse
                                ? menuRoot.accentColor
                                : ThemeService.grey0
                        }

                        ToolTip.visible: filesMa.containsMouse
                        ToolTip.delay: 600
                        ToolTip.text: menuRoot.densho ? "ファイル · Files" : "Files (Thunar)"

                        MouseArea {
                            id: filesMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // hf1: launch Thunar specifically; if missing,
                                // fall back to xdg-open ~ silently
                                Quickshell.execDetached({
                                    command: ["sh", "-c",
                                        "command -v thunar >/dev/null && thunar \"$HOME\" || xdg-open \"$HOME\""]
                                })
                                menuRoot.appLaunched()
                            }
                        }
                    }

                    // ── SETTINGS — hf1: opens Zen Settings (toggleSettings IPC) ──
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: setMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.08)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "\uf013"   // gear
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: setMa.containsMouse
                                ? menuRoot.accentColor
                                : ThemeService.grey0
                        }

                        ToolTip.visible: setMa.containsMouse
                        ToolTip.delay: 600
                        ToolTip.text: menuRoot.densho ? "設定 · Settings" : "Settings"

                        MouseArea {
                            id: setMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // ══ v8.0.0-alpha-hf177 — THIS BUTTON DID NOTHING ══
                                //
                                // "dito sa start menu paayos yun settings dapat
                                //  mag open sa settings natin zen control center"
                                //
                                // It flipped `PanelState.settingsVisible`, which
                                // drives the LEGACY settings window — and that
                                // window is mounted behind
                                //
                                //   visible: PanelState.legacyUiEnabled && ...
                                //
                                // in shell.qml. `legacyUiEnabled` defaults to
                                // false and has since the dashboard became the
                                // default UI, so the click toggled a boolean that
                                // nothing was listening to. The start menu closed
                                // and no window ever appeared.
                                //
                                // Settings IS the Zen Control Center now, same as
                                // SUPER+C, the dock's controlcenter slot and the
                                // bar entry. Route there.
                                //
                                // The legacy path is kept for anyone who has
                                // deliberately switched it back on — wala tayong
                                // babawasan.
                                if (PanelState.legacyUiEnabled) {
                                    // v7.0.0-beta.1-hf25: direct toggle to
                                    // avoid spawning second instance if
                                    // current is mid-crash.
                                    PanelState.settingsVisible = !PanelState.settingsVisible
                                } else {
                                    PanelState.dashboardVisible = true
                                }
                                menuRoot.closeRequested()
                            }
                        }
                    }

                    // ── POWER — hf1: expandable popup with 5 actions ──
                    Rectangle {
                        id: powerBtn
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: pwMa.containsMouse || menuRoot.powerMenuOpen
                               ? ThemeService.alpha(ThemeService.red, 0.14)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "\u23fb"
                            font.family: menuRoot.fontPrimary
                            font.pixelSize: 14
                            color: pwMa.containsMouse || menuRoot.powerMenuOpen
                                ? ThemeService.red
                                : ThemeService.grey0
                        }

                        ToolTip.visible: pwMa.containsMouse && !menuRoot.powerMenuOpen
                        ToolTip.delay: 600
                        ToolTip.text: menuRoot.densho ? "電源 · Power" : "Power"

                        MouseArea {
                            id: pwMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.powerMenuOpen = !menuRoot.powerMenuOpen
                        }
                    }
                }
            }
        }

        // ── Vertical divider ──
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: ThemeService.alpha(ThemeService.fg, 0.08)
        }

        // ─────────────────────────────────────────────────────────
        // RIGHT PANE — All Apps (Most Used + alphabetical) + Search
        // ─────────────────────────────────────────────────────────
        ColumnLayout {
            id: rightPane
            Layout.fillHeight: true
            Layout.preferredWidth: menuRoot.rightPaneWidth - 24
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: menuRoot.densho
                    text: "全アプリ"
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: menuRoot.accentColor
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: menuRoot.densho ? "All Apps · Zen Apuri" : "All Apps"
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                    Layout.fillWidth: true
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: AppLauncherService.apps.length
                    font.family: menuRoot.fontPrimary
                    font.pixelSize: 10
                    color: ThemeService.grey1
                }
            }

            ListView {
                id: appsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 1
                cacheBuffer: 200
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                readonly property var _searchResults: menuRoot.searchQuery
                    ? AppLauncherService.searchApps(menuRoot.searchQuery)
                    : null

                model: {
                    if (appsList._searchResults) {
                        return appsList._searchResults.map(function(a){ return { kind: "app", app: a } })
                    }
                    const out = []
                    const mu = AppLauncherService.mostUsed(5)
                    if (mu.length > 0) {
                        out.push({ kind: "header",
                                   text: menuRoot.densho ? "常用 · Most Used · Jōyō" : "Most Used" })
                        for (var i = 0; i < mu.length; i++) out.push({ kind: "app", app: mu[i] })
                        out.push({ kind: "header",
                                   text: menuRoot.densho ? "全て · All · Subete" : "All" })
                    }
                    for (var j = 0; j < AppLauncherService.apps.length; j++) {
                        out.push({ kind: "app", app: AppLauncherService.apps[j] })
                    }
                    return out
                }

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: modelData.kind === "header" ? 28 : 36

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        visible: modelData.kind === "header"
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 6
                        anchors.bottomMargin: 4
                        text: modelData.text || ""
                        font.family: menuRoot.fontPrimary
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        color: ThemeService.grey0
                    }

                    Rectangle {
                        visible: modelData.kind === "app"
                        anchors.fill: parent
                        radius: 6
                        color: appMa.containsMouse
                               ? ThemeService.alpha(menuRoot.accentColor, 0.10)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            visible: menuRoot.densho && appMa.containsMouse
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 2
                            color: ThemeService.red
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Image {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                source: modelData.app
                                    ? Quickshell.iconPath(modelData.app.icon || "application-x-executable", true)
                                    : ""
                                sourceSize.width: 44
                                sourceSize.height: 44
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.app ? (modelData.app.name || "") : ""
                                font.family: menuRoot.fontPrimary
                                font.pixelSize: 12
                                color: ThemeService.fg
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                // v7.0.0-beta.1: explicit bool coercion. isPinned()
                                // can return undefined before AppLauncherService is
                                // fully initialized, causing repeated binding errors.
                                visible: !!(modelData
                                            && modelData.app
                                            && AppLauncherService.isPinned
                                            && AppLauncherService.isPinned(modelData.app.id))
                                text: "\uf08d"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: ThemeService.grey1
                            }
                        }

                        MouseArea {
                            id: appMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(m) {
                                if (m.button === Qt.RightButton) {
                                    // hf1: open context menu instead of immediate toggle
                                    if (modelData.app) {
                                        const isPin = AppLauncherService.isPinned(modelData.app.id)
                                        const p = mapToItem(menuRoot, m.x, m.y)
                                        menuRoot.openContextMenu(modelData.app, isPin, p.x, p.y)
                                    }
                                } else {
                                    if (modelData.app) {
                                        AppLauncherService.launch(modelData.app)
                                        menuRoot.appLaunched()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 8
                color: LookService.surfaceColor(ThemeService.bg2, 0.6)
                border.color: searchInput.activeFocus
                              ? ThemeService.alpha(menuRoot.accentColor, 0.5)
                              : ThemeService.alpha(ThemeService.fg, 0.08)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf002"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: searchInput.activeFocus
                               ? menuRoot.accentColor
                               : ThemeService.grey0
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: menuRoot.densho
                            ? "アプリを検索 · Type to search"
                            : "Type to search"
                        font.family: menuRoot.fontPrimary
                        font.pixelSize: 12
                        color: ThemeService.fg
                        placeholderTextColor: ThemeService.grey1
                        background: Item {}
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onTextChanged: {
                            menuRoot.pendingSearch = text
                            searchDebounce.restart()
                        }
                        Keys.onEscapePressed: {
                            if (text.length > 0) text = ""
                            else menuRoot.closeRequested()
                        }
                        Keys.onReturnPressed: {
                            const results = menuRoot.searchQuery
                                ? AppLauncherService.searchApps(menuRoot.searchQuery)
                                : AppLauncherService.apps
                            if (results.length > 0) {
                                AppLauncherService.launch(results[0])
                                menuRoot.appLaunched()
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // POWER POPUP MENU (hf1) — appears above the power button
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: powerPopup
        visible: menuRoot.powerMenuOpen
        width: 200
        height: powerCol.implicitHeight + 16
        radius: 10
        color: Qt.rgba(ThemeService.bg1.r, ThemeService.bg1.g, ThemeService.bg1.b, 0.98)
        border.color: ThemeService.alpha(ThemeService.fg, 0.14)
        border.width: 1
        z: 100

        // Anchor near the bottom-right of the left pane (above the user pill)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: parent.width - menuRoot.leftPaneWidth + 8
        anchors.bottomMargin: 72

        opacity: menuRoot.powerMenuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        ColumnLayout {
            id: powerCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 1

            Repeater {
                model: [
                    { icon: "\uf023", label: menuRoot.densho ? "Lock · 施錠" : "Lock",
                      action: "lock",     cmd: "hyprlock",                destructive: false },
                    { icon: "\uf186", label: menuRoot.densho ? "Suspend · 休眠" : "Suspend",
                      action: "suspend",  cmd: "systemctl suspend",       destructive: false },
                    { icon: "\uf2f5", label: menuRoot.densho ? "Logout · 退出" : "Logout",
                      action: "logout",   cmd: "hyprctl dispatch exit",   destructive: false },
                    { icon: "\uf021", label: menuRoot.densho ? "Restart · 再起動" : "Restart",
                      action: "reboot",   cmd: "systemctl reboot",        destructive: false },
                    { icon: "\uf011", label: menuRoot.densho ? "Shutdown · 終了" : "Shutdown",
                      action: "shutdown", cmd: "systemctl poweroff",      destructive: true  }
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 6
                    color: itemMa.containsMouse
                           ? ThemeService.alpha(modelData.destructive ? ThemeService.red : menuRoot.accentColor, 0.14)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: itemMa.containsMouse
                                ? (modelData.destructive ? ThemeService.red : menuRoot.accentColor)
                                : ThemeService.grey0
                            Layout.preferredWidth: 18
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: modelData.label
                            font.family: menuRoot.fontPrimary
                            font.pixelSize: 12
                            color: itemMa.containsMouse
                                ? (modelData.destructive ? ThemeService.red : ThemeService.fg)
                                : ThemeService.fg
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menuRoot.powerMenuOpen = false
                            menuRoot.powerActionRequested(modelData.action, modelData.cmd)
                        }
                    }
                }
            }
        }
    }

    // Click-outside-to-close for power menu
    MouseArea {
        anchors.fill: parent
        visible: menuRoot.powerMenuOpen
        z: 99
        onClicked: menuRoot.powerMenuOpen = false
    }

    // ═══════════════════════════════════════════════════════════════
    // RIGHT-CLICK CONTEXT MENU (hf1) — Pin/Unpin + Cancel
    // ═══════════════════════════════════════════════════════════════
    MouseArea {
        // Click-outside-to-close
        anchors.fill: parent
        visible: menuRoot.contextMenuOpen
        z: 199
        onClicked: menuRoot.closeContextMenu()
    }

    Rectangle {
        id: contextMenu
        visible: menuRoot.contextMenuOpen
        x: menuRoot.contextX
        y: menuRoot.contextY
        z: 200
        width: 200
        height: 88
        radius: 10
        color: Qt.rgba(ThemeService.bg1.r, ThemeService.bg1.g, ThemeService.bg1.b, 0.98)
        border.color: ThemeService.alpha(ThemeService.fg, 0.16)
        border.width: 1

        opacity: menuRoot.contextMenuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 1

            // ── Pin / Unpin row ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 6
                color: pinRowMa.containsMouse
                       ? ThemeService.alpha(menuRoot.accentColor, 0.14)
                       : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: menuRoot.contextIsPinned ? "\uf08d" : "\uf08d"   // pin glyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: pinRowMa.containsMouse ? menuRoot.accentColor : ThemeService.grey0
                        Layout.preferredWidth: 18
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: menuRoot.contextIsPinned
                            ? (menuRoot.densho ? "Unpin · 解除" : "Unpin from Start")
                            : (menuRoot.densho ? "Pin · 固定"  : "Pin to Start")
                        font.family: menuRoot.fontPrimary
                        font.pixelSize: 12
                        color: ThemeService.fg
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: pinRowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (menuRoot.contextApp) {
                            if (menuRoot.contextIsPinned)
                                AppLauncherService.unpin(menuRoot.contextApp.id)
                            else
                                AppLauncherService.pin(menuRoot.contextApp.id)
                        }
                        menuRoot.closeContextMenu()
                    }
                }
            }

            // ── Cancel row ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 6
                color: cancelRowMa.containsMouse
                       ? ThemeService.alpha(ThemeService.fg, 0.06)
                       : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf00d"   // x
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: ThemeService.grey0
                        Layout.preferredWidth: 18
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: menuRoot.densho ? "Cancel · 取消" : "Cancel"
                        font.family: menuRoot.fontPrimary
                        font.pixelSize: 12
                        color: ThemeService.grey1
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: cancelRowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menuRoot.closeContextMenu()
                }
            }
        }
    }
}
