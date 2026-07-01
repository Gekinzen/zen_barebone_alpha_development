import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * NetworkPulsePage v7.0.0-beta.1-hf39 — Settings page for Network Pulse.
 */
Item {
    id: root

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: contentCol.implicitHeight
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 24
            spacing: 16

            DenshoPageHeader {
                Layout.fillWidth: true
                title: "Network Pulse"
                subtitle: "Live per-app bandwidth monitoring"
                kanji: "通信"
                romaji: "Tsūshin"
            }

            HMSection {
                title: "Monitoring"

                HMRow {
                    label: "Enable network pulse"
                    description: "Poll interface stats + active connections."
                    icon: "\uf0e8"
                    separator: true

                    HMSwitch {
                        checked: NetworkPulseService.enabled
                        onToggled: NetworkPulseService.enabled = checked
                    }
                }

                HMRow {
                    label: "Active poll interval"
                    description: "How often to re-read /proc/net/dev and active sockets "
                               + "when the popover is open. " + NetworkPulseService.pollIntervalMs + "ms"
                    icon: "\uf017"
                    separator: true

                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: [1000, 2000, 5000]
                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 26
                                radius: 5
                                color: NetworkPulseService.pollIntervalMs === modelData
                                       ? ThemeService.alpha(ThemeService.blue, 0.4)
                                       : ThemeService.alpha(ThemeService.fg, 0.1)
                                border.color: ThemeService.alpha(ThemeService.fg, 0.25)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData / 1000) + "s"
                                    color: ThemeService.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NetworkPulseService.pollIntervalMs = modelData
                                }
                            }
                        }
                    }
                }

                HMRow {
                    label: "Tools detected"
                    description: "ss = active connection listing. nethogs = per-app bandwidth "
                               + "(requires SUID or CAP_NET_ADMIN)."
                    icon: "\uf0c8"

                    RowLayout {
                        spacing: 8

                        Row {
                            spacing: 4
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: NetworkPulseService.ssAvailable
                                       ? ThemeService.green || "#98c379"
                                       : ThemeService.red || "#e06c75"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "ss"
                                color: ThemeService.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        Row {
                            spacing: 4
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: NetworkPulseService.nethogsAvailable
                                       ? ThemeService.green || "#98c379"
                                       : ThemeService.alpha(ThemeService.fg, 0.3)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "nethogs"
                                color: ThemeService.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            HMSection {
                title: "Blocked Apps (" + NetworkPulseService.blockedComms.length + ")"
                subtitle: "Apps you've marked as 'blocked' for awareness. Actual sandboxing "
                        + "requires manual firejail wrap. Click to unblock."
                visible: NetworkPulseService.blockedComms.length > 0

                Repeater {
                    model: NetworkPulseService.blockedComms

                    HMRow {
                        label: modelData
                        description: "Click 'Unblock' to remove from the block list."
                        icon: "\uf05e"
                        separator: index < NetworkPulseService.blockedComms.length - 1

                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 24
                            radius: 5
                            color: ThemeService.alpha(ThemeService.fg, 0.10)
                            border.color: ThemeService.alpha(ThemeService.fg, 0.3)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "Unblock"
                                color: ThemeService.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkPulseService.toggleBlock(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
