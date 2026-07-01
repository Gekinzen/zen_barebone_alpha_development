import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

/*
 * ControlCenterBanner — Prompt to open full GTK Hypr Control Center
 * for advanced features not in QML quick settings.
 */
Rectangle {
    id: root

    property string feature: "Advanced Settings"
    property string description: "Full options available in Hypr Control Center"

    Layout.fillWidth: true
    Layout.preferredHeight: 56
    radius: 10
    color: ThemeService.alpha(ThemeService.blue, 0.12)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.blue, 0.35)

    Process { id: ccLauncher; running: false }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Text {
            text: "\uf013"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            color: ThemeService.blue
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: root.feature
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: ThemeService.fg
            }
            Text {
                text: root.description
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.grey1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        ZenButton {
            text: "Open"
            accent: true
            iconText: "\uf08e"   // external-link glyph
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                ccLauncher.command = ["bash", "-c", "cd ~/.config/hypr-control-center && python3 main.py &"]
                ccLauncher.running = true
            }
        }
    }
}
