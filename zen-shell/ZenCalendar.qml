import QtQuick
import QtQuick.Layouts

/*
 * ZenCalendar v6.13 — Popup calendar for bar clock
 *
 * Shows when clicking Clock in the bar. Positioned above the bar.
 * Current month grid with:
 *   - Today highlighted (ThemeService.blue)
 *   - ◀ / ▶ month navigation
 *   - Day-of-week headers (Su Mo Tu We Th Fr Sa)
 *   - Click outside or Esc to close
 *
 * Matches waybar clock tooltip calendar behavior.
 */
Rectangle {
    id: root

    signal closeRequested()

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()  // 0-indexed

    readonly property var today: new Date()
    readonly property int todayDay: today.getDate()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayYear: today.getFullYear()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayHeaders: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    width: 280
    height: calLayout.implicitHeight + 24
    // v6.16.2: theme-synced radius — follows the active theme's panel
    // rounding. Previously hardcoded 12 which didn't match square-style
    // themes or larger-radius themes.
    radius: Theme.panelRadius !== undefined ? Math.min(Theme.panelRadius, 16) : 12
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)

    Keys.onEscapePressed: closeRequested()

    // v6.16.2.3.1: React to month-delta nudges from Clock.qml scroll wheel.
    // We track the last consumed delta so we only apply the INCREMENTAL
    // change (ignoring stale deltas from before this calendar opened).
    property int _lastConsumedMonthDelta: 0
    Connections {
        target: PanelState
        function onCalendarMonthDeltaChanged() {
            const diff = PanelState.calendarMonthDelta - root._lastConsumedMonthDelta
            if (diff === 0) return
            root._lastConsumedMonthDelta = PanelState.calendarMonthDelta
            // Apply the delta. Negative = go back, positive = go forward.
            let m = root.viewMonth + diff
            let y = root.viewYear
            while (m < 0)  { m += 12; y -= 1 }
            while (m > 11) { m -= 12; y += 1 }
            root.viewMonth = m
            root.viewYear  = y
        }
    }

    // v6.16.2.3.1: Also accept scroll wheel directly on the calendar
    // itself (so the user can scroll-navigate even once it's open and
    // the cursor is on the calendar, not the clock).
    // WheelHandler (not MouseArea.onWheel) for Qt6/Wayland reliability.
    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const dir = event.angleDelta.y > 0 ? -1 : +1
            let m = root.viewMonth + dir
            let y = root.viewYear
            if (m < 0)  { m += 12; y -= 1 }
            if (m > 11) { m -= 12; y += 1 }
            root.viewMonth = m
            root.viewYear  = y
            event.accepted = true
        }
    }

    // Build the 6×7 grid of day numbers for the current view month
    function buildDays() {
        const firstDay = new Date(viewYear, viewMonth, 1).getDay()
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const prevMonthDays = new Date(viewYear, viewMonth, 0).getDate()

        let cells = []

        // Previous month trailing days
        for (let i = firstDay - 1; i >= 0; i--) {
            cells.push({ day: prevMonthDays - i, current: false })
        }

        // Current month
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push({ day: d, current: true })
        }

        // Next month leading days (fill to 42 = 6 rows)
        let nextDay = 1
        while (cells.length < 42) {
            cells.push({ day: nextDay++, current: false })
        }

        return cells
    }

    ColumnLayout {
        id: calLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── Header: ◀ Month Year ▶ ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            // Prev month
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 6
                color: prevMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "\uf104"  // ❮
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: ThemeService.grey0
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.viewMonth === 0) {
                            root.viewMonth = 11
                            root.viewYear--
                        } else {
                            root.viewMonth--
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: monthNames[root.viewMonth] + " " + root.viewYear
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: ThemeService.fg
            }

            Item { Layout.fillWidth: true }

            // Next month
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 6
                color: nextMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "\uf105"  // ❯
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: ThemeService.grey0
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.viewMonth === 11) {
                            root.viewMonth = 0
                            root.viewYear++
                        } else {
                            root.viewMonth++
                        }
                    }
                }
            }
        }

        // ── Day-of-week headers ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.dayHeaders

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: ThemeService.grey1
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ── Day grid (6 rows × 7 cols) ──
        Grid {
            Layout.fillWidth: true
            columns: 7
            rows: 6
            spacing: 2

            Repeater {
                model: root.buildDays()

                Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool isToday: modelData.current &&
                        modelData.day === root.todayDay &&
                        root.viewMonth === root.todayMonth &&
                        root.viewYear === root.todayYear

                    width: (root.width - 24 - 12) / 7   // parent width - margins - spacing
                    height: 28
                    radius: 6
                    color: isToday
                           ? ThemeService.alpha(ThemeService.blue, 0.3)
                           : "transparent"

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: modelData.day
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: isToday ? Font.Bold : Font.Normal
                        color: isToday
                               ? ThemeService.fg
                               : (modelData.current ? ThemeService.grey0 : ThemeService.grey2)
                    }
                }
            }
        }

        // ── Today shortcut ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            radius: 6
            color: todayMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.05) : "transparent"
            visible: root.viewMonth !== root.todayMonth || root.viewYear !== root.todayYear

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                text: "↩ Today"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: ThemeService.blue
            }

            MouseArea {
                id: todayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.viewYear = root.todayYear
                    root.viewMonth = root.todayMonth
                }
            }
        }
    }
}
