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
        onEntered: peekDelay.restart()
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
            PanelState.toggleCalendar()
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
        visible: clockRoot._peekPending && clockMouse.containsMouse
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
}
