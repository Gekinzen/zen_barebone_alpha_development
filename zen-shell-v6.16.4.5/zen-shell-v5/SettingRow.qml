import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * SettingRow — Single row with label/description + control slot on right
 */
Rectangle {
    id: root

    property string label: ""
    property string description: ""
    default property alias control: controlSlot.data

    Layout.fillWidth: true
    implicitHeight: 48
    color: rowMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.03) : "transparent"
    radius: 6

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: ThemeService.fg
            }

            Text {
                text: root.description
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.grey1
                visible: root.description.length > 0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Item {
            id: controlSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
