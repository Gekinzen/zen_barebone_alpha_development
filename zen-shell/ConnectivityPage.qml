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
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Connectivity"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: ThemeService.fg
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
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
                                to: 100
                                stepSize: 1
                                value: ConnectivityService.audioVolume
                                onMoved: ConnectivityService.setVolume(value)

                                background: Rectangle {
                                    implicitWidth: 180
                                    implicitHeight: 4
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
                                               : ThemeService.blue
                                    }
                                }

                                handle: Rectangle {
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    x: settingsVolSlider.leftPadding + settingsVolSlider.visualPosition * (settingsVolSlider.availableWidth - width)
                                    y: settingsVolSlider.topPadding + settingsVolSlider.availableHeight / 2 - height / 2
                                    width: 14; height: 14; radius: 7
                                    antialiasing: true   // v7.0.0-beta.1-hf99: Qt won't AA rounded corners by default → smooth circle
                                    color: ThemeService.fg
                                    border.width: 2
                                    border.color: LookService.surfaceColor(ThemeService.bg0, 0.5)
                                }
                            }

                            // Mute toggle
                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: muteMouse.containsMouse
                                       ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
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
                                // v7.0.0-beta.1-hf99b: mic slider had no onMoved —
                                // dragging did nothing. Wire it to setMicVolume.
                                onMoved: ConnectivityService.setMicVolume(value)

                                background: Rectangle {
                                    implicitWidth: 180
                                    implicitHeight: 4
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
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    x: settingsMicSlider.leftPadding + settingsMicSlider.visualPosition * (settingsMicSlider.availableWidth - width)
                                    y: settingsMicSlider.topPadding + settingsMicSlider.availableHeight / 2 - height / 2
                                    width: 14; height: 14; radius: 7
                                    antialiasing: true   // v7.0.0-beta.1-hf99: Qt won't AA rounded corners by default → smooth circle
                                    color: ThemeService.fg
                                    border.width: 2
                                    border.color: LookService.surfaceColor(ThemeService.bg0, 0.5)
                                }
                            }

                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: micMuteMouse.containsMouse
                                       ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
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
                    // v8.0.0-alpha-hf188 — one status string for the whole shell, so
                    // this page, the dashboard rail and the bar tooltip cannot
                    // disagree about whether you are online.
                    subtitle: ConnectivityService.wifiStatusText

                    SettingRow {
                        label: "Wi-Fi"
                        description: "Enable or disable wireless networking"

                        HMSwitch {
                            compact: true
                            activeColor: ThemeService.alpha(ThemeService.green, 0.85)
                            checked: ConnectivityService.wifiEnabled
                            onToggled: ConnectivityService.toggleWifi()
                        }
                    }

                    // ── v8.0.0-alpha-hf188 — keep-connected ──
                    SettingRow {
                        icon: "\uf021"
                        label: "Keep me connected"
                        description: ConnectivityService.reconnectPending
                            ? ConnectivityService.wifiStatusText
                            : (ConnectivityService.lastGoodSsid.length > 0
                               ? "Rejoins " + ConnectivityService.lastGoodSsid
                                 + " automatically if it drops, backing off 5s to 60s. "
                                 + "Stops and asks instead when a password is the problem, "
                                 + "and stands down if you disconnect on purpose."
                               : "Rejoins your last working network automatically if it drops.")
                        HMSwitch {
                            compact: true
                            activeColor: ThemeService.alpha(ThemeService.green, 0.85)
                            checked: ConnectivityService.autoReconnect
                            onToggled: ConnectivityService.autoReconnect = !ConnectivityService.autoReconnect
                        }
                    }

                    // Only shown when it is actually a problem — a row that says
                    // "everything is fine" is a row nobody reads.
                    SettingRow {
                        visible: ConnectivityService.powerSaveKnown && ConnectivityService.powerSaveOn
                        icon: "\uf0e7"
                        label: "Wi-Fi power saving is on"
                        description: "The adapter is allowed to idle down, which on many "
                                     + "chipsets shows up as a link that drops for no visible "
                                     + "reason. Turning it off writes a NetworkManager drop-in, "
                                     + "so it survives reboots — unlike `iw set power_save off`, "
                                     + "which is forgotten on the next activation."
                        ZenButton {
                            text: "Turn off"
                            onClicked: ConnectivityService.disablePowerSave()
                        }
                    }

                    SettingRow {
                        label: "Signal Strength"
                        description: ConnectivityService.wifiSignal + "%"
                        visible: ConnectivityService.wifiConnected

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
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
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
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

                        HMSwitch {
                            compact: true
                            activeColor: ThemeService.alpha(ThemeService.blue, 0.85)
                            checked: ConnectivityService.btPowered
                            onToggled: ConnectivityService.toggleBluetooth()
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
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
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
