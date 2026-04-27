import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * CalendarButton v6.16.4.12 — Hikari 光
 *
 * Self-contained bar module. Click → opens PopupWindow with
 * calendar + notifications + system icons. No external wiring.
 *
 * To use: add "calendar" to your barLayout via Settings → Panel.
 */
Rectangle {
    id: root

    width: dateText.implicitWidth + 24
    height: Theme.moduleHeight
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
    color: ma.containsMouse ? Theme.alpha(Theme.blue, 0.25) : Theme.alpha(Theme.bg0, 0.9)
    border.width: 1
    border.color: ma.containsMouse ? Theme.blue : Theme.bg1

    Behavior on color { ColorAnimation { duration: 150 } }

    // ── Live date ──
    property var now: new Date()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = new Date() }

    readonly property var monthShort: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
    readonly property var monthFull: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayHeaders: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        Text {
            text: "\uf073"  // calendar icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: ma.containsMouse ? Theme.blue : Theme.fg
        }
        Text {
            id: dateText
            text: monthShort[root.now.getMonth()] + " " + root.now.getDate()
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.fg
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            console.log("[CalendarButton] click — popup.visible was:", popup.visible)
            popup.visible = !popup.visible
        }
    }

    // ═══════════════════════════════════════════════════════════
    // POPUP — calendar + notifications + system icons
    // PopupWindow is a Quickshell primitive that positions itself
    // relative to its anchor item (this rectangle).
    // ═══════════════════════════════════════════════════════════
    PopupWindow {
        id: popup

        anchor.window: QsWindow.window
        anchor.rect.x: root.x + (root.width / 2) - 165
        anchor.rect.y: root.y - 540
        anchor.rect.width: 0
        anchor.rect.height: 0

        implicitWidth: 330
        implicitHeight: 540
        color: "transparent"
        visible: false

        // ── Calendar state ──
        property int viewYear: new Date().getFullYear()
        property int viewMonth: new Date().getMonth()
        readonly property var today: new Date()

        onVisibleChanged: {
            if (visible) {
                viewYear = new Date().getFullYear()
                viewMonth = new Date().getMonth()
                if (typeof notifPoll !== "undefined") notifPoll.running = true
            }
        }

        // ── Notification state ──
        property int notifCount: 0
        property bool dndEnabled: false

        Process {
            id: notifPoll
            command: ["swaync-client", "-swb"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(this.text)
                        popup.notifCount = d.count || 0
                        popup.dndEnabled = d.dnd || false
                    } catch (e) {}
                }
            }
        }
        Timer { interval: 2000; running: popup.visible; repeat: true; onTriggered: notifPoll.running = true }

        // ── Build calendar grid ──
        function buildDays() {
            const firstDay = new Date(popup.viewYear, popup.viewMonth, 1).getDay()
            const daysInMonth = new Date(popup.viewYear, popup.viewMonth + 1, 0).getDate()
            const prevMonthDays = new Date(popup.viewYear, popup.viewMonth, 0).getDate()
            let cells = []
            for (let i = firstDay - 1; i >= 0; i--) cells.push({ day: prevMonthDays - i, current: false })
            for (let d = 1; d <= daysInMonth; d++) cells.push({ day: d, current: true })
            let nextDay = 1
            while (cells.length < 42) cells.push({ day: nextDay++, current: false })
            return cells
        }

        // ── Power action runner ──
        Process { id: powerRunner; running: false }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.97)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.12)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // ─── NOTIFICATIONS ROW ───
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 10
                    color: notifMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : Theme.alpha(Theme.bg1, 0.5)
                    border.width: 1; border.color: Theme.alpha(Theme.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: popup.dndEnabled ? "\uf1f6" : (popup.notifCount > 0 ? "\uf0f3" : "\uf0a2")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: popup.notifCount > 0 ? Theme.yellow : Theme.grey0
                        }
                        Text {
                            text: "Notifications"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.fg
                        }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: popup.notifCount > 0
                            width: countText.implicitWidth + 14; height: 22; radius: 11
                            color: Theme.alpha(Theme.yellow, 0.2)
                            border.width: 1; border.color: Theme.alpha(Theme.yellow, 0.3)
                            Text {
                                id: countText; anchors.centerIn: parent
                                text: popup.notifCount
                                font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold
                                color: Theme.yellow
                            }
                        }
                    }

                    MouseArea {
                        id: notifMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached({command: ["swaync-client", "-t", "-sw"]})
                    }
                }

                // ─── CALENDAR HEADER ───
                RowLayout {
                    Layout.fillWidth: true; spacing: 0

                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                        color: prevMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf104"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.grey0 }
                        MouseArea {
                            id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popup.viewMonth === 0) { popup.viewMonth = 11; popup.viewYear-- }
                                else popup.viewMonth--
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.monthFull[popup.viewMonth] + " " + popup.viewYear
                        font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.fg
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                        color: nextMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf105"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.grey0 }
                        MouseArea {
                            id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popup.viewMonth === 11) { popup.viewMonth = 0; popup.viewYear++ }
                                else popup.viewMonth++
                            }
                        }
                    }
                }

                // ─── DAY HEADERS ───
                RowLayout {
                    Layout.fillWidth: true; spacing: 0
                    Repeater {
                        model: root.dayHeaders
                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.grey1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // ─── DAY GRID ───
                Grid {
                    Layout.fillWidth: true
                    columns: 7; rows: 6; spacing: 2
                    Repeater {
                        model: popup.buildDays()
                        Rectangle {
                            required property var modelData
                            readonly property bool isToday:
                                modelData.current
                                && modelData.day === popup.today.getDate()
                                && popup.viewMonth === popup.today.getMonth()
                                && popup.viewYear === popup.today.getFullYear()
                            width: (popup.implicitWidth - 28 - 12) / 7
                            height: 28
                            radius: 6
                            color: isToday ? Theme.alpha(Theme.blue, 0.3) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: isToday ? Font.Bold : Font.Normal
                                color: isToday
                                       ? Theme.fg
                                       : (modelData.current ? Theme.grey0 : Theme.grey2)
                            }
                        }
                    }
                }

                // ─── SEPARATOR ───
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    color: Theme.alpha(Theme.fg, 0.08)
                }

                // ─── SYSTEM QUICK-ACTIONS ───
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 6

                    // Row 1: BT / WiFi / Lock / Logout
                    Repeater {
                        model: [
                            { icon: "\uf293", label: "BT",     action: "bt" },
                            { icon: "\uf1eb", label: "WiFi",   action: "wifi" },
                            { icon: "\uf023", label: "Lock",   action: "lock" },
                            { icon: "\uf2f5", label: "Logout", action: "logout" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 8
                            color: btnMa.containsMouse
                                   ? Theme.alpha(Theme.blue, 0.18)
                                   : Theme.alpha(Theme.bg1, 0.4)
                            border.width: 1
                            border.color: Theme.alpha(Theme.fg, 0.06)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 2
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: Theme.fg
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: Theme.grey0
                                }
                            }

                            MouseArea {
                                id: btnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    switch (modelData.action) {
                                        case "bt":
                                            powerRunner.command = ["bash", "-c", "bluetoothctl power on || bluetoothctl power off"]
                                            powerRunner.running = true
                                            break
                                        case "wifi":
                                            powerRunner.command = ["bash", "-c", "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on"]
                                            powerRunner.running = true
                                            break
                                        case "lock":
                                            popup.visible = false
                                            powerRunner.command = ["hyprlock"]
                                            powerRunner.running = true
                                            break
                                        case "logout":
                                            popup.visible = false
                                            powerRunner.command = ["hyprctl", "dispatch", "exit"]
                                            powerRunner.running = true
                                            break
                                    }
                                }
                            }
                        }
                    }

                    // Row 2: Restart / Shutdown
                    Repeater {
                        model: [
                            { icon: "\uf021", label: "Restart",  cmd: "systemctl reboot",   color: Theme.blue },
                            { icon: "\uf011", label: "Shutdown", cmd: "systemctl poweroff", color: Theme.red }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.columnSpan: 2
                            Layout.preferredHeight: 38
                            radius: 8
                            color: pwrMa.containsMouse
                                   ? Theme.alpha(modelData.color, 0.2)
                                   : Theme.alpha(Theme.bg1, 0.4)
                            border.width: 1
                            border.color: Theme.alpha(Theme.fg, 0.06)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent; spacing: 6
                                Text {
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: modelData.color
                                }
                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.fg
                                }
                            }

                            MouseArea {
                                id: pwrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    popup.visible = false
                                    powerRunner.command = ["bash", "-c", modelData.cmd]
                                    powerRunner.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
