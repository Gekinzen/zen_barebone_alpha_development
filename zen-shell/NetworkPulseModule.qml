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
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            // v8.0.0-alpha-hf184 — was a static sitemap glyph that never reflected the
            // actual link. Now: wifi signal-tier when on wifi, ethernet glyph when on
            // LAN, disconnected glyph otherwise — matching the SysRow network module.
            text: {
                if (ConnectivityService.wifiConnected) {
                    const sig = ConnectivityService.wifiSignal
                    if (sig >= 80) return "\udb83\udca8"   // 󰤨
                    if (sig >= 60) return "\udb83\udca5"   // 󰤥
                    if (sig >= 40) return "\udb83\udca2"   // 󰤢
                    if (sig >= 20) return "\udb83\udc9f"   // 󰤟
                    return "\udb83\udcaf"                  // 󰤯
                }
                if (ConnectivityService.lanConnected) return "\udb80\ude00"   // 󰈀 ethernet
                return "\udb83\udcae"   // 󰤮 disconnected
            }
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: PanelState.networkPulseVisible
                   ? ThemeService.blue
                   : ThemeService.fg
        }

        ColumnLayout {
            spacing: -2

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "↓ " + NetworkPulseService.fmtRate(NetworkPulseService.totalRxRate)
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: ThemeService.fg
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
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
        // hf195: middle-click opens the GTK Wi-Fi selector. Left still toggles
        // the pulse graph and right still opens its settings page — this module
        // is about throughput, so the selector is the third action here, not
        // the first.
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                PanelState.openSettingsPage("networkpulse")
            } else if (mouse.button === Qt.MiddleButton) {
                ConnectivityService.openWifiSelector()
            } else {
                PanelState.networkPulseVisible = !PanelState.networkPulseVisible
            }
        }
    }
}
