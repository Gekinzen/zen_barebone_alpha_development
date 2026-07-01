import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/*
 * NetworkPulseModule v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Bar widget for Network Pulse. Shows live total ↓ / ↑ bandwidth.
 * Click → toggle NetworkPulsePanel popover with per-app breakdown.
 *
 * Switches NetworkPulseService.active true when hovered/clicked so
 * polling speeds up (2s) for accurate readings; reverts to 10s when
 * popover closes.
 */
Item {
    id: nm

    implicitWidth: Math.max(Theme.moduleHeight, content.implicitWidth + 14)
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

    // While hovered or panel visible, set active=true for fast polls
    onChildrenChanged: NetworkPulseService.active = ma.containsMouse || PanelState.networkPulseVisible
    Connections {
        target: ma
        function onContainsMouseChanged() {
            NetworkPulseService.active = ma.containsMouse || PanelState.networkPulseVisible
        }
    }
    Connections {
        target: PanelState
        function onNetworkPulseVisibleChanged() {
            NetworkPulseService.active = ma.containsMouse || PanelState.networkPulseVisible
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "\uf0e8"   // sitemap / network icon
            font.family: Theme.iconFontFamily
            font.pixelSize: 12
            color: PanelState.networkPulseVisible
                   ? ThemeService.blue
                   : ThemeService.fg
        }

        ColumnLayout {
            spacing: -2

            Text {
                text: "↓ " + NetworkPulseService.fmtRate(NetworkPulseService.totalRxRate)
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: ThemeService.fg
            }
            Text {
                text: "↑ " + NetworkPulseService.fmtRate(NetworkPulseService.totalTxRate)
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: ThemeService.alpha(ThemeService.fg, 0.75)
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                PanelState.openSettingsPage("networkpulse")
            } else {
                PanelState.networkPulseVisible = !PanelState.networkPulseVisible
            }
        }
    }
}
