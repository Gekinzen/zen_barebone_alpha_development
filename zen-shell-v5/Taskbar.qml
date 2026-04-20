import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/*
 * Taskbar.qml v6.12
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

    // v6.12: maxVisibleWidth caps how wide the taskbar can grow.
    // Beyond this, chevron < > buttons appear and content scrolls.
    readonly property int maxVisibleWidth: 440
    readonly property int btnSize: 40
    readonly property int btnSpacing: 4
    readonly property int chevronWidth: 24
    readonly property bool hasOverflow: taskbarRow.implicitWidth > maxVisibleWidth

    // Clamp implicitWidth so bar doesn't stretch infinitely
    implicitWidth: Math.min(taskbarRow.implicitWidth + 60, maxVisibleWidth + (hasOverflow ? chevronWidth * 2 + 16 : 0) + 24)
    height: 48
    radius: Theme.moduleRadius
    color: Theme.alpha(Theme.bg0, 0.9)
    border.width: 1
    border.color: Theme.bg1

    readonly property string nfPin: "\uf0403"
    readonly property string nfUnpin: "\uf0404"
    readonly property string nfClose: "\uf0156"
    readonly property string nfWindow: "\uf024d"

    property var pinnedApps: ["kitty", "firefox", "code"]
    property string popupAppId: ""
    property string ctxAppId: ""

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
        return groups
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

    function safeCloseAll(appId) {
        const ws = groupedApps[appId.toLowerCase()] || []
        for (const w of ws) safeClose(w)
    }

    Process { id: closeHelper; running: false }

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
    readonly property int maxScroll: Math.max(0, taskbarRow.implicitWidth - maxVisibleWidth)

    // Clamp scroll when app list shrinks (e.g. windows close)
    onMaxScrollChanged: {
        if (scrollOffset > maxScroll) scrollOffset = maxScroll
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 4

        // ── Left chevron ──
        Rectangle {
            visible: taskbarRoot.hasOverflow && taskbarRoot.scrollOffset > 0
            Layout.preferredWidth: taskbarRoot.chevronWidth
            Layout.preferredHeight: 32
            radius: 8
            color: chevLeftMa.containsMouse ? Theme.bg3 : Theme.bg2
            Text {
                anchors.centerIn: parent
                text: "\u276E"  // ❮
                color: Theme.fg
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
            Layout.preferredWidth: taskbarRoot.hasOverflow ? taskbarRoot.maxVisibleWidth : taskbarRow.implicitWidth
            Layout.preferredHeight: 44
            clip: true

            RowLayout {
                id: taskbarRow
                y: (parent.height - height) / 2
                x: -taskbarRoot.scrollOffset
                spacing: 4

                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Repeater {
                    model: taskbarRoot.appList

            Rectangle {
                id: appBtn
                property var appData: modelData
                property string appId: appData.id
                property bool isRunning: appData.running
                property bool isPinned: appData.pinned
                property int windowCount: appData.windowCount
                property bool isActive: {
                    const atl = ToplevelManager.activeToplevel
                    return atl ? (atl.appId || "").toLowerCase() === appId.toLowerCase() : false
                }
                property var entry: taskbarRoot.findEntry(appId)

                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 13
                color: isActive ? Theme.blue : ma.containsMouse ? Theme.bg3 : Theme.bg1
                Behavior on color { ColorAnimation { duration: 200 } }

                Image {
                    anchors.centerIn: parent
                    width: 24; height: 24
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

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            if (!isRunning && entry) {
                                entry.execute()
                            } else if (windowCount === 1) {
                                const w = taskbarRoot.groupedApps[appId.toLowerCase()] || []
                                if (w.length > 0) w[0].activate()
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
                PopupWindow {
                    anchor.item: appBtn
                    anchor.edges: Edges.Top
                    anchor.gravity: Edges.Top
                    visible: taskbarRoot.popupAppId === appId && windowCount > 1
                    width: 240
                    height: Math.min(winCol.implicitHeight + 16, 300)
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.alpha(Theme.bg0, 0.95)
                        border.width: 1; border.color: Theme.bg1

                        ColumnLayout {
                            id: winCol
                            anchors.fill: parent; anchors.margins: 8; spacing: 4

                            Text {
                                text: entry ? entry.name : appId
                                color: Theme.fgDim; font.family: Theme.fontFamily
                                font.pixelSize: 11; font.bold: true; leftPadding: 4
                            }

                            Repeater {
                                model: taskbarRoot.groupedApps[appId.toLowerCase()] || []

                                Rectangle {
                                    Layout.fillWidth: true; height: 32; radius: 8
                                    color: wma.containsMouse ? Theme.bg2 : "transparent"
                                    property var tl: modelData

                                    // v6.9: wma FIRST (bottom of z-stack) so close X button is on top
                                    MouseArea {
                                        id: wma
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { tl.activate(); taskbarRoot.popupAppId = "" }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                        // z above wma so children receive clicks first
                                        z: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: { const t = tl.title || "Untitled"; return t.length > 28 ? t.substring(0, 25) + "..." : t }
                                            color: tl.activated ? Theme.blue : Theme.fg
                                            elide: Text.ElideRight; font.family: Theme.fontFamily; font.pixelSize: 12
                                        }

                                        // Close button — larger click area, on top of wma
                                        Rectangle {
                                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                            radius: 12
                                            color: closeWinMa.containsMouse ? Theme.alpha(Theme.red, 0.2) : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\u2715"
                                                color: closeWinMa.containsMouse ? Theme.red : Theme.fgDim
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
                    }
                }

                // ── Context Menu ──
                PopupWindow {
                    anchor.item: appBtn
                    anchor.edges: Edges.Top
                    anchor.gravity: Edges.Top
                    visible: taskbarRoot.ctxAppId === appId
                    width: 180
                    height: ctxCol.implicitHeight + 16
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.alpha(Theme.bg0, 0.95)
                        border.width: 1; border.color: Theme.bg1

                        ColumnLayout {
                            id: ctxCol
                            anchors.fill: parent; anchors.margins: 8; spacing: 2

                            // Pin/Unpin
                            Rectangle {
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: pma.containsMouse ? Theme.bg2 : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                    Text { text: isPinned ? taskbarRoot.nfUnpin : taskbarRoot.nfPin; color: "#ffffff"; font.family: Theme.monoFont; font.pixelSize: 14 }
                                    Text { text: isPinned ? "Unpin" : "Pin to taskbar"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (isPinned) taskbarRoot.unpinApp(appId); else taskbarRoot.pinApp(appId); taskbarRoot.ctxAppId = "" }
                                }
                            }

                            // New window
                            Rectangle {
                                visible: entry !== null
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: nma.containsMouse ? Theme.bg2 : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                    Text { text: taskbarRoot.nfWindow; color: "#ffffff"; font.family: Theme.monoFont; font.pixelSize: 14 }
                                    Text { text: "New window"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 12 }
                                }
                                MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (entry) entry.execute(); taskbarRoot.ctxAppId = "" }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.alpha(Theme.fg, 0.08) }

                            // v6.9: Close all — uses safeCloseAll
                            Rectangle {
                                visible: isRunning
                                Layout.fillWidth: true; height: 32; radius: 8
                                color: cma.containsMouse ? Theme.alpha(Theme.red, 0.15) : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                    Text { text: taskbarRoot.nfClose; color: Theme.red; font.family: Theme.monoFont; font.pixelSize: 14 }
                                    Text { text: windowCount > 1 ? "Close all (" + windowCount + ")" : "Close"; color: Theme.red; font.family: Theme.fontFamily; font.pixelSize: 12 }
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
        }  // end RowLayout (taskbarRow)
        }  // end Item (clip viewport)

        // ── Right chevron ──
        Rectangle {
            visible: taskbarRoot.hasOverflow && taskbarRoot.scrollOffset < taskbarRoot.maxScroll
            Layout.preferredWidth: taskbarRoot.chevronWidth
            Layout.preferredHeight: 32
            radius: 8
            color: chevRightMa.containsMouse ? Theme.bg3 : Theme.bg2
            Text {
                anchors.centerIn: parent
                text: "\u276F"  // ❯
                color: Theme.fg
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
