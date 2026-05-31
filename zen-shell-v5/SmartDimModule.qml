import QtQuick
import QtQuick.Controls
import Quickshell

/*
 * SmartDimModule v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Bar widget for Smart Dim. Shows a brightness icon, color-coded by
 * current active rule. Click → toggle SmartDimService.enabled.
 * Right-click → open SmartDim Settings page.
 *
 * Icon mapping (matches active rule):
 *   none         — standard brightness icon, muted
 *   video        — sun-half-stroke (dimmed)
 *   video_browser — sun-half-stroke (dimmed)
 *   ide          — sun + plus (boosted)
 *   reading      — book-open
 *   battery_critical — battery-quarter (red)
 *   gaming       — gamepad
 */
Item {
    id: sm

    implicitWidth: Theme.moduleHeight
    implicitHeight: Theme.moduleHeight

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: 2
        radius: 6
        color: ma.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.10)
               : "transparent"
        border.color: ma.containsMouse
                      ? ThemeService.alpha(ThemeService.fg, 0.15)
                      : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
        anchors.centerIn: parent
        text: {
            switch (SmartDimService.activeRuleName) {
                case "video":
                case "video_browser":     return "\uf186"   // moon
                case "ide":               return "\uf0eb"   // lightbulb
                case "reading":           return "\uf02d"   // book
                case "battery_critical":  return "\uf244"   // battery-empty
                case "gaming":            return "\uf11b"   // gamepad
                default:                  return "\uf185"   // sun (default)
            }
        }
        font.family: Theme.iconFontFamily
        font.pixelSize: 13
        color: {
            if (!SmartDimService.enabled) return ThemeService.alpha(ThemeService.fg, 0.4)
            switch (SmartDimService.activeRuleName) {
                case "battery_critical": return ThemeService.red || "#e06c75"
                case "ide": return ThemeService.green || "#98c379"
                case "video":
                case "video_browser": return ThemeService.blue
                case "gaming": return ThemeService.purple || "#c678dd"
                default: return ThemeService.fg
            }
        }
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                PanelState.openSettingsPage("smartdim")
            } else {
                SmartDimService.enabled = !SmartDimService.enabled
            }
        }
    }

    // Tooltip
    Rectangle {
        visible: ma.containsMouse
        z: 100
        radius: 4
        color: ThemeService.alpha(ThemeService.bg1, 0.95)
        border.color: ThemeService.alpha(ThemeService.fg, 0.2)
        border.width: 1
        width: ttText.implicitWidth + 12
        height: ttText.implicitHeight + 6
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4

        Text {
            id: ttText
            anchors.centerIn: parent
            text: SmartDimService.enabled
                  ? ("Smart Dim · " + SmartDimService.activeRuleName)
                  : "Smart Dim · off"
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: ThemeService.fg
        }
    }
}
