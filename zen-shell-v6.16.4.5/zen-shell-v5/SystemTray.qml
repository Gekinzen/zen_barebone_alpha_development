import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: trayRoot
    visible: SystemTray.items && SystemTray.items.values.length > 0
    implicitWidth: visible ? trayRow.implicitWidth + 20 : 0
    height: 40
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
    color: Theme.alpha(Theme.bg0, 0.9)
    border.width: 1
    border.color: Theme.bg1

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: SystemTray.items

            Rectangle {
                id: trayItem
                required property var modelData
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Theme.styleMode === "round" ? 12 : 6
                color: trayMa.containsMouse ? Theme.alpha(Theme.fg, 0.1) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: trayItem.modelData.icon
                    sourceSize: Qt.size(18, 18)
                    smooth: true
                }

                MouseArea {
                    id: trayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            trayItem.modelData.activate()
                        } else {
                            trayItem.modelData.display(trayRoot, trayItem.x, trayRoot.height)
                        }
                    }
                }
            }
        }
    }
}
