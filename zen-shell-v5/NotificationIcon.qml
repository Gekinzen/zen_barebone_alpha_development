import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: notifRoot
    width: Theme.moduleHeight
    height: Theme.moduleHeight
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
    color: Theme.alpha(Theme.bg0, 0.9)
    border.width: 1
    border.color: Theme.bg1

    // Matching your old format-icons:
    // notification: 󱅫, none: 󰂜, dnd-notification: 󰂠, dnd-none: 󰪓, etc
    property bool hasNotifications: false
    property bool dndEnabled: false

    property string notifIcon: {
        if (dndEnabled) {
            return hasNotifications ? "\udb80\udca0" : "\udb82\udd13"  // dnd-notification : dnd-none
        }
        return hasNotifications ? "\udb83\udd6b" : "\udb80\udc9c"  // notification : none
    }

    Process {
        id: poll
        command: ["swaync-client", "-swb"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    notifRoot.hasNotifications = (d.count || 0) > 0
                    notifRoot.dndEnabled = d.dnd || false
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: poll.running = true
    }

    Text {
        anchors.centerIn: parent
        text: notifRoot.notifIcon
        color: notifRoot.hasNotifications ? Theme.yellow : Theme.fg
        font.family: Theme.monoFont
        font.pixelSize: 18
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached({command: ["swaync-client", "-t", "-sw"]})
            else
                Quickshell.execDetached({command: ["swaync-client", "-d", "-sw"]})
        }
    }
}
