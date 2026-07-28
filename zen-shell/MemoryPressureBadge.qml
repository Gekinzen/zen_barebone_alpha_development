import QtQuick
import QtQuick.Controls
import Quickshell

/*
 * MemoryPressureBadge v7.0.0-alpha.7
 *
 * Compact bar indicator that appears in SysRow when free RAM drops
 * below ZenCleanupService.freeRamThreshold. Click runs the cleanup;
 * the icon also animates a slow pulse while pressure is sustained.
 *
 * When memory is fine (free > threshold), the badge is invisible
 * (height collapsed) so it doesn't take up bar space — only
 * appears when actually needed.
 *
 * Wala tayong babawasan — purely additive bar widget.
 */
Item {
    id: badge

    // Show only when memory is under pressure OR cleanup is running
    visible: ZenCleanupService.memoryPressure || ZenCleanupService.isRunning
    implicitWidth: visible ? Theme.moduleHeight : 0
    implicitHeight: Theme.moduleHeight

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: parent.width - 4
        height: parent.height - 4
        radius: 8
        color: ZenCleanupService.isRunning
               ? ThemeService.alpha(ThemeService.blue, 0.18)
               : ThemeService.alpha(ThemeService.red, 0.18)
        border.color: ZenCleanupService.isRunning
                      ? ThemeService.blue
                      : ThemeService.red
        border.width: 1
        Behavior on color { ColorAnimation { duration: 200 } }

        // Pulse animation when memory pressure (not while cleaning)
        SequentialAnimation on opacity {
            running: ZenCleanupService.memoryPressure && !ZenCleanupService.isRunning
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.6; duration: 800; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.6; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
        }

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            anchors.centerIn: parent
            text: MaterialIcons.icon(ZenCleanupService.isRunning ? "refresh" : "warning")
            font.family: MaterialIcons.fontFamily
            font.pixelSize: 14
            color: ZenCleanupService.isRunning ? ThemeService.blue : ThemeService.red

            // Refresh icon spins while running
            RotationAnimation on rotation {
                running: ZenCleanupService.isRunning
                from: 0; to: 360
                duration: 1200
                loops: Animation.Infinite
            }
        }
    }

    ToolTip.visible: ma.containsMouse
    ToolTip.delay: 500
    ToolTip.text: ZenCleanupService.isRunning
                  ? "Cleaning memory…"
                  : "Memory pressure: " + ZenCleanupService.freeMemPercent.toFixed(1) + "% free · click to clean"

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: ZenCleanupService.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: !ZenCleanupService.isRunning
        onClicked: ZenCleanupService.freeMemoryNow()
    }
}
