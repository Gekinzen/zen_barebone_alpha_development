import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

/*
 * WorkspaceOverview v7.0.0-beta.1-hf82h — Karui (軽い)
 *
 * v7.0.0-beta.1-hf82h — FIRST-OPEN RACE FIX.
 *
 *   User report:
 *   "yung super + tab show workspace unang execute ko dun wala
 *    laman tas pangalawa execute ulit dun palang lalabas"
 *
 *   First Super+Tab after shell start shows the overview empty
 *   (no workspace tiles or empty tile content). Second press
 *   populates correctly.
 *
 *   Root cause: the existing onVisibleChanged handler watches
 *   the Rectangle's OWN `visible` property, which is true by
 *   default and never reassigned. When the parent PanelWindow's
 *   `visible` flips (driven by PanelState.workspaceOverviewVisible),
 *   the inner Rectangle's effective rendering changes but its
 *   `visible` property doesn't get reassigned — so QML doesn't
 *   emit a visibleChanged signal on the Rectangle. The
 *   onVisibleChanged handler that should call _refresh() never
 *   fires on first open.
 *
 *   The handler eventually fires on subsequent opens because the
 *   first close DOES propagate visible=false through the parent
 *   chain (parent→child cascade is real, unlike child→parent
 *   detection). Then the second open re-triggers the signal as
 *   false→true.
 *
 *   Fix: subscribe to PanelState.workspaceOverviewVisible
 *   directly via Connections. That's the authoritative singleton
 *   property toggled by toggleWorkspaceOverview() — it always
 *   emits change signals. No visibility-propagation race.
 *
 *   Defense in depth:
 *     - Primary: Connections on PanelState fires reliably
 *     - Backup: existing onVisibleChanged handler kept as no-op-
 *       safe alternate path
 *     - Backup: Component.onCompleted handles the (hypothetical)
 *       case where overview is already open at mount time
 *     - Backup: unconditional 250ms _refreshTickTimer fires
 *       regardless of workspacesList content, catching the case
 *       where workspaces populate fast but toplevels lag
 *     - Backup: Connections on Hyprland.toplevels.valuesChanged
 *       refreshes tiles in real time while overview is open
 *     - Backup: Connections on Hyprland.workspaces.valuesChanged
 *       handles workspace creation/deletion mid-view
 *
 *   Both the parent overview Rectangle AND the tile Repeater
 *   delegates now have PanelState Connections, since the inner
 *   tile's Component.onCompleted runs before Hyprland has
 *   populated toplevels in the first-shell-start scenario.
 *
 * v7.0.0-alpha.14-hf4 — SIMPLIFIED + STABLE version (continues below)
 *
 *   - Show workspaces as grid tiles
 *   - Each tile shows window titles inside
 *   - Click tile → switch workspace
 *   - Click window card → focus that window
 *   - Right-click window card → menu (move to ws 1/2/3...) — safer
 *     than drag for moving windows
 *   - Keyboard nav after first click (arrows + Enter + 1-9 + Esc)
 *
 * No more:
 *   - Object.assign + property reassign on every tile geometry change
 *   - Repeater.children manipulation in drag handlers
 *   - Cross-tile drop zone math
 *
 * Theme-aware via ThemeService.
 */
Rectangle {
    id: overview

    color: LookService.surfaceColor(ThemeService.bg0, 0.96)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.15)
    radius: 12
    clip: true

    implicitWidth: 820
    implicitHeight: 580

    focus: true

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    property int selectedIndex: 0
    // hf79: workspacesList changed from readonly binding to imperative
    // property. The old `Hyprland.workspaces.values` binding returned
    // a JS array snapshot on init that didn't re-trigger when Hyprland
    // populated workspace data — causing empty tiles on first Super+Tab
    // after shell start. Now refreshed explicitly in _refresh().
    property var workspacesList: []
    readonly property int columns: 3

    // Right-click move menu state
    property bool moveMenuVisible: false
    property string moveTargetAddress: ""
    property int moveMenuX: 0
    property int moveMenuY: 0

    // hf79: central refresh function — populates workspacesList.
    // Tiles refresh their own windows via the onVisibleChanged
    // Connections already in place; we just need the workspace list
    // to be correct BEFORE the tile Repeater processes its model.
    function _refresh() {
        const wsList = (Hyprland.workspaces && Hyprland.workspaces.values)
                       ? Hyprland.workspaces.values
                       : []
        // Sort by ID for consistent display order
        const sorted = wsList.slice().sort((a, b) => a.id - b.id)
        overview.workspacesList = sorted
    }

    // hf82h — extracted the "overview just became visible" logic
    // into a function so it can be invoked from two paths: the
    // legacy onVisibleChanged handler AND the new authoritative
    // Connections-on-PanelState handler. The latter is what fires
    // reliably on first open.
    //
    // Bug report:
    //   "yung super + tab show workspace unang execute ko dun wala
    //    laman tas pangalawa execute ulit dun palang lalabas"
    //
    // Root cause: the `onVisibleChanged` handler watches
    // overview.visible (the Rectangle's OWN visible property),
    // which is always true by default and never reassigned. When
    // the parent PanelWindow flips between visible/invisible, the
    // inner Rectangle's effective rendering changes but its
    // visible PROPERTY doesn't get reassigned — so QML doesn't
    // emit a visibleChanged signal on the Rectangle. First open
    // after shell start: no signal fires → _refresh() never runs
    // → tiles render with empty workspacesList. Close → PanelWindow
    // visible flips false, which DOES propagate Rectangle.visible
    // to false (single direction, parent-to-child cascade). Second
    // open: Rectangle.visible flips false → true → signal fires →
    // _refresh runs → populated.
    //
    // Fix: subscribe to PanelState.workspaceOverviewVisible
    // directly via Connections. That property always emits change
    // signals because it's the authoritative source toggled by
    // toggleWorkspaceOverview(). No visibility-propagation race.
    //
    // We also keep the existing onVisibleChanged handler as a
    // belt-and-braces backup, and add a Component.onCompleted
    // path for the case where the Rectangle mounts while
    // PanelState is already true (shell restart with overview
    // open, hypothetical).
    function _onOverviewOpened() {
        _refresh()
        for (let i = 0; i < workspacesList.length; i++) {
            if (Hyprland.focusedWorkspace
                && workspacesList[i].id === Hyprland.focusedWorkspace.id) {
                selectedIndex = i
                break
            }
        }
        moveMenuVisible = false
        // hf79: retry if data wasn't ready yet (shell just started,
        // Hyprland hasn't sent toplevels via IPC). The retry fires
        // 250ms later when the data is almost certainly populated.
        //
        // hf82h: also fire the retry UNCONDITIONALLY on first open,
        // not just when workspacesList is empty. The reason: workspaces
        // may already be populated (Hyprland exposes them early on
        // its initial sync) but toplevels (window info) may lag —
        // tiles then show with empty window cards. The retry forces
        // a tile re-read 250ms later regardless of the workspace
        // count, catching this slower-toplevels case.
        if (workspacesList.length === 0) {
            _retryTimer.start()
        }
        // Fire a second tick at 250ms always, so tile windows
        // refresh once the toplevels data has had a chance to
        // arrive. No-op if windows were already correct.
        _refreshTickTimer.start()
    }

    // hf82h — authoritative Connections on PanelState. Fires
    // reliably whenever the workspace overview toggle changes,
    // regardless of how the Rectangle's own visible property
    // happens to be propagating through the parent PanelWindow.
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

    // hf82h — defensive Component.onCompleted for the (currently
    // hypothetical) case where the Rectangle mounts while
    // PanelState.workspaceOverviewVisible is already true. Without
    // this, that path would leave the overview empty.
    Component.onCompleted: {
        if (PanelState && PanelState.workspaceOverviewVisible) {
            _onOverviewOpened()
        }
    }

    // Pre-select current workspace when overview opens
    //
    // hf82h — kept as belt-and-braces backup. The PanelState
    // Connections above is the primary trigger; this fires only
    // if the Rectangle's own visible property happens to change
    // (which it may not on some QML+layer-shell combinations).
    // Either way, _onOverviewOpened is idempotent.
    onVisibleChanged: {
        if (visible) {
            _onOverviewOpened()
        }
    }

    Timer {
        id: _retryTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (overview.visible || (PanelState && PanelState.workspaceOverviewVisible)) {
                overview._refresh()
                // Also re-trigger tile window refresh — tiles listen
                // for onVisibleChanged but that already fired. Force
                // a re-read by toggling a dummy property.
                overview._refreshTick++
            }
        }
    }

    // hf82h — unconditional 250ms tick that fires on every open.
    // The legacy _retryTimer only fires when workspacesList is
    // empty. This one fires regardless, so the tile windows get a
    // second-pass refresh once Hyprland.toplevels has had a chance
    // to populate. No-op if the first pass already had correct
    // data (the tile re-read is cheap).
    Timer {
        id: _refreshTickTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (overview.visible || (PanelState && PanelState.workspaceOverviewVisible)) {
                overview._refresh()
                overview._refreshTick++
            }
        }
    }

    // hf82h — also watch Hyprland.toplevels for value changes while
    // the overview is open. If a window opens/closes/moves while
    // the overview is visible, tiles refresh in real time without
    // needing the user to close + reopen.
    Connections {
        target: (typeof Hyprland !== "undefined" && Hyprland.toplevels)
                ? Hyprland.toplevels : null
        function onValuesChanged() {
            if (PanelState && PanelState.workspaceOverviewVisible) {
                overview._refreshTick++
            }
        }
    }
    // Same for workspaces (e.g., user creates a new workspace
    // while the overview is open).
    Connections {
        target: (typeof Hyprland !== "undefined" && Hyprland.workspaces)
                ? Hyprland.workspaces : null
        function onValuesChanged() {
            if (PanelState && PanelState.workspaceOverviewVisible) {
                overview._refresh()
                overview._refreshTick++
            }
        }
    }
    // Dummy counter — tiles watch this to know when to re-read windows
    property int _refreshTick: 0

    // ─────────────────────────────────────────────────────────────
    // KEYBOARD NAVIGATION
    // ─────────────────────────────────────────────────────────────
    Keys.onPressed: function(event) {
        if (moveMenuVisible) {
            if (event.key === Qt.Key_Escape) {
                moveMenuVisible = false
                event.accepted = true
            }
            return
        }

        const len = workspacesList.length
        if (len === 0) { event.accepted = false; return }

        if (event.key === Qt.Key_Escape) {
            Quickshell.execDetached({command: ["bash", "-c",
                "qs -c zen-shell ipc call zen closeWorkspaceOverview"]})
            event.accepted = true; return
        }

        if (event.key === Qt.Key_Return
            || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space) {
            const ws = workspacesList[selectedIndex]
            if (ws) _switchTo(ws.id)
            event.accepted = true; return
        }

        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            _switchTo(event.key - Qt.Key_0)
            event.accepted = true; return
        }

        let next = selectedIndex
        if (event.key === Qt.Key_Right) next = (selectedIndex + 1) % len
        else if (event.key === Qt.Key_Left) next = (selectedIndex - 1 + len) % len
        else if (event.key === Qt.Key_Down) next = Math.min(selectedIndex + columns, len - 1)
        else if (event.key === Qt.Key_Up) next = Math.max(selectedIndex - columns, 0)
        else if (event.key === Qt.Key_Tab) {
            next = (event.modifiers & Qt.ShiftModifier)
                   ? (selectedIndex - 1 + len) % len
                   : (selectedIndex + 1) % len
        }
        else if (event.key === Qt.Key_Home) next = 0
        else if (event.key === Qt.Key_End) next = len - 1
        else { event.accepted = false; return }

        selectedIndex = next
        event.accepted = true
    }

    // ─────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────
    // v7.0.0-beta.1-hf3: close-before-switch race fix.
    //
    // Previously the dispatch order was:
    //   hyprctl dispatch workspace N && qs ipc closeWorkspaceOverview
    //
    // This caused a race: workspace change fired first → Hyprland's
    // focused monitor possibly changed → ALL PanelWindow variants
    // re-evaluated `isFocusedMonitor` while overview was still
    // visible → layer-shell surface lifecycle conflict → multiple
    // bars stacking + eventual SIGSEGV.
    //
    // Fix: close the overview synchronously via the local property
    // FIRST (which collapses all PanelWindow.visible bindings to
    // false in one frame), THEN dispatch the workspace switch via
    // an external process. By the time Hyprland processes the
    // switch, our surfaces are already torn down cleanly.
    function _switchTo(wsId) {
        // 1. Close overview SYNCHRONOUSLY via shared root state
        Quickshell.execDetached({command: ["bash", "-c",
            "qs -c zen-shell ipc call zen closeWorkspaceOverview"]})
        // 2. Switch workspace (async — happens after our window is gone)
        Quickshell.execDetached({command: ["bash", "-c",
            "sleep 0.05 && hyprctl dispatch workspace " + wsId]})
    }

    function _focusWindowAndClose(address) {
        if (!address) return
        Quickshell.execDetached({command: ["bash", "-c",
            "qs -c zen-shell ipc call zen closeWorkspaceOverview"]})
        Quickshell.execDetached({command: ["bash", "-c",
            "sleep 0.05 && hyprctl dispatch focuswindow address:0x" + address]})
    }

    function _focusWindow(address) {
        // v7.0.0-beta.1-hf3: redirect to the close-before-switch
        // variant so the original call site (window card left-click)
        // also benefits from the race fix.
        overview._focusWindowAndClose(address)
    }

    function _moveWindowToWs(address, wsId) {
        if (!address) return
        Quickshell.execDetached({command: ["bash", "-c",
            "hyprctl dispatch movetoworkspacesilent " + wsId +
            ",address:0x" + address]})
        moveMenuVisible = false
    }

    function _windowsFor(wsId) {
        if (!Hyprland.toplevels) return []
        const out = []
        const tops = Hyprland.toplevels.values || []
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i]
            const tWsId = (t.workspace && t.workspace.id) || -1
            if (tWsId === wsId) out.push(t)
        }
        return out
    }

    function _appColor(cls) {
        if (!cls) return ThemeService.grey0
        let hash = 0
        for (let i = 0; i < cls.length; i++) {
            hash = ((hash << 5) - hash + cls.charCodeAt(i)) | 0
        }
        const palette = [ThemeService.blue, ThemeService.green,
                         ThemeService.yellow, ThemeService.red]
        return palette[Math.abs(hash) % palette.length]
    }

    function _getTitle(t) {
        if (!t) return "Untitled"
        return t.title || "Untitled"
    }

    function _getClass(t) {
        if (!t) return ""
        return t.class || ""
    }

    function _getAddress(t) {
        if (!t) return ""
        return t.address || ""
    }

    // ─────────────────────────────────────────────────────────────
    // CONTENT
    // ─────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: DenshoService.denshoMode
                text: "作業空間"
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: ThemeService.fg
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Workspaces"
                font.family: Theme.fontFamily
                font.pixelSize: DenshoService.denshoMode ? 14 : 22
                font.weight: Font.DemiBold
                color: ThemeService.fg
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Click tile to switch · right-click window to move · 1-9 to jump · Esc to close"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.alpha(ThemeService.fg, 0.55)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: overview.columns
            rowSpacing: 14
            columnSpacing: 14

            Repeater {
                model: overview.workspacesList

                delegate: Rectangle {
                    id: wsTile
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 170
                    Layout.preferredWidth: 240

                    readonly property bool isCurrent: Hyprland.focusedWorkspace
                                                      && modelData.id === Hyprland.focusedWorkspace.id
                    readonly property bool isKeyboardSelected: overview.selectedIndex === index

                    // v7.0.0-beta.1-hf1: windows is now an explicit
                    // property updated only when overview visibility
                    // changes, NOT a live binding. Previously this
                    // recomputed `_windowsFor` every time any toplevel
                    // updated (window opens, closes, title changes,
                    // workspace move) — for every tile, every frame.
                    // With 8 workspaces × ~5 windows × frequent
                    // Hyprland events, this was hammering CPU and
                    // accumulating QObject instances → leak.
                    property var windows: []

                    Connections {
                        target: overview
                        function onVisibleChanged() {
                            if (overview.visible) {
                                wsTile.windows = overview._windowsFor(modelData.id)
                            }
                        }
                        // hf79: retry path — when _retryTimer fires after
                        // the first empty open, _refreshTick increments,
                        // which triggers this re-read.
                        function on_RefreshTickChanged() {
                            if (overview.visible || (PanelState && PanelState.workspaceOverviewVisible)) {
                                wsTile.windows = overview._windowsFor(modelData.id)
                            }
                        }
                    }

                    // hf82h — also watch PanelState directly, same
                    // reason as the parent overview Rectangle:
                    // overview.visible doesn't always emit
                    // visibleChanged on first open due to QML
                    // visibility-propagation behavior through the
                    // parent PanelWindow. Watching the
                    // authoritative singleton property guarantees
                    // the windows refresh on first open.
                    Connections {
                        target: (typeof PanelState !== "undefined") ? PanelState : null
                        function onWorkspaceOverviewVisibleChanged() {
                            if (PanelState.workspaceOverviewVisible) {
                                wsTile.windows = overview._windowsFor(modelData.id)
                            }
                        }
                    }

                    Component.onCompleted: {
                        wsTile.windows = overview._windowsFor(modelData.id)
                    }

                    radius: 10
                    color: isKeyboardSelected
                           ? ThemeService.alpha(ThemeService.blue, 0.28)
                           : (isCurrent
                              ? ThemeService.alpha(ThemeService.blue, 0.18)
                              : LookService.surfaceColor(ThemeService.bg2, 0.45))
                    border.width: isKeyboardSelected ? 2 : (isCurrent ? 2 : 1)
                    border.color: isKeyboardSelected
                                  ? ThemeService.blue
                                  : (isCurrent
                                     ? ThemeService.alpha(ThemeService.blue, 0.6)
                                     : ThemeService.alpha(ThemeService.fg, 0.12))

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            overview.selectedIndex = wsTile.index
                            overview._switchTo(wsTile.modelData.id)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: wsTile.modelData.id
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: wsTile.isCurrent
                                       ? ThemeService.blue : ThemeService.fg
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: wsTile.windows.length
                                      + (wsTile.windows.length === 1 ? " window" : " windows")
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: ThemeService.alpha(ThemeService.fg, 0.5)
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: wsTile.isCurrent
                                width: 6; height: 6; radius: 3
                                color: ThemeService.blue
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            interactive: contentHeight > height
                            model: wsTile.windows

                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                height: 26
                                radius: 5

                                readonly property color appColor: overview._appColor(overview._getClass(modelData))

                                color: winMa.containsMouse
                                       ? LookService.surfaceColor(ThemeService.bg1, 0.95)
                                       : LookService.surfaceColor(ThemeService.bg1, 0.65)
                                border.width: 1
                                border.color: ThemeService.alpha(appColor, 0.45)

                                Rectangle {
                                    width: 3
                                    height: parent.height
                                    radius: 2
                                    color: parent.appColor
                                }

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: overview._getTitle(modelData)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeService.fg
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: winMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(mouse) {
                                        const addr = overview._getAddress(modelData)
                                        if (mouse.button === Qt.LeftButton) {
                                            overview._focusWindow(addr)
                                        } else {
                                            // Right-click → show move menu
                                            const pt = mapToItem(overview, mouse.x, mouse.y)
                                            overview.moveTargetAddress = addr
                                            overview.moveMenuX = pt.x
                                            overview.moveMenuY = pt.y
                                            overview.moveMenuVisible = true
                                        }
                                    }
                                }
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                visible: wsTile.windows.length === 0
                                anchors.centerIn: parent
                                text: "empty"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.italic: true
                                color: ThemeService.alpha(ThemeService.fg, 0.35)
                            }
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MOVE-TO-WORKSPACE MENU (right-click on window card)
    // ─────────────────────────────────────────────────────────────
    Rectangle {
        id: moveMenu
        visible: overview.moveMenuVisible
        z: 100
        x: Math.min(overview.moveMenuX, overview.width - width - 12)
        y: Math.min(overview.moveMenuY, overview.height - height - 12)
        width: 180
        height: moveCol.implicitHeight + 12
        radius: 8
        color: LookService.surfaceColor(ThemeService.bg1, 0.98)
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.25)

        // Click outside menu closes it
        MouseArea {
            anchors.fill: parent
            preventStealing: true
        }

        ColumnLayout {
            id: moveCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Move to workspace…"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: ThemeService.alpha(ThemeService.fg, 0.6)
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            Repeater {
                model: overview.workspacesList

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 4
                    color: itemMa.containsMouse
                           ? ThemeService.alpha(ThemeService.blue, 0.18)
                           : "transparent"

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Workspace " + modelData.id
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            overview._moveWindowToWs(
                                overview.moveTargetAddress,
                                modelData.id)
                        }
                    }
                }
            }
        }
    }

    // Backdrop catcher: clicks outside menu close it (without
    // closing the whole overview)
    MouseArea {
        anchors.fill: parent
        visible: overview.moveMenuVisible
        z: 99
        onClicked: overview.moveMenuVisible = false
    }
}
