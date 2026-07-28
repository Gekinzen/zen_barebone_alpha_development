import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ConnToggleRow — Connectivity toggle row for ControlPanel
 *
 * Shows: [icon] Label / sublabel     [gear] [switch]
 *
 * Internal component — prefix underscore = not for direct external use.
 */
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property color iconColor: ThemeService.fg

    signal toggled()
    signal settingsClicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 40

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // Icon badge
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 8
            color: ThemeService.alpha(root.iconColor, 0.12)

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                text: root.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: root.iconColor
            }
        }

        // Label + sublabel
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: ThemeService.fg
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: root.sublabel
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.grey1
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: root.sublabel.length > 0
            }
        }

        // Settings gear
        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: 6
            color: gearMouse.containsMouse
                   ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                text: "\uf013"  // gear
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: ThemeService.grey1
            }

            MouseArea {
                id: gearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsClicked()
            }
        }

        // Toggle switch
        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 22
            radius: 11
            color: root.active
                   ? ThemeService.alpha(ThemeService.green, 0.85)
                   : ThemeService.alpha(ThemeService.fg, 0.15)

            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: ThemeService.fg
                y: 2
                x: root.active ? parent.width - width - 2 : 2

                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }
    }
}
