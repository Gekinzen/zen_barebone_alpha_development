import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * ZenClock v6.16.2 — bar clock module with calendar toggle + hover peek
 *
 * v6.8: Auto-apply — changing format in Bar Modules page updates instantly.
 * v6.13: Click clock → toggles calendar overlay window via IPC.
 *        Calendar is hosted in shell.qml as a separate PanelWindow
 *        (Overlay layer) so it can render above the bar without clipping.
 * v6.16.2: Hover peek — after 350ms hover, a small native popup shows
 *        the full weekday/date + week number. Click still opens the
 *        full calendar. Popup is ThemeService-synced (bg, fg, radius).
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

    // Hover highlight
    Rectangle {
        anchors.fill: parent
        radius: Theme.panelRadius !== undefined ? Math.max(6, Theme.panelRadius * 0.4) : 6
        color: clockMouse.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: peekDelay.restart()
        onExited: { peekDelay.stop(); clockRoot._peekPending = false }
        onClicked: {
            // Toggle calendar overlay via IPC
            clockRoot._peekPending = false
            calToggle.command = ["bash", "-c",
                "qs -c zen-shell ipc call zen toggleCalendar"]
            calToggle.running = true
        }
    }

    Process { id: calToggle; running: false }

    // ═══════════════════════════════════════════════════════════════
    // v6.16.2 HOVER PEEK POPUP — shows full date + week info after 350ms.
    // Uses PopupWindow (same pattern as SysRowIcon tooltip) so it renders
    // above the bar's layer surface. Theme-synced via ThemeService.
    //
    // v6.16.3.6: richer content (time with seconds, day-of-year, IANA
    // timezone) + consistent styling with ZenSysMonitor hover popup.
    // All bar-module hover popups now share the same visual language:
    // bg0 @ 96% alpha, 15% fg border, Theme.panelRadius (min 14),
    // 350ms hover-intent delay, Edges.Top anchor.
    // ═══════════════════════════════════════════════════════════════
    PopupWindow {
        id: peekPopup
        anchor.item: clockRoot
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        visible: clockRoot._peekPending && clockMouse.containsMouse
        width: Math.max(peekCol.implicitWidth + 28, 220)
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
                // Live time with seconds (updates every tick)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clockRoot.now, "h:mm:ss AP")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey0
                }
                // Subtle separator
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: peekCol.width * 0.5
                    height: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.1)
                }
                // Week + day-of-year + timezone (IANA, via JS Intl)
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
                        // Day of year
                        const startOfYear = new Date(clockRoot.now.getFullYear(), 0, 0)
                        const diff = clockRoot.now - startOfYear
                        const doy = Math.floor(diff / 86400000)
                        return "Week " + wk + "  ·  Day " + doy + " of " + clockRoot.now.getFullYear()
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.grey1
                }
                // IANA timezone
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        try {
                            const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
                            const offMin = -clockRoot.now.getTimezoneOffset()
                            const sign = offMin >= 0 ? "+" : "-"
                            const hh = Math.floor(Math.abs(offMin) / 60)
                            const mm = Math.abs(offMin) % 60
                            const off = "UTC" + sign + String(hh).padStart(2, "0") + ":" + String(mm).padStart(2, "0")
                            return (tz || "Local") + "  ·  " + off
                        } catch (e) {
                            return "Local time"
                        }
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.grey1
                }
                // Subtle separator
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: peekCol.width * 0.5
                    height: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.1)
                }
                // Click hint
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Click for calendar"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.grey0
                }
            }
        }
    }
}
