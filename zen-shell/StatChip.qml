import QtQuick
import QtQuick.Layouts

/*
 * StatChip — Compact stat display (icon + label + value)
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
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: ThemeService.grey0
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: ThemeService.grey1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: root.value
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.valueColor
            }
        }
    }
}
