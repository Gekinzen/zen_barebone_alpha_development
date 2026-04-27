import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * ZenNotificationCenter v6.16.4.12
 *
 * Unified panel that opens on clock click:
 *   ┌──────────────────────────┐
 *   │ 🔔 Notifications  [N]   │  ← count + open swaync
 *   ├──────────────────────────┤
 *   │    ◀ April 2026 ▶       │  ← full calendar
 *   │   Su Mo Tu We Th Fr Sa  │
 *   │   ...                   │
 *   ├──────────────────────────┤
 *   │ BT  WiFi  Lock  Logout  │  ← system quick-actions
 *   │ Restart   Shutdown       │
 *   └──────────────────────────┘
 *
 * Replaces the old standalone ZenCalendar popup.
 * Notifications top, calendar center, system icons bottom.
 */
Rectangle {
    id: root

    signal closeRequested()
    signal powerActionRequested(string action, string command)

    // ── Calendar state ──
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var today: new Date()
    readonly property int todayDay: today.getDate()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayYear: today.getFullYear()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayHeaders: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    // ── Notification state ──
    property int notifCount: 0
    property bool dndEnabled: false

    // ── Sizing ──
    width: 310
    height: mainLayout.implicitHeight + 28
    radius: Theme.panelRadius !== undefined ? Math.min(Theme.panelRadius, 16) : 12
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)

    Keys.onEscapePressed: closeRequested()

    // ── Notification poller ──
    Process {
        id: notifPoll
        command: ["swaync-client", "-swb"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.notifCount = d.count || 0
                    root.dndEnabled = d.dnd || false
                } catch (e) {}
            }
        }
    }
    Timer { interval: 2000; running: root.visible; repeat: true; onTriggered: notifPoll.running = true }
    onVisibleChanged: if (visible) notifPoll.running = true

    // ── Power action runner ──
    Process { id: actionRunner; running: false }

    // ── Calendar month scroll ──
    property int _lastConsumedMonthDelta: 0
    Connections {
        target: PanelState
        function onCalendarMonthDeltaChanged() {
            const diff = PanelState.calendarMonthDelta - root._lastConsumedMonthDelta
            if (diff === 0) return
            root._lastConsumedMonthDelta = PanelState.calendarMonthDelta
            let m = root.viewMonth + diff
            let y = root.viewYear
            while (m < 0)  { m += 12; y -= 1 }
            while (m > 11) { m -= 12; y += 1 }
            root.viewMonth = m; root.viewYear = y
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const dir = event.angleDelta.y > 0 ? -1 : +1
            let m = root.viewMonth + dir, y = root.viewYear
            if (m < 0)  { m += 12; y -= 1 }
            if (m > 11) { m -= 12; y += 1 }
            root.viewMonth = m; root.viewYear = y
            event.accepted = true
        }
    }

    function buildDays() {
        const firstDay = new Date(viewYear, viewMonth, 1).getDay()
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const prevMonthDays = new Date(viewYear, viewMonth, 0).getDate()
        let cells = []
        for (let i = firstDay - 1; i >= 0; i--) cells.push({ day: prevMonthDays - i, current: false })
        for (let d = 1; d <= daysInMonth; d++) cells.push({ day: d, current: true })
        let nextDay = 1
        while (cells.length < 42) cells.push({ day: nextDay++, current: false })
        return cells
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ═══════════════════════════════════════════════
        // NOTIFICATIONS — top section
        // ═══════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 10
            color: ThemeService.alpha(ThemeService.bg1, 0.5)
            border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.06)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: root.dndEnabled ? "\udb82\udd13" : (root.notifCount > 0 ? "\udb83\udd6b" : "\udb80\udc9c")
                    font.family: Theme.monoFont; font.pixelSize: 18
                    color: root.notifCount > 0 ? ThemeService.yellow : ThemeService.grey0
                }
                Text {
                    text: "Notifications"
                    font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: ThemeService.fg
                }
                Item { Layout.fillWidth: true }

                // Badge count
                Rectangle {
                    visible: root.notifCount > 0
                    width: countText.implicitWidth + 14; height: 22; radius: 11
                    color: ThemeService.alpha(ThemeService.yellow, 0.2)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.yellow, 0.3)
                    Text {
                        id: countText; anchors.centerIn: parent
                        text: root.notifCount
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold
                        color: ThemeService.yellow
                    }
                }

                // DND toggle
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: dndMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.1) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: root.dndEnabled ? "\uf1f6" : "\uf0f3"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                        color: root.dndEnabled ? ThemeService.red : ThemeService.grey0
                    }
                    MouseArea {
                        id: dndMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached({command: ["swaync-client", "-d", "-sw"]})
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached({command: ["swaync-client", "-t", "-sw"]})
            }
        }

        // ═══════════════════════════════════════════════
        // CALENDAR — center section
        // ═══════════════════════════════════════════════

        // Header: ◀ Month Year ▶
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                color: prevMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "\uf104"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: ThemeService.grey0 }
                MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear-- } else root.viewMonth-- }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: monthNames[root.viewMonth] + " " + root.viewYear
                font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: ThemeService.fg
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                color: nextMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "\uf105"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: ThemeService.grey0 }
                MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear++ } else root.viewMonth++ }
                }
            }
        }

        // Day headers
        RowLayout {
            Layout.fillWidth: true; spacing: 0
            Repeater {
                model: root.dayHeaders
                Text { required property string modelData; Layout.fillWidth: true; text: modelData; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: ThemeService.grey1; horizontalAlignment: Text.AlignHCenter }
            }
        }

        // Day grid
        Grid {
            Layout.fillWidth: true; columns: 7; rows: 6; spacing: 2
            Repeater {
                model: root.buildDays()
                Rectangle {
                    required property var modelData
                    readonly property bool isToday: modelData.current && modelData.day === root.todayDay && root.viewMonth === root.todayMonth && root.viewYear === root.todayYear
                    width: (root.width - 28 - 12) / 7; height: 28; radius: 6
                    color: isToday ? ThemeService.alpha(ThemeService.blue, 0.3) : "transparent"
                    Text { anchors.centerIn: parent; text: modelData.day; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: isToday ? Font.Bold : Font.Normal; color: isToday ? ThemeService.fg : (modelData.current ? ThemeService.grey0 : ThemeService.grey2) }
                }
            }
        }

        // Today shortcut
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 24; radius: 6
            color: todayMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.05) : "transparent"
            visible: root.viewMonth !== root.todayMonth || root.viewYear !== root.todayYear
            Text { anchors.centerIn: parent; text: "↩ Today"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.blue }
            MouseArea { id: todayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.viewYear = root.todayYear; root.viewMonth = root.todayMonth } }
        }

        // ═══════════════════════════════════════════════
        // SEPARATOR
        // ═══════════════════════════════════════════════
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: ThemeService.alpha(ThemeService.fg, 0.08) }

        // ═══════════════════════════════════════════════
        // SYSTEM QUICK-ACTIONS — bottom section
        // ═══════════════════════════════════════════════
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 6

            // Row 1: Connectivity toggles
            Repeater {
                model: [
                    { icon: "\uf294", label: "BT",       action: "bt",       active: ConnectivityService.btPowered,   color: "blue" },
                    { icon: "\uf1eb", label: "WiFi",     action: "wifi",     active: ConnectivityService.wifiEnabled, color: "blue" },
                    { icon: "\uf023", label: "Lock",     action: "lock",     active: false, color: "yellow" },
                    { icon: "\uf2f5", label: "Logout",   action: "logout",   active: false, color: "orange" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 8
                    color: {
                        if (modelData.active) return ThemeService.alpha(ThemeService[modelData.color] || ThemeService.blue, 0.2)
                        return sysActionMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : ThemeService.alpha(ThemeService.bg1, 0.4)
                    }
                    border.width: 1
                    border.color: modelData.active ? ThemeService.alpha(ThemeService[modelData.color] || ThemeService.blue, 0.3) : ThemeService.alpha(ThemeService.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                            color: modelData.active ? (ThemeService[modelData.color] || ThemeService.blue) : ThemeService.grey0
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 9; font.weight: Font.DemiBold
                            color: modelData.active ? ThemeService.fg : ThemeService.grey1
                        }
                    }

                    MouseArea {
                        id: sysActionMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            switch (modelData.action) {
                                case "bt":    ConnectivityService.toggleBluetooth(); break
                                case "wifi":  ConnectivityService.toggleWifi(); break
                                case "lock":  root.powerActionRequested("lock", "hyprlock"); break
                                case "logout": root.powerActionRequested("logout", "hyprctl dispatch exit"); break
                            }
                        }
                    }
                }
            }

            // Row 2: Power actions
            Repeater {
                model: [
                    { icon: "\uf021", label: "Restart",  action: "reboot",   color: "blue" },
                    { icon: "\uf011", label: "Shutdown", action: "shutdown", color: "red" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.preferredHeight: 38
                    radius: 8
                    color: pwrMa.containsMouse
                           ? ThemeService.alpha(ThemeService[modelData.color] || ThemeService.red, 0.15)
                           : ThemeService.alpha(ThemeService.bg1, 0.4)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: ThemeService[modelData.color] || ThemeService.grey0 }
                        Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.fg }
                    }

                    MouseArea {
                        id: pwrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.action === "reboot") root.powerActionRequested("reboot", "systemctl reboot")
                            else root.powerActionRequested("shutdown", "systemctl poweroff")
                        }
                    }
                }
            }
        }
    }
}
