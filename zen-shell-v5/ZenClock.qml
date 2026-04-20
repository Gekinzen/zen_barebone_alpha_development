import QtQuick
import QtQuick.Layouts
import Quickshell.Io

/*
 * ZenClock v6.13 — bar clock module with calendar toggle
 *
 * v6.8: Auto-apply — changing format in Bar Modules page updates instantly.
 * v6.13: Click clock → toggles calendar overlay window via IPC.
 *        Calendar is hosted in shell.qml as a separate PanelWindow
 *        (Overlay layer) so it can render above the bar without clipping.
 *
 * Install as Clock.qml in ~/.config/quickshell/zen-shell/
 */
Item {
    id: clockRoot
    implicitWidth: clockText.implicitWidth + 20
    implicitHeight: parent ? parent.height : 40

    Timer { interval: 1000; repeat: true; running: true; onTriggered: clockRoot.now = new Date() }
    property var now: new Date()

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
        radius: 6
        color: clockMouse.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.06) : "transparent"
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Toggle calendar overlay via IPC
            calToggle.command = ["bash", "-c",
                "qs -c zen-shell ipc call zen toggleCalendar"]
            calToggle.running = true
        }
    }

    Process { id: calToggle; running: false }
}
