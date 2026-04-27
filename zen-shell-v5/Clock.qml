import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * ZenClock v6.16.2.3.1 — bar clock module with calendar toggle + hover peek
 *
 * v6.8: Auto-apply — changing format in Bar Modules page updates instantly.
 * v6.13: Click clock → toggles calendar overlay window via IPC.
 *        Calendar is hosted in shell.qml as a separate PanelWindow
 *        (Overlay layer) so it can render above the bar without clipping.
 * v6.16.2: Hover peek — after 350ms hover, a small native popup shows
 *        the full weekday/date + week number. Click still opens the
 *        full calendar. Popup is ThemeService-synced (bg, fg, radius).
 * v6.16.2.3: Click uses PanelState singleton directly (no IPC).
 * v6.16.2.3.1: (1) Music rope no longer covers clock's input region
 *        (shell.qml mask fix) — hover events now actually arrive.
 *        (2) Popup anchored to Bottom edge of clockRoot with Top gravity
 *        so it opens ABOVE the clock (where empty space is when the bar
 *        is at the bottom). Previous Top/Top got clipped when the bar
 *        was at the screen bottom edge.
 *        (3) MouseArea now uses `onPositionChanged` as a fallback peek
 *        trigger in case `onEntered` misses (some Quickshell/Wayland
 *        timing has the first hover event fire as a position delta
 *        rather than a proper enter).
 *        (4) Scroll wheel over the clock cycles months in calendar
 *        (works when calendar is open — forwards to ZenCalendar).
 *
 * Install as Clock.qml in ~/.config/quickshell/zen-shell/
 */
Item {
    id: clockRoot
    implicitWidth: clockText.implicitWidth + 20
    implicitHeight: parent ? parent.height : 40

    Timer { interval: 1000; repeat: true; running: true; onTriggered: clockRoot.now = new Date() }
    property var now: new Date()

    // v6.16.2 — delay before hover peek appears (hover intent heuristic)
    property bool _peekPending: false
    Timer {
        id: peekDelay
        interval: 350
        repeat: false
        onTriggered: clockRoot._peekPending = clockMouse.containsMouse
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: {
            const idx = Math.max(0, Math.min(ZenConstants.clockFormats.length - 1, PanelState.clockFormatIndex))
            return ZenConstants.formatClock(clockRoot.now, ZenConstants.clockFormats[idx].format, true)
        }
        font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        color: ThemeService.fg
        lineHeight: 1.15
    }

    // v6.16.4: Hover highlight MORE VISIBLE.
    // Previous 0.06 alpha was too subtle — Paul couldn't tell if hover
    // registered. Now 0.12 + border tint so it's unmistakable.
    Rectangle {
        anchors.fill: parent
        radius: Theme.panelRadius !== undefined ? Math.max(6, Theme.panelRadius * 0.4) : 6
        color: clockMouse.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent"
        border.width: clockMouse.containsMouse ? 1 : 0
        border.color: ThemeService.alpha(ThemeService.blue, 0.4)
        Behavior on color       { ColorAnimation  { duration: 120 } }
        Behavior on border.width { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        // v6.16.2.2: Explicit z ensures mouse events reach here even with
        // overlapping sibling Rectangles. QML's default draw-order =
        // event-order already handles this, but explicit z prevents
        // surprises from future sibling additions.
        z: 10
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: { peekDelay.restart(); console.log("[Clock] onEntered, containsMouse=", containsMouse) }
        // v6.16.2.3.1: Fallback peek trigger. Some Wayland/Quickshell
        // paths deliver the initial hover as a position delta rather
        // than an enter event (happens when another surface just
        // relinquished input — e.g. strings window mask change).
        onPositionChanged: if (!peekDelay.running && !clockRoot._peekPending) peekDelay.restart()
        onExited: { peekDelay.stop(); clockRoot._peekPending = false }
        onClicked: (mouse) => {
            clockRoot._peekPending = false
            if (mouse.button === Qt.RightButton) {
                // Right-click: cycle clock format (nice-to-have, cheap).
                const n = ZenConstants.clockFormats.length
                PanelState.clockFormatIndex = (PanelState.clockFormatIndex + 1) % n
                PanelState.saveState()
                return
            }
            // v6.16.4.12.2: Calendar popup is hover-driven (same pattern as
            // SysRow CPU/memory tooltip). Left-click does nothing — the
            // popup already opens automatically on hover.
        }
    }

    // v6.16.2.3.1: Scroll wheel over the clock cycles calendar months.
    // Using WheelHandler (Qt 6 PointerHandler) rather than MouseArea.onWheel
    // because the latter has spotty delivery under Wayland when the
    // surface has recently gained input focus (which is exactly what
    // happens when the music-strings mask opens up the clock area).
    // WheelHandler sits alongside MouseArea and both receive events.
    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (!PanelState.calendarVisible) {
                PanelState.openCalendar()
            }
            const dir = event.angleDelta.y > 0 ? -1 : +1   // wheel up → previous month
            PanelState.calendarMonthDelta += dir
            event.accepted = true
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // v6.16.2 HOVER PEEK POPUP — shows full date + week info after 350ms.
    // Uses PopupWindow (same pattern as SysRowIcon tooltip) so it renders
    // above the bar's layer surface. Theme-synced via ThemeService.
    // ═══════════════════════════════════════════════════════════════
    PopupWindow {
        id: peekPopup
        anchor.item: clockRoot
        // v6.16.2.3.1: Anchor to clock's TOP edge with gravity pointing UP.
        // Previous (Edges.Top + gravity Top) placed popup at the TOP of
        // the clock WITH ITS OWN TOP at that line — pushing the popup
        // upward so it extended off the screen when bar sat at screen
        // bottom (popup ends up above the monitor edge = Wayland clips
        // it invisible). Edges.Top + gravity.Top means:
        //   anchor point = clock's top edge
        //   popup expands upward from that point
        // Which on a bottom-anchored bar places the popup ABOVE the
        // clock with its BOTTOM edge aligned to the clock's top. Correct.
        //
        // The bug wasn't this — the actual bug was that the music-strings
        // overlay was covering the clock's input region, so hover events
        // never fired (see shell.qml stringsWindow mask fix). This anchor
        // was always geometrically correct; it just never had a chance
        // to show because _peekPending never became true.
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        // v6.16.4.12.2: Disabled — replaced by full calendar popup which
        // also opens on hover. The old single-line "Today is X" peek is
        // redundant when the full calendar shows the same info.
        visible: false
        // visible: clockRoot._peekPending && clockMouse.containsMouse
        width: Math.max(peekCol.implicitWidth + 28, 180)
        height: peekCol.implicitHeight + 20
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.panelRadius !== undefined ? Math.min(Theme.panelRadius, 14) : 10
            color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)

            Column {
                id: peekCol
                anchors.centerIn: parent
                spacing: 4

                // Weekday name (large)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clockRoot.now, "dddd")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.blue
                }
                // Full date
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clockRoot.now, "MMMM d, yyyy")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.fg
                }
                // Subtle separator
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: peekCol.width * 0.5
                    height: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.1)
                }
                // Week number + click hint
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        // ISO 8601 week number
                        const d = new Date(Date.UTC(clockRoot.now.getFullYear(),
                                                   clockRoot.now.getMonth(),
                                                   clockRoot.now.getDate()))
                        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7))
                        const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1))
                        const wk = Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
                        return "Week " + wk + "  ·  Click for calendar"
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.grey0
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // v6.16.4.12 Hikari: HOVER POPUP — calendar + notifs + system
    //
    // Same pattern as SysRowIcon tooltip + Taskbar PopupWindow:
    //   - anchor.item = clockRoot (auto-positions on Wayland)
    //   - anchor.edges = Edges.Top (popup floats above clock)
    //   - visible bound to hover state (no click required)
    // ═══════════════════════════════════════════════════════════════
    PopupWindow {
        id: calPopup
        anchor.item: clockRoot
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top

        // v6.16.4.12.4: Use width/height (matches SysRowIcon pattern that
        // actually works on Wayland). implicitWidth alone doesn't trigger
        // proper popup sizing in current Quickshell, even though it warns
        // that width is deprecated. The deprecation is forward-looking;
        // implicitWidth currently isn't honored for PopupWindow sizing.
        width: 330
        height: 590
        color: "transparent"

        // v6.16.4.12.3: Pure hover-driven, same exact pattern as SysRowIcon.
        // Tooltip approach — popup stays visible only while clock is hovered.
        // User can interact with popup interior by hovering it (clockMouse
        // does NOT lose containsMouse just because cursor moves up over popup).
        visible: clockMouse.containsMouse

        property int viewYear: new Date().getFullYear()
        property int viewMonth: new Date().getMonth()
        readonly property var today: new Date()
        property int notifCount: 0
        property bool dndEnabled: false

        readonly property var monthFull: [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]
        readonly property var dayHeaders: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

        onVisibleChanged: {
            console.log("[CalPopup] visible=", visible, "clockHover=", clockMouse.containsMouse)
            if (visible) {
                viewYear = new Date().getFullYear()
                viewMonth = new Date().getMonth()
                notifPoll.running = true
            }
        }

        Process {
            id: notifPoll
            command: ["swaync-client", "-swb"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(this.text)
                        calPopup.notifCount = d.count || 0
                        calPopup.dndEnabled = d.dnd || false
                    } catch (e) {}
                }
            }
        }
        Timer { interval: 2000; running: calPopup.visible; repeat: true; onTriggered: notifPoll.running = true }
        Process { id: powerRunner; running: false }

        function buildDays() {
            const firstDay = new Date(calPopup.viewYear, calPopup.viewMonth, 1).getDay()
            const daysInMonth = new Date(calPopup.viewYear, calPopup.viewMonth + 1, 0).getDate()
            const prevMonthDays = new Date(calPopup.viewYear, calPopup.viewMonth, 0).getDate()
            let cells = []
            for (let i = firstDay - 1; i >= 0; i--) cells.push({ day: prevMonthDays - i, current: false })
            for (let d = 1; d <= daysInMonth; d++) cells.push({ day: d, current: true })
            let nextDay = 1
            while (cells.length < 42) cells.push({ day: nextDay++, current: false })
            return cells
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.97)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.12)

            // Click outside popup → close
            MouseArea {
                anchors.fill: parent
                z: -1
                propagateComposedEvents: true
                onClicked: { /* swallow */ }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // ─── CLOCK FORMAT SELECTOR (compact pills) ───
                // v6.16.4.12.1: Click any pill to switch format.
                // Right-click clock module also cycles formats (existing).
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 4
                    Text {
                        text: "Format:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.alpha(Theme.fg, 0.5)
                        Layout.rightMargin: 4
                    }
                    Repeater {
                        model: ZenConstants.clockFormats
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === PanelState.clockFormatIndex

                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 6
                            color: selected
                                   ? Theme.alpha(Theme.blue, 0.25)
                                   : (fmtMa.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent")
                            border.width: selected ? 1 : 0
                            border.color: Theme.alpha(Theme.blue, 0.4)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: ZenConstants.formatClock(clockRoot.now, modelData.format, true)
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? Theme.fg : Theme.alpha(Theme.fg, 0.6)
                            }
                            MouseArea {
                                id: fmtMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    PanelState.clockFormatIndex = index
                                    PanelState.saveState()
                                }
                            }
                        }
                    }
                }

                // Subtle separator between format and notifications
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.alpha(Theme.fg, 0.06)
                }

                // ─── NOTIFICATIONS ROW (flat, no nested bg) ───
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 8
                    // v6.16.4.12.1: Transparent default — only show bg on hover
                    // so popup feels like one flat surface, not boxes inside boxes.
                    color: notifMa.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: calPopup.dndEnabled ? "\uf1f6" : (calPopup.notifCount > 0 ? "\uf0f3" : "\uf0a2")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: calPopup.notifCount > 0 ? Theme.yellow : Theme.grey0
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
                            visible: calPopup.notifCount > 0
                            width: countText.implicitWidth + 14; height: 22; radius: 11
                            color: Theme.alpha(Theme.yellow, 0.2)
                            border.width: 1; border.color: Theme.alpha(Theme.yellow, 0.3)
                            Text {
                                id: countText; anchors.centerIn: parent
                                text: calPopup.notifCount
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
                        onClicked: {
                            calPopup.visible = false
                            Quickshell.execDetached({command: ["swaync-client", "-t", "-sw"]})
                        }
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
                                if (calPopup.viewMonth === 0) { calPopup.viewMonth = 11; calPopup.viewYear-- }
                                else calPopup.viewMonth--
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: calPopup.monthFull[calPopup.viewMonth] + " " + calPopup.viewYear
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
                                if (calPopup.viewMonth === 11) { calPopup.viewMonth = 0; calPopup.viewYear++ }
                                else calPopup.viewMonth++
                            }
                        }
                    }
                }

                // ─── DAY HEADERS ───
                RowLayout {
                    Layout.fillWidth: true; spacing: 0
                    Repeater {
                        model: calPopup.dayHeaders
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
                        model: calPopup.buildDays()
                        Rectangle {
                            required property var modelData
                            readonly property bool isToday:
                                modelData.current
                                && modelData.day === calPopup.today.getDate()
                                && calPopup.viewMonth === calPopup.today.getMonth()
                                && calPopup.viewYear === calPopup.today.getFullYear()
                            width: (calPopup.implicitWidth - 28 - 12) / 7
                            height: 28
                            radius: 6
                            color: isToday ? Theme.alpha(Theme.blue, 0.3) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: isToday ? Font.Bold : Font.Normal
                                color: isToday ? Theme.fg : (modelData.current ? Theme.grey0 : Theme.grey2)
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
                            // v6.16.4.12.1: Transparent default. Only shows on hover.
                            color: btnMa.containsMouse
                                   ? Theme.alpha(Theme.blue, 0.15)
                                   : "transparent"
                            border.width: 0
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
                                            calPopup.visible = false
                                            powerRunner.command = ["hyprlock"]
                                            powerRunner.running = true
                                            break
                                        case "logout":
                                            calPopup.visible = false
                                            powerRunner.command = ["hyprctl", "dispatch", "exit"]
                                            powerRunner.running = true
                                            break
                                    }
                                }
                            }
                        }
                    }

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
                            // v6.16.4.12.1: Transparent default. Tinted on hover.
                            color: pwrMa.containsMouse
                                   ? Theme.alpha(modelData.color, 0.2)
                                   : "transparent"
                            border.width: 0
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
                                    calPopup.visible = false
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
