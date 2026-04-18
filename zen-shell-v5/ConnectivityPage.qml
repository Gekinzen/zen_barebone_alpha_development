import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ConnectivityPage v6.13 — Settings → Connectivity
 *
 * Unified page for Sound, Wi-Fi, Bluetooth, and LAN settings.
 * Full-featured version of what ControlPanel shows in compact form.
 *
 * Sections:
 *   1. Audio Output — sink selection hint, volume, mute
 *   2. Audio Input — source/mic volume, mute
 *   3. Wi-Fi — toggle, connected network, signal, open nm-connection-editor
 *   4. Bluetooth — toggle, paired devices, open blueman
 *   5. Ethernet — status, interface, IP
 */
Item {
    id: root

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            // ── Page header ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                Layout.leftMargin: 24
                Layout.topMargin: 24

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    Text {
                        text: "Connectivity"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: ThemeService.fg
                    }

                    Text {
                        text: "Sound, Wi-Fi, Bluetooth & Network"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: ThemeService.grey1
                    }
                }
            }

            // Content with padding
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24
                spacing: 16

                // ═══════════════════════════════════════
                // AUDIO OUTPUT
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Audio Output"
                    subtitle: "PipeWire / WirePlumber"

                    SettingRow {
                        label: "Output Device"
                        description: ConnectivityService.audioSinkName

                        Rectangle {
                            width: 80
                            height: 28
                            radius: 6
                            color: pavuMouse.containsMouse
                                   ? ThemeService.alpha(ThemeService.blue, 0.15)
                                   : ThemeService.alpha(ThemeService.blue, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "pavucontrol"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: ThemeService.blue
                            }

                            MouseArea {
                                id: pavuMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConnectivityService.openAudioSettings()
                            }
                        }
                    }

                    SettingRow {
                        label: "Volume"
                        description: ConnectivityService.audioMuted ? "Muted" : (ConnectivityService.audioVolume + "%")

                        RowLayout {
                            spacing: 8

                            Slider {
                                id: settingsVolSlider
                                implicitWidth: 180
                                from: 0
                                to: 150
                                stepSize: 1
                                value: ConnectivityService.audioVolume
                                onMoved: ConnectivityService.setVolume(value)

                                background: Rectangle {
                                    x: settingsVolSlider.leftPadding
                                    y: settingsVolSlider.topPadding + settingsVolSlider.availableHeight / 2 - height / 2
                                    width: settingsVolSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: ThemeService.alpha(ThemeService.fg, 0.12)

                                    Rectangle {
                                        width: settingsVolSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: ConnectivityService.audioMuted
                                               ? ThemeService.grey2
                                               : (ConnectivityService.audioVolume > 100
                                                  ? ThemeService.orange : ThemeService.blue)
                                    }
                                }

                                handle: Rectangle {
                                    x: settingsVolSlider.leftPadding + settingsVolSlider.visualPosition * (settingsVolSlider.availableWidth - width)
                                    y: settingsVolSlider.topPadding + settingsVolSlider.availableHeight / 2 - height / 2
                                    width: 14; height: 14; radius: 7
                                    color: ThemeService.fg
                                    border.width: 2
                                    border.color: ThemeService.alpha(ThemeService.bg0, 0.5)
                                }
                            }

                            // Mute toggle
                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: muteMouse.containsMouse
                                       ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: ConnectivityService.audioIcon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    color: ConnectivityService.audioMuted ? ThemeService.red : ThemeService.blue
                                }

                                MouseArea {
                                    id: muteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.toggleMute()
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // AUDIO INPUT (Microphone)
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Audio Input"
                    subtitle: ConnectivityService.micSourceName

                    SettingRow {
                        label: "Microphone Volume"
                        description: ConnectivityService.micMuted ? "Muted" : (ConnectivityService.micVolume + "%")

                        RowLayout {
                            spacing: 8

                            Slider {
                                id: settingsMicSlider
                                implicitWidth: 180
                                from: 0; to: 100; stepSize: 1
                                value: ConnectivityService.micVolume

                                background: Rectangle {
                                    x: settingsMicSlider.leftPadding
                                    y: settingsMicSlider.topPadding + settingsMicSlider.availableHeight / 2 - height / 2
                                    width: settingsMicSlider.availableWidth
                                    height: 4; radius: 2
                                    color: ThemeService.alpha(ThemeService.fg, 0.12)

                                    Rectangle {
                                        width: settingsMicSlider.visualPosition * parent.width
                                        height: parent.height; radius: 2
                                        color: ConnectivityService.micMuted ? ThemeService.grey2 : ThemeService.purple
                                    }
                                }

                                handle: Rectangle {
                                    x: settingsMicSlider.leftPadding + settingsMicSlider.visualPosition * (settingsMicSlider.availableWidth - width)
                                    y: settingsMicSlider.topPadding + settingsMicSlider.availableHeight / 2 - height / 2
                                    width: 14; height: 14; radius: 7
                                    color: ThemeService.fg
                                    border.width: 2
                                    border.color: ThemeService.alpha(ThemeService.bg0, 0.5)
                                }
                            }

                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: micMuteMouse.containsMouse
                                       ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: ConnectivityService.micMuted ? "\udb80\ude36" : "\uf130"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    color: ConnectivityService.micMuted ? ThemeService.red : ThemeService.purple
                                }

                                MouseArea {
                                    id: micMuteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.toggleMicMute()
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // WI-FI
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Wi-Fi"
                    subtitle: ConnectivityService.wifiConnected
                              ? "Connected to " + ConnectivityService.wifiSSID
                              : (ConnectivityService.wifiEnabled ? "Not connected" : "Wi-Fi is off")

                    SettingRow {
                        label: "Wi-Fi"
                        description: "Enable or disable wireless networking"

                        Rectangle {
                            width: 42; height: 22; radius: 11
                            color: ConnectivityService.wifiEnabled
                                   ? ThemeService.alpha(ThemeService.green, 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.15)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: ThemeService.fg; y: 2
                                x: ConnectivityService.wifiEnabled ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConnectivityService.toggleWifi()
                            }
                        }
                    }

                    SettingRow {
                        label: "Signal Strength"
                        description: ConnectivityService.wifiSignal + "%"
                        visible: ConnectivityService.wifiConnected

                        Text {
                            text: ConnectivityService.wifiIcon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 20
                            color: ConnectivityService.wifiSignal >= 50
                                   ? ThemeService.green : ThemeService.yellow
                        }
                    }

                    SettingRow {
                        label: "Network Settings"
                        description: "Open nm-connection-editor"

                        Rectangle {
                            width: 60; height: 28; radius: 6
                            color: nmMouse.containsMouse
                                   ? ThemeService.alpha(ThemeService.blue, 0.15)
                                   : ThemeService.alpha(ThemeService.blue, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Open"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.blue
                            }

                            MouseArea {
                                id: nmMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConnectivityService.openWifiSettings()
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // BLUETOOTH
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Bluetooth"
                    subtitle: ConnectivityService.btConnected
                              ? ConnectivityService.btConnectedName + " connected"
                              : (ConnectivityService.btPowered ? "No devices connected" : "Bluetooth is off")

                    SettingRow {
                        label: "Bluetooth"
                        description: "Enable or disable Bluetooth"

                        Rectangle {
                            width: 42; height: 22; radius: 11
                            color: ConnectivityService.btPowered
                                   ? ThemeService.alpha(ThemeService.blue, 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.15)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: ThemeService.fg; y: 2
                                x: ConnectivityService.btPowered ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConnectivityService.toggleBluetooth()
                            }
                        }
                    }

                    SettingRow {
                        label: "Bluetooth Manager"
                        description: "Open Blueman"

                        Rectangle {
                            width: 60; height: 28; radius: 6
                            color: btMgrMouse.containsMouse
                                   ? ThemeService.alpha(ThemeService.blue, 0.15)
                                   : ThemeService.alpha(ThemeService.blue, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Open"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.blue
                            }

                            MouseArea {
                                id: btMgrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConnectivityService.openBluetoothSettings()
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // ETHERNET
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Ethernet"
                    subtitle: ConnectivityService.lanConnected
                              ? ConnectivityService.lanInterface + " — " + ConnectivityService.lanIP
                              : "Not connected"

                    SettingRow {
                        label: "Status"
                        description: ConnectivityService.lanConnected ? "Connected" : "No cable detected"

                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: ConnectivityService.lanConnected
                                   ? ThemeService.green : ThemeService.grey2
                        }
                    }

                    SettingRow {
                        label: "Interface"
                        description: ConnectivityService.lanInterface || "None"
                        visible: ConnectivityService.lanConnected
                    }

                    SettingRow {
                        label: "IP Address"
                        description: ConnectivityService.lanIP || "N/A"
                        visible: ConnectivityService.lanConnected
                    }
                }

                // Bottom spacer
                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
