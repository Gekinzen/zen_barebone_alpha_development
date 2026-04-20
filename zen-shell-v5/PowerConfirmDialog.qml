import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: dialogRoot
    radius: 20
    color: Theme.alpha(Theme.bg0, 0.97)
    border.width: 1
    border.color: Theme.alpha(Theme.fg, 0.15)

    property string action: ""      // "shutdown", "reboot", "logout", "lock"
    property string command: ""
    property int countdown: 60

    signal confirmed()
    signal cancelled()

    // Icon and color by action
    readonly property var actionInfo: {
        switch(action) {
            case "shutdown": return { icon: "\uf28d", title: "Shutdown", color: Theme.red, subtitle: "System will power off" }
            case "reboot":   return { icon: "\uf021", title: "Restart",  color: Theme.orange, subtitle: "System will reboot" }
            case "logout":   return { icon: "\uf0343", title: "Logout", color: Theme.yellow, subtitle: "Exit Hyprland session" }
            case "lock":     return { icon: "\uf023", title: "Lock",    color: Theme.blue, subtitle: "Lock the screen" }
        }
        return { icon: "\uf071", title: "Action", color: Theme.fg, subtitle: "" }
    }

    // ── Countdown timer ──
    Timer {
        id: countdownTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (dialogRoot.countdown > 0) {
                dialogRoot.countdown--
            } else {
                running = false
                dialogRoot.executeAction()
            }
        }
    }

    function executeAction() {
        countdownTimer.running = false
        if (command) {
            Quickshell.execDetached({command: ["bash", "-c", command]})
        }
        confirmed()
    }

    function cancel() {
        countdownTimer.running = false
        cancelled()
    }

    // Keyboard: Enter = confirm, Escape = cancel
    Keys.onEscapePressed: cancel()
    Keys.onReturnPressed: executeAction()
    Keys.onEnterPressed: executeAction()
    focus: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 20

        // ── Icon ──
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            radius: 48
            color: Theme.alpha(dialogRoot.actionInfo.color, 0.15)
            border.width: 2
            border.color: dialogRoot.actionInfo.color

            Text {
                anchors.centerIn: parent
                text: dialogRoot.actionInfo.icon
                color: dialogRoot.actionInfo.color
                font.family: Theme.monoFont
                font.pixelSize: 42
            }
        }

        // ── Title ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: dialogRoot.actionInfo.title
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.bold: true
        }

        // ── Subtitle ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: dialogRoot.actionInfo.subtitle
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        // ── Countdown ──
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 44
            radius: 22
            color: Theme.alpha(dialogRoot.actionInfo.color, 0.12)
            border.width: 1
            border.color: Theme.alpha(dialogRoot.actionInfo.color, 0.3)

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "\uf017"
                    color: dialogRoot.actionInfo.color
                    font.family: Theme.monoFont
                    font.pixelSize: 14
                }
                Text {
                    text: "Auto in " + dialogRoot.countdown + "s"
                    color: dialogRoot.actionInfo.color
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }

        // ── Progress bar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: Theme.alpha(Theme.fg, 0.1)
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (dialogRoot.countdown / 60)
                radius: 2
                color: dialogRoot.actionInfo.color
                Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 12 }

        // ── Buttons ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Cancel
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: cancelMa.containsMouse ? Theme.bg2 : Theme.bg1
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "\uf00d"
                        color: Theme.fgDim
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Cancel"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: "Esc"
                        color: Theme.fgDim
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialogRoot.cancel()
                }
            }

            // Confirm
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: confirmMa.containsMouse
                    ? dialogRoot.actionInfo.color
                    : Theme.alpha(dialogRoot.actionInfo.color, 0.75)
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "\uf00c"
                        color: Theme.bg0
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Confirm now"
                        color: Theme.bg0
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: "Enter"
                        color: Qt.rgba(0, 0, 0, 0.4)
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: confirmMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialogRoot.executeAction()
                }
            }
        }
    }
}
