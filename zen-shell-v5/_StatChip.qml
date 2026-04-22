import QtQuick
import QtQuick.Layouts

/*
 * _StatChip — Compact stat display (icon + label + value)
 * Used in ControlPanel for CPU/GPU/RAM readouts.
 */
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property color valueColor: ThemeService.fg

    implicitHeight: 36

    RowLayout {
        anchors.fill: parent
        spacing: 6

        Text {
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: ThemeService.grey0
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: ThemeService.grey1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.value
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.valueColor
            }
        }
    }
}
