import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ControlPanel v6.13 — Quick Settings Popup
 *
 * macOS Control Center style. Shows on bar click or Super+C.
 * Features:
 *   - Volume slider (PipeWire via wpctl)
 *   - WiFi toggle + SSID + signal
 *   - Bluetooth toggle + connected device name
 *   - LAN status (auto-detect ethernet)
 *   - CPU temp + RAM usage row (from SystemMonitorService)
 *   - Expand arrow (▾) to show full connectivity details
 *   - Draggable by header
 *   - No auto-close on click outside (stays open like Settings panel)
 *
 * Closes via: ✕ button, Esc, or toggle keybind (Super+C)
 *
 * Layout:
 * ┌──────────────────────────────────┐
 * │ ☰ Quick Settings            ✕   │  ← drag handle on title
 * ├──────────────────────────────────┤
 * │ 🔊 ━━━━━━━━━━━━━━━━━━━━━ 75%   │  ← volume slider
 * │ 🎤 ━━━━━━━━━━━━━━━━━━━━━ 100%  │  ← mic slider
 * ├──────────────────────────────────┤
 * │ 📶 WiFi  HomeNetwork    [on]    │
 * │ 🔵 BT    AirPods Pro    [on]    │
 * │ 🔌 LAN   enp5s0         [up]    │
 * ├──────────────────────────────────┤
 * │ 🌡 CPU 42°C  │  RAM 23.4/128GB │
 * │ 🎮 GPU 38°C  │  VRAM 2.1/16GB  │
 * ├──────────────────────────────────┤
 * │            ▾ Expand              │  ← expand arrow
 * └──────────────────────────────────┘
 *
 * Expanded state shows WiFi network list and BT device list.
 */
Rectangle {
    id: root

    signal closeRequested()
    property bool expanded: false
    property bool hasBeenDragged: false

    width: 380
    height: expanded ? Math.min(680, baseHeight + expandedHeight) : baseHeight
    readonly property int baseHeight: mainLayout.implicitHeight + 32
    readonly property int expandedHeight: expandedSection.implicitHeight + 16

    color: ThemeService.alpha(ThemeService.bg0, 0.96)
    radius: 16
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)
    clip: true

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Keys.onEscapePressed: closeRequested()

    ColumnLayout {
        id: mainLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

        // ═══════════════════════════════════════════════
        // HEADER — drag handle + close button
        // ═══════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            RowLayout {
                anchors.fill: parent
                spacing: 8

                // Drag handle area (icon + title)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        Text {
                            text: "\uf0c9"  // bars/hamburger
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: ThemeService.blue
                        }

                        Text {
                            text: "Quick Settings"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: root
                        drag.axis: Drag.XAndYAxis
                        preventStealing: true
                        onPressed: root.hasBeenDragged = true
                    }
                }

                // Close button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: closeMouse.containsMouse
                           ? ThemeService.alpha(ThemeService.red, 0.2)
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"  // ✕
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: closeMouse.containsMouse ? ThemeService.red : ThemeService.grey0
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: ThemeService.alpha(ThemeService.fg, 0.08)
        }

        // ═══════════════════════════════════════════════
        // VOLUME SECTION — PipeWire sink + mic
        // ═══════════════════════════════════════════════
        SettingsSection {
            title: ""

            // Speaker volume
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Mute toggle icon
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: volIconMouse.containsMouse
                           ? ThemeService.alpha(ThemeService.blue, 0.15)
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ConnectivityService.audioIcon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: ConnectivityService.audioMuted ? ThemeService.grey2 : ThemeService.blue
                    }

                    MouseArea {
                        id: volIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ConnectivityService.toggleMute()
                    }
                }

                // Volume slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: ConnectivityService.audioSinkName
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: ConnectivityService.audioVolume + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: ConnectivityService.audioMuted ? ThemeService.grey2 : ThemeService.fg
                        }
                    }

                    Slider {
                        id: volSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 150
                        stepSize: 1
                        value: ConnectivityService.audioVolume
                        onMoved: ConnectivityService.setVolume(value)

                        background: Rectangle {
                            x: volSlider.leftPadding
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                            width: volSlider.availableWidth
                            height: 4
                            radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.12)

                            Rectangle {
                                width: volSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: ConnectivityService.audioMuted
                                       ? ThemeService.grey2
                                       : (ConnectivityService.audioVolume > 100
                                          ? ThemeService.orange : ThemeService.blue)
                            }
                        }

                        handle: Rectangle {
                            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: volSlider.pressed ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.9)
                            border.width: 2
                            border.color: ThemeService.alpha(ThemeService.bg0, 0.5)
                        }
                    }
                }
            }

            // Microphone volume
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: micIconMouse.containsMouse
                           ? ThemeService.alpha(ThemeService.purple, 0.15)
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ConnectivityService.micMuted ? "\udb80\ude36" : "\uf130"  // mic off/on
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: ConnectivityService.micMuted ? ThemeService.grey2 : ThemeService.purple
                    }

                    MouseArea {
                        id: micIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ConnectivityService.toggleMicMute()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: ConnectivityService.micSourceName
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: ConnectivityService.micVolume + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: ConnectivityService.micMuted ? ThemeService.grey2 : ThemeService.fg
                        }
                    }

                    Slider {
                        id: micSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 1
                        value: ConnectivityService.micVolume
                        onMoved: {
                            const v = Math.round(value)
                            // wpctl set-volume for source
                        }

                        background: Rectangle {
                            x: micSlider.leftPadding
                            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                            width: micSlider.availableWidth
                            height: 4
                            radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.12)

                            Rectangle {
                                width: micSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: ConnectivityService.micMuted ? ThemeService.grey2 : ThemeService.purple
                            }
                        }

                        handle: Rectangle {
                            x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
                            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                            width: 12
                            height: 12
                            radius: 6
                            color: micSlider.pressed ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.85)
                            border.width: 2
                            border.color: ThemeService.alpha(ThemeService.bg0, 0.5)
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // CONNECTIVITY TOGGLES — WiFi, BT, LAN
        // ═══════════════════════════════════════════════
        SettingsSection {
            title: ""

            // WiFi row
            ConnToggleRow {
                icon: ConnectivityService.wifiIcon
                label: "Wi-Fi"
                sublabel: ConnectivityService.wifiConnected
                          ? ConnectivityService.wifiSSID + " (" + ConnectivityService.wifiSignal + "%)"
                          : (ConnectivityService.wifiEnabled ? "Not connected" : "Off")
                active: ConnectivityService.wifiEnabled
                iconColor: ConnectivityService.wifiConnected ? ThemeService.green : ThemeService.grey0
                onToggled: ConnectivityService.toggleWifi()
                onSettingsClicked: ConnectivityService.openWifiSettings()
            }

            // Bluetooth row
            ConnToggleRow {
                icon: ConnectivityService.btIcon
                label: "Bluetooth"
                sublabel: ConnectivityService.btConnected
                          ? ConnectivityService.btConnectedName
                          : (ConnectivityService.btPowered ? "No devices" : "Off")
                active: ConnectivityService.btPowered
                iconColor: ConnectivityService.btConnected ? ThemeService.blue : ThemeService.grey0
                onToggled: ConnectivityService.toggleBluetooth()
                onSettingsClicked: ConnectivityService.openBluetoothSettings()
            }

            // LAN row (status only, no toggle)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: ThemeService.alpha(
                        ConnectivityService.lanConnected ? ThemeService.green : ThemeService.grey2, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: ConnectivityService.lanIcon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: ConnectivityService.lanConnected ? ThemeService.green : ThemeService.grey2
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Ethernet"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: ThemeService.fg
                    }
                    Text {
                        text: ConnectivityService.lanConnected
                              ? ConnectivityService.lanInterface +
                                (ConnectivityService.lanIP ? " · " + ConnectivityService.lanIP : "")
                              : "Not connected"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Status indicator dot
                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: ConnectivityService.lanConnected ? ThemeService.green : ThemeService.grey2
                }
            }
        }

        // ═══════════════════════════════════════════════
        // SYSTEM STATS — CPU/GPU temp + RAM
        // ═══════════════════════════════════════════════
        SettingsSection {
            title: ""

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // CPU
                StatChip {
                    icon: "\uf2db"  // microchip
                    label: SystemMonitorService.cpuName
                    value: SystemMonitorService.cpuTemp > 0
                           ? SystemMonitorService.cpuTemp + "°C"
                           : SystemMonitorService.cpuPercent + "%"
                    valueColor: SystemMonitorService.cpuTemp > 0
                                ? SystemMonitorService.tempColor(SystemMonitorService.cpuTemp)
                                : SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                    Layout.fillWidth: true
                }

                // Vertical separator
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    color: ThemeService.alpha(ThemeService.fg, 0.08)
                }

                // RAM
                StatChip {
                    icon: "\uefc5"  // memory
                    label: "RAM"
                    value: SystemMonitorService.ramUsedGb.toFixed(1) + "/" +
                           SystemMonitorService.ramTotalGb.toFixed(0) + "GB"
                    valueColor: SystemMonitorService.usageColor(SystemMonitorService.ramPercent)
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // GPU
                StatChip {
                    icon: "\uf1b2"  // gpu/cube
                    label: SystemMonitorService.gpuName
                    value: SystemMonitorService.gpuTemp > 0
                           ? SystemMonitorService.gpuTemp + "°C"
                           : (SystemMonitorService.gpuUsage + "%")
                    valueColor: SystemMonitorService.gpuTemp > 0
                                ? SystemMonitorService.tempColor(SystemMonitorService.gpuTemp)
                                : SystemMonitorService.usageColor(SystemMonitorService.gpuUsage)
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    color: ThemeService.alpha(ThemeService.fg, 0.08)
                }

                // VRAM
                StatChip {
                    icon: "\uefc5"
                    label: "VRAM"
                    value: SystemMonitorService.gpuVramTotal > 0
                           ? SystemMonitorService.gpuVramUsed.toFixed(1) + "/" +
                             SystemMonitorService.gpuVramTotal.toFixed(0) + "GB"
                           : "N/A"
                    valueColor: ThemeService.grey0
                    Layout.fillWidth: true
                }
            }
        }

        // ═══════════════════════════════════════════════
        // EXPAND ARROW — toggles expanded section
        // ═══════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: expandMouse.containsMouse
                   ? ThemeService.alpha(ThemeService.fg, 0.05) : "transparent"
            radius: 6

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: root.expanded ? "▴ Collapse" : "▾ Expand"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }
            }

            MouseArea {
                id: expandMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    // ═══════════════════════════════════════════════
    // EXPANDED SECTION — WiFi network list + BT devices
    // ═══════════════════════════════════════════════
    ColumnLayout {
        id: expandedSection
        anchors.top: mainLayout.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        anchors.topMargin: 4
        spacing: 12
        visible: root.expanded
        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        // WiFi networks
        SettingsSection {
            title: "Wi-Fi Networks"
            visible: ConnectivityService.wifiEnabled

            Repeater {
                model: ConnectivityService.wifiNetworks

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 8

                    Text {
                        text: modelData.active ? "\uf00c" : "\uf1eb"  // check or wifi
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: modelData.active ? ThemeService.green : ThemeService.grey1
                        Layout.preferredWidth: 20
                    }

                    Text {
                        text: modelData.ssid
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: modelData.active ? Font.DemiBold : Font.Normal
                        color: modelData.active ? ThemeService.fg : ThemeService.grey0
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.signal + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }

                    Text {
                        text: modelData.security ? "\uf023" : ""  // lock
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: ThemeService.grey1
                        visible: modelData.security.length > 0
                    }

                    // Connect button (only for non-active networks)
                    Rectangle {
                        visible: !modelData.active
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 24
                        radius: 6
                        color: wifiConnMouse.containsMouse
                               ? ThemeService.alpha(ThemeService.blue, 0.2)
                               : ThemeService.alpha(ThemeService.blue, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.blue
                        }

                        MouseArea {
                            id: wifiConnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConnectivityService.connectWifi(modelData.ssid, "")
                        }
                    }
                }
            }

            // Refresh button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                color: refreshMouse.containsMouse
                       ? ThemeService.alpha(ThemeService.fg, 0.05) : "transparent"
                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: "\uf021  Refresh Networks"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ConnectivityService.refresh()
                }
            }
        }

        // Bluetooth devices
        SettingsSection {
            title: "Bluetooth Devices"
            visible: ConnectivityService.btPowered

            Text {
                visible: ConnectivityService.btDevices.length === 0
                text: "No connected devices"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
                Layout.fillWidth: true
            }

            Repeater {
                model: ConnectivityService.btDevices

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 8

                    Text {
                        text: "\uf294"  // bluetooth
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: ThemeService.blue
                        Layout.preferredWidth: 20
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.fg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.mac
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: ThemeService.grey2
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 24
                        radius: 6
                        color: btDiscMouse.containsMouse
                               ? ThemeService.alpha(ThemeService.red, 0.2)
                               : ThemeService.alpha(ThemeService.red, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "Disconnect"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.red
                        }

                        MouseArea {
                            id: btDiscMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConnectivityService.disconnectBtDevice(modelData.mac)
                        }
                    }
                }
            }
        }

        // Open full settings link
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: openSettingsMouse.containsMouse
                   ? ThemeService.alpha(ThemeService.blue, 0.1) : "transparent"
            radius: 6

            Text {
                anchors.centerIn: parent
                text: "\uf013  Open Settings → Connectivity"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: ThemeService.blue
            }

            MouseArea {
                id: openSettingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ConnectivityService.openAudioSettings()
            }
        }
    }
}
