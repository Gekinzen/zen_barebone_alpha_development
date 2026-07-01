import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ControlPanel v6.16.1 — Quick Settings Popup
 *
 * v6.16.1 ADDITIONS:
 *   - POWER PROFILE section with 3 pills (Saver/Balanced/Performance)
 *     + Gaming Boost toggle. Hidden when powerprofilesctl unavailable.
 *   - Battery % + charging bolt shown in Power Profile header row
 *     (laptops only — auto-hides on desktops via batteryPresent check).
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

    // v6.16.1.10: Cascade-to-side mode. When expanded content would push
    // the panel past `maxSingleHeight`, split layout into two columns:
    //   Left column (380px): original mainLayout (audio / conn / sysinfo
    //   / power profile). Right column (380px): expandedSection (tabs).
    // Windows Start Menu style — instead of truncating at the bottom, the
    // extra content folds out to the right.
    //
    // v6.16.1.11 CIRCULAR DEPENDENCY FIX:
    //   v6.16.1.10 had: cascadeMode → expandedHeight → implicitHeight
    //                   → root.height → cascadeMode (LOOP).
    //   Result: on expand, recalc ran forever, panel height grew
    //   uncontrollably downward in a runaway feedback loop.
    //   Fix: use a FIXED constant for the expanded section's reserved
    //   height — don't derive it from root.height. Cascade decision then
    //   uses stable inputs (mainLayout.implicitHeight + constant).
    readonly property int maxSingleHeight: 720
    readonly property int columnWidth: 380
    readonly property int expandedReservedHeight: 380   // fixed, not derived
    readonly property bool cascadeMode:
        expanded && (baseHeight + expandedReservedHeight + 16 > maxSingleHeight)

    width: cascadeMode ? (columnWidth * 2 + 2) : columnWidth
    height: {
        if (!expanded) return baseHeight
        if (cascadeMode) return Math.max(baseHeight, expandedReservedHeight + 32)
        return Math.min(maxSingleHeight, baseHeight + expandedReservedHeight + 16)
    }

    readonly property int baseHeight: mainLayout.implicitHeight + 32
    // v6.16.1.11: expandedHeight now references the fixed constant so
    // nothing derives its size from root.height. Retained for code
    // readability elsewhere in the file.
    readonly property int expandedHeight: expandedReservedHeight + 16

    color: ThemeService.alpha(ThemeService.bg0, 0.96)
    radius: 16
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)

    // v7.0.0-beta.1-hf53 — HyprbarsMimic was here.
    // v7.0.0-beta.1-hf64 — REMOVED per user request.
    //
    // User wants the original header (drag handle + fullscreen +
    // close button) to ALWAYS show on the Hypr Control Panel, even
    // when hyprbars is enabled. The mimic was confusing — replace-
    // ing the familiar header with traffic lights felt inconsistent.
    //
    // The real hyprbars plugin handles regular Hyprland windows.
    // Zen Shell popups keep their native Zen header style.
    //
    // HyprbarsMimic instance removed. hyprbarsMimic references
    // below replaced with { visible: false, height: 0 } shim.
    QtObject {
        id: hyprbarsMimic
        property bool visible: false
        property int height: 0
    }
    clip: true

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // v6.16.1.10: vertical divider visible only in cascade mode,
    // separates the two column panels for visual clarity.
    Rectangle {
        visible: root.cascadeMode
        x: root.columnWidth
        y: 12
        width: 1
        height: root.height - 24
        color: ThemeService.alpha(ThemeService.fg, 0.08)
        opacity: root.cascadeMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Keys.onEscapePressed: closeRequested()

    // v7.0.0-alpha.10-hf4: Absorb scroll wheel events at the CC root
    // level. Without this, scroll wheel events on the CC's layer-shell
    // surface were causing focus dance with WlrKeyboardFocus.OnDemand —
    // user reported "scroll ko nag close siya sabay nag open lage kada
    // scroll ko" (CC closes then reopens on every scroll). The handler
    // accepts every wheel event so it never propagates to the layer-
    // shell focus subsystem. Children that genuinely need scroll
    // (ScrollViews inside CC sections) still get their events because
    // they're INSIDE this handler — the handler only catches wheels
    // that bubble all the way up to the root.
    WheelHandler {
        target: null   // don't redirect — just consume
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            // Swallow — event doesn't propagate further. Children that
            // already handled the event (ScrollViews) will have set
            // event.accepted = true before reaching here, so this is
            // a no-op for them. For the empty CC chrome areas, this
            // prevents the wheel from triggering layer-shell focus
            // changes.
            event.accepted = true
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.top: parent.top
        anchors.left: parent.left
        // v6.16.1.10: in cascade mode, constrain to left column only
        anchors.right: root.cascadeMode ? undefined : parent.right
        width: root.cascadeMode ? (root.columnWidth - 32) : undefined
        anchors.margins: 16
        // v7.0.0-beta.1-hf54: extra top clearance when HyprbarsMimic
        // is visible so content sits below the mimic bar instead of
        // overlapping it. hyprbarsMimic.height = HyprbarsService.barHeight
        // when visible, 0 when hidden.
        anchors.topMargin: 16 + (hyprbarsMimic.visible ? hyprbarsMimic.height + 4 : 0)
        spacing: 12

        // ═══════════════════════════════════════════════
        // HEADER — drag handle + close button
        //
        // v7.0.0-beta.1-hf64: always visible. Previously hidden
        // when HyprbarsMimic was showing. Now mimic is removed
        // from ControlPanel — native header always stays.
        // ═══════════════════════════════════════════════
        Item {
            visible: true
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            RowLayout {
                anchors.fill: parent
                spacing: 8

                // Drag handle area (icon + title)
                // v7.0.0-alpha.7-hf3: SearchBar removed from CC header.
                // CC has limited horizontal space (320px column) which
                // can't fit search bar + close button + drag handle.
                // Use Ctrl+F overlay (works system-wide) to search CC
                // entries — same SettingsSearchService backend, just
                // accessed via overlay instead of inline bar.
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

                        // v7.0.0-alpha.11: Densho mode bilingual title.
                        // 操 (sou) = "operation/control", per the Densho
                        // naming convention (one kanji per major surface).
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            Text {
                                visible: DenshoService.denshoMode
                                text: "操"
                                font.family: "Noto Sans CJK JP"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: ThemeService.alpha(ThemeService.fg, 0.55)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: "Quick Settings"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: ThemeService.fg
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
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

                // Spacer to push search + close to right
                // v7.0.0-alpha.7-hf3: search bar removed from CC header.
                // CC has tight horizontal space (compact 320px panel) —
                // a 240px search bar plus close button plus drag handle
                // didn't fit cleanly. Use Ctrl+F overlay (system-wide
                // global modal) to search Control Center entries —
                // same SettingsSearchService backend, surfaces all
                // CC entries with `surface: "controlpanel"` filter
                // applied automatically.

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
        // v7.0.0-alpha.13: WORKFLOW PROFILES
        //
        // 5-tile picker for one-click profile switching:
        // Work / Gaming / Focus / Movie / Sleep
        //
        // Each profile bundles brightness + DND + power profile.
        // Active profile gets blue ring. Click to switch.
        // ═══════════════════════════════════════════════
        SettingsSection {
            title: ""

            WorkflowProfilePicker {
                Layout.fillWidth: true
            }
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

                    // v7.0.0-beta.1-hf16: replace QQC2 Slider with the
                    // same custom Rectangle-based slider used in the bar
                    // sound popup. Cleaner drag (no binding loop), full
                    // theme control, and visually consistent with the bar
                    // popup so users see one design across the shell.
                    Item {
                        id: volSliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        readonly property real ratio:
                            Math.max(0, Math.min(1,
                                ConnectivityService.audioVolume / 100))

                        // Track background
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.15)
                        }
                        // Filled portion
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * volSliderTrack.ratio
                            height: 4; radius: 2
                            color: ConnectivityService.audioMuted
                                   ? ThemeService.grey2
                                   : ThemeService.blue
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                        // Knob
                        Rectangle {
                            width: 14; height: 14; radius: 7
                            y: (parent.height - height) / 2
                            x: Math.max(0, parent.width * volSliderTrack.ratio - width / 2)
                            color: ThemeService.fg
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.bg0, 0.4)
                            Behavior on x { NumberAnimation { duration: 80 } }
                        }
                        // Drag / click area
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function _set(x) {
                                const r = Math.max(0, Math.min(1, x / width))
                                ConnectivityService.setVolume(Math.round(r * 100))
                            }
                            onPressed: function(m) { _set(m.x) }
                            onPositionChanged: function(m) {
                                if (pressed) _set(m.x)
                            }
                            onWheel: function(w) {
                                const cur = ConnectivityService.audioVolume
                                const next = w.angleDelta.y > 0
                                             ? Math.min(100, cur + 5)
                                             : Math.max(0, cur - 5)
                                ConnectivityService.setVolume(next)
                                w.accepted = true
                            }
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

                    // v7.0.0-beta.1-hf16: same custom slider design as
                    // speaker above + bar popup (consistent across shell).
                    Item {
                        id: micSliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        readonly property real ratio:
                            Math.max(0, Math.min(1,
                                ConnectivityService.micVolume / 100))

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.15)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * micSliderTrack.ratio
                            height: 4; radius: 2
                            color: ConnectivityService.micMuted
                                   ? ThemeService.grey2
                                   : ThemeService.purple
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                        Rectangle {
                            width: 14; height: 14; radius: 7
                            y: (parent.height - height) / 2
                            x: Math.max(0, parent.width * micSliderTrack.ratio - width / 2)
                            color: ThemeService.fg
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.bg0, 0.4)
                            Behavior on x { NumberAnimation { duration: 80 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function _set(x) {
                                const r = Math.max(0, Math.min(1, x / width))
                                ConnectivityService.setMicVolume(Math.round(r * 100))
                            }
                            onPressed: function(m) { _set(m.x) }
                            onPositionChanged: function(m) {
                                if (pressed) _set(m.x)
                            }
                            onWheel: function(w) {
                                const cur = ConnectivityService.micVolume
                                const next = w.angleDelta.y > 0
                                             ? Math.min(100, cur + 5)
                                             : Math.max(0, cur - 5)
                                ConnectivityService.setMicVolume(next)
                                w.accepted = true
                            }
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
        // POWER PROFILE (v6.16.1) — 3 pill buttons + Gaming Boost
        // Hidden when powerprofilesctl isn't installed, so it only
        // shows up on systems that can actually use it.
        // ═══════════════════════════════════════════════
        SettingsSection {
            title: ""
            visible: PowerProfileService.available

            // Header row: label + battery % if laptop
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "\uf0e7  Power Profile"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: ThemeService.grey0
                    Layout.fillWidth: true
                }

                // Battery % on the right (laptops only)
                Text {
                    visible: SystemMonitorService.batteryPresent
                    text: {
                        const bolt = SystemMonitorService.batteryCharging ? "\uf0e7 " : ""
                        return bolt + SystemMonitorService.batteryCapacity + "%"
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: {
                        if (SystemMonitorService.batteryCharging) return ThemeService.green
                        if (SystemMonitorService.batteryCapacity <= 10) return ThemeService.red
                        if (SystemMonitorService.batteryCapacity <= 30) return ThemeService.orange
                        return ThemeService.grey0
                    }
                }
            }

            // ── Three profile pills ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { id: "power-saver", label: "Saver",       icon: "\uf06c" },
                        { id: "balanced",    label: "Balanced",    icon: "\uf24e" },
                        { id: "performance", label: "Performance", icon: "\uf0e7" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive: PowerProfileService.currentProfile === modelData.id
                                                         && !PowerProfileService.gamingBoostActive
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 8
                        color: isActive
                            ? ThemeService.alpha(ThemeService.blue, 0.22)
                            : (pillMouse.containsMouse
                                ? ThemeService.alpha(ThemeService.fg, 0.08)
                                : ThemeService.alpha(ThemeService.bg2, 0.55))
                        border.width: isActive ? 1 : 0
                        border.color: isActive ? ThemeService.blue : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                        }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Switching to a regular profile turns off
                                // gaming boost if it was active
                                if (PowerProfileService.gamingBoostActive) {
                                    PowerProfileService.setGamingBoost(false)
                                }
                                PowerProfileService.setProfile(modelData.id)
                            }
                        }
                    }
                }
            }

            // ── Gaming Boost toggle ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: PowerProfileService.gamingBoostActive
                    ? ThemeService.alpha(ThemeService.red, 0.22)
                    : (boostMouse.containsMouse
                        ? ThemeService.alpha(ThemeService.fg, 0.08)
                        : ThemeService.alpha(ThemeService.bg2, 0.55))
                border.width: PowerProfileService.gamingBoostActive ? 1 : 0
                border.color: PowerProfileService.gamingBoostActive
                    ? ThemeService.red : "transparent"

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "🎮"
                        font.pixelSize: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: PowerProfileService.gamingBoostActive
                                ? "Gaming Boost ACTIVE"
                                : "Gaming Boost"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: PowerProfileService.gamingBoostActive
                                ? ThemeService.red : ThemeService.fg
                        }
                        Text {
                            text: PowerProfileService.gamingBoostActive
                                ? "Performance + effects OFF · click to restore"
                                : "Performance + disable blur/dim/anim for max FPS"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Toggle switch — visual state only. The outer
                    // row-wide MouseArea (boostMouse) handles clicks.
                    // HMSwitch's own MouseArea is gated off via enabled:false
                    // so it doesn't intercept the row click.
                    HMSwitch {
                        compact: true
                        activeColor: ThemeService.alpha(ThemeService.red, 0.85)
                        checked: PowerProfileService.gamingBoostActive
                        // Click handled by parent row — this switch is visual
                        enabled: false
                        opacity: 1.0  // counteract the default disabled look
                    }
                }

                MouseArea {
                    id: boostMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProfileService.toggleGamingBoost()
                }
            }

            // ═══════════════════════════════════════════════════════
            // ── Dark Mode toggle (v6.16.4.12.9.8 / Modori) ──
            //
            // Toggles GTK3 + GTK4 + libadwaita color-scheme in one
            // tap. Script `zen-darkmode.sh` is the source of truth
            // for application — this row is just the visual surface
            // and click target. Auto-hides if the script isn't
            // installed yet (the install.sh phase that drops the
            // script may have been skipped on legacy installs).
            //
            // Affects every GTK3/GTK4 application that respects
            // either gsettings or settings.ini — Thunar, Nautilus,
            // GNOME Settings, GIMP (GTK port), Geary, etc. Apps
            // that have their own theme preference (Firefox,
            // Chromium with their own dark mode) are unaffected.
            // ═══════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: DarkModeService.available
                radius: 8
                color: darkmodeMouse.containsMouse
                       ? ThemeService.alpha(ThemeService.fg, 0.08)
                       : ThemeService.alpha(ThemeService.bg2, 0.55)

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: DarkModeService.isDark ? "🌙" : "☀️"
                        font.pixelSize: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: DarkModeService.isDark ? "Dark Mode" : "Light Mode"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }
                        Text {
                            text: DarkModeService.isDark
                                  ? "GTK3 / GTK4 / libadwaita apps using dark theme"
                                  : "GTK3 / GTK4 / libadwaita apps using light theme"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Visual switch. The outer row MouseArea handles
                    // the click; we gate the switch's own MouseArea
                    // off (enabled:false) so it doesn't intercept.
                    HMSwitch {
                        compact: true
                        activeColor: ThemeService.alpha(ThemeService.blue, 0.85)
                        checked: DarkModeService.isDark
                        enabled: false
                        opacity: 1.0
                    }
                }

                MouseArea {
                    id: darkmodeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DarkModeService.toggle()
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
                    // v6.16.1.10: different icon/label in cascade mode —
                    // the expansion goes sideways, not down.
                    text: root.expanded
                        ? (root.cascadeMode ? "◂ Collapse" : "▴ Collapse")
                        : "▸ Expand"
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
    // EXPANDED SECTION — v6.16.1.8 Tabbed UI
    // Previous ScrollView/Flickable approach had layout-resolution
    // issues (expandedSection.implicitHeight bouncing to 0, panel
    // growing in height but content collapsed). Paul also requested
    // tabs for WiFi/Bluetooth separation.
    //
    // New design: three tabs (WiFi / Bluetooth / Audio). Only one tab's
    // content is visible at a time → smaller implicit height, cleaner
    // layout, and the panel's expanded height is predictable.
    // Each tab's content is a Flickable so long lists scroll internally
    // without fighting the panel's own height calc.
    // ═══════════════════════════════════════════════
    property string expandedTab: "wifi"   // wifi | bluetooth | audio

    Item {
        id: expandedSection
        // v6.16.1.10: Cascade mode moves expandedSection to right column.
        // Non-cascade mode keeps original layout (below mainLayout).
        anchors.top: root.cascadeMode ? parent.top : mainLayout.bottom
        anchors.left: root.cascadeMode ? undefined : parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.cascadeMode ? (root.columnWidth - 32) : undefined
        anchors.topMargin: root.cascadeMode ? 16 : 4
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        anchors.leftMargin: root.cascadeMode ? 0 : 16
        clip: true
        visible: root.expanded
        opacity: root.expanded ? 1 : 0
        // v6.16.1.11: FIXED implicitHeight — must not depend on root.height
        // or we get the infinite-loop bug (cascadeMode → height → implicit
        // → cascade). Use anchors.bottom to fill available space in
        // cascade mode; the implicit value here is just the reservation
        // used by the height-calc.
        implicitHeight: root.expandedReservedHeight

        // v6.16.1.10: slide-in from right when cascade mode activates
        transform: Translate {
            x: root.cascadeMode
                ? (root.expanded ? 0 : 40)
                : 0
            Behavior on x {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // ── Tab bar ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { id: "wifi",      label: "Wi-Fi",     icon: "\uf1eb" },
                        { id: "bluetooth", label: "Bluetooth", icon: "\uf294" },
                        { id: "audio",     label: "Audio",     icon: "\uf028" },
                        // v6.16.2.3.2: Input tab — mouse sensitivity/scroll
                        // live-controlled via MouseSettingsService.
                        { id: "input",     label: "Input",     icon: "\uf245" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive: root.expandedTab === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        color: isActive
                            ? ThemeService.alpha(ThemeService.blue, 0.22)
                            : (tabMouseArea.containsMouse
                                ? ThemeService.alpha(ThemeService.fg, 0.08)
                                : ThemeService.alpha(ThemeService.bg2, 0.45))
                        border.width: isActive ? 1 : 0
                        border.color: isActive ? ThemeService.blue : "transparent"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expandedTab = modelData.id
                        }
                    }
                }
            }

            // ── Tab content area ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: ThemeService.alpha(ThemeService.bg1, 0.5)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.06)
                clip: true

                // ─── WiFi tab ───
                Flickable {
                    id: wifiFlick
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "wifi"
                    contentWidth: wifiFlick.width
                    contentHeight: wifiCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: wifiCol
                        // v6.16.1.9: explicit id ref instead of parent.parent.width
                        // which was unreliable across Quickshell versions.
                        // v6.16.4.12.9.9 (Modori): full WiFi UI redesign —
                        // saved/available split, larger tap targets,
                        // refresh button, forget button, signal-bars icon.
                        width: wifiFlick.width - 24
                        spacing: 4

                        // ── Computed properties for section split ──
                        // Saved networks that are CURRENTLY visible in
                        // the scan results. Hide the saved section
                        // entirely when out of range.
                        readonly property var _savedAndVisible: {
                            const saved = ConnectivityService.savedWifiNetworks || []
                            const visible = ConnectivityService.wifiNetworks || []
                            const visibleSsids = new Set(visible.map(n => n.ssid))
                            return saved.filter(s => visibleSsids.has(s))
                        }
                        // Available (not-saved, not-active) networks.
                        readonly property var _availableNew: {
                            const all = ConnectivityService.wifiNetworks || []
                            const savedSet = new Set(ConnectivityService.savedWifiNetworks || [])
                            return all.filter(n => !savedSet.has(n.ssid) && !n.active)
                        }

                        // ── Refresh button row (always visible when wifi is on) ──
                        RowLayout {
                            visible: ConnectivityService.wifiEnabled
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 8

                            Item { Layout.fillWidth: true }   // spacer

                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 26
                                radius: 6
                                color: wifiRefreshMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.blue, 0.2)
                                    : ThemeService.alpha(ThemeService.bg2, 0.5)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.fg, 0.08)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "\uf021"   // fa-refresh
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: ThemeService.blue
                                    }
                                    Text {
                                        text: "Rescan"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: ThemeService.fg
                                    }
                                }

                                MouseArea {
                                    id: wifiRefreshMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.scanWifi()
                                }
                            }
                        }

                        // ── WiFi off state ──
                        Text {
                            visible: !ConnectivityService.wifiEnabled
                            text: "Wi-Fi is off"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.grey1
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }

                        // ── Empty state ──
                        Text {
                            visible: ConnectivityService.wifiEnabled
                                     && ConnectivityService.wifiNetworks.length === 0
                            text: "Scanning..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.grey1
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }

                        // ═══════════════════════════════════════
                        // SAVED NETWORKS section
                        // ═══════════════════════════════════════
                        Text {
                            visible: ConnectivityService.wifiEnabled
                                     && wifiCol._savedAndVisible.length > 0
                            text: "SAVED NETWORKS"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                        }

                        Repeater {
                            model: ConnectivityService.wifiEnabled
                                   ? wifiCol._savedAndVisible : []

                            Rectangle {
                                id: savedRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8

                                readonly property bool isActive: ConnectivityService.wifiSSID === modelData
                                readonly property var _scanInfo: {
                                    const list = ConnectivityService.wifiNetworks || []
                                    for (let i = 0; i < list.length; i++) {
                                        if (list[i].ssid === modelData) return list[i]
                                    }
                                    return { signal: 0, security: "" }
                                }

                                color: savedRow.isActive
                                    ? ThemeService.alpha(ThemeService.green, 0.12)
                                    : (savedRowMouse.containsMouse
                                        ? ThemeService.alpha(ThemeService.fg, 0.06)
                                        : ThemeService.alpha(ThemeService.bg2, 0.4))
                                border.width: savedRow.isActive ? 1 : 0
                                border.color: savedRow.isActive
                                    ? ThemeService.alpha(ThemeService.green, 0.4)
                                    : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Text {
                                        text: savedRow.isActive ? "\uf00c" : "\uf1eb"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: savedRow.isActive
                                            ? ThemeService.green : ThemeService.blue
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: savedRow.modelData
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: savedRow.isActive
                                                ? "Connected · " + savedRow._scanInfo.signal + "%"
                                                : "Saved · tap to reconnect · " + savedRow._scanInfo.signal + "%"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: savedRow.isActive
                                                ? ThemeService.green : ThemeService.grey1
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Forget button
                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 6
                                        color: forgetMouse.containsMouse
                                            ? ThemeService.alpha(ThemeService.red, 0.18)
                                            : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf2ed"   // fa-trash
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: forgetMouse.containsMouse
                                                ? ThemeService.red : ThemeService.grey1
                                        }

                                        MouseArea {
                                            id: forgetMouse
                                            anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ConnectivityService.forgetWifi(savedRow.modelData)
                                        }
                                    }
                                }

                                // Row click → reconnect (entire row except forget btn)
                                MouseArea {
                                    id: savedRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    anchors.rightMargin: 38
                                    hoverEnabled: true
                                    cursorShape: savedRow.isActive
                                        ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    enabled: !savedRow.isActive
                                    onClicked: ConnectivityService.reconnectWifi(savedRow.modelData)
                                }
                            }
                        }

                        // ═══════════════════════════════════════
                        // AVAILABLE NETWORKS section
                        // ═══════════════════════════════════════
                        Text {
                            visible: ConnectivityService.wifiEnabled
                                     && wifiCol._availableNew.length > 0
                            text: "AVAILABLE NETWORKS"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                        }

                        Repeater {
                            model: ConnectivityService.wifiEnabled
                                   ? wifiCol._availableNew : []

                            Rectangle {
                                id: availRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8

                                color: availRowMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.fg, 0.06)
                                    : ThemeService.alpha(ThemeService.bg2, 0.4)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    // Signal-strength colored icon
                                    Text {
                                        text: "\uf1eb"   // fa-wifi
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: {
                                            const s = availRow.modelData.signal
                                            if (s >= 60) return ThemeService.green
                                            if (s >= 35) return ThemeService.yellow
                                            return ThemeService.grey1
                                        }
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: availRow.modelData.ssid
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: availRow.modelData.signal + "% · "
                                                  + (availRow.modelData.security
                                                     && availRow.modelData.security.length > 0
                                                     ? availRow.modelData.security : "Open")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: ThemeService.grey1
                                        }
                                    }

                                    // Lock icon for secured networks
                                    Text {
                                        text: "\uf023"   // fa-lock
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: ThemeService.grey1
                                        visible: availRow.modelData.security
                                                 && availRow.modelData.security.length > 0
                                    }
                                }

                                MouseArea {
                                    id: availRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.connectWifi(
                                        availRow.modelData.ssid, availRow.modelData.security)
                                }
                            }
                        }
                    }
                }

                // ─── Bluetooth tab ───
                Flickable {
                    id: btFlick
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "bluetooth"
                    contentWidth: btFlick.width
                    contentHeight: btCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: btCol
                        // v6.16.1.9: explicit id ref
                        // v6.16.4.12.9.9 (Modori): full BT UI redesign —
                        // connected/paired/nearby split, scan toggle,
                        // pair button, larger tap targets.
                        width: btFlick.width - 24
                        spacing: 6

                        // ── Scan toggle button row (when BT is on) ──
                        RowLayout {
                            visible: ConnectivityService.btPowered
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 8

                            Item { Layout.fillWidth: true }   // spacer

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 26
                                radius: 6
                                color: btScanMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.blue, 0.25)
                                    : (ConnectivityService.btScanning
                                        ? ThemeService.alpha(ThemeService.blue, 0.18)
                                        : ThemeService.alpha(ThemeService.bg2, 0.5))
                                border.width: ConnectivityService.btScanning ? 1 : 1
                                border.color: ConnectivityService.btScanning
                                    ? ThemeService.blue
                                    : ThemeService.alpha(ThemeService.fg, 0.08)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: ConnectivityService.btScanning
                                            ? "\uf256"   // fa-hand-stop (stop scan)
                                            : "\uf002"   // fa-search (start scan)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: ConnectivityService.btScanning
                                            ? ThemeService.blue : ThemeService.fg
                                    }
                                    Text {
                                        text: ConnectivityService.btScanning
                                            ? "Stop scan" : "Scan nearby"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: ConnectivityService.btScanning
                                            ? ThemeService.blue : ThemeService.fg
                                    }
                                }

                                MouseArea {
                                    id: btScanMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (ConnectivityService.btScanning)
                                            ConnectivityService.stopBtScan()
                                        else
                                            ConnectivityService.startBtScan()
                                    }
                                }
                            }
                        }

                        // ── BT off state ──
                        Text {
                            visible: !ConnectivityService.btPowered
                            text: "Bluetooth is off"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.grey1
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }

                        // ── Empty state ──
                        Text {
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btDevices.length === 0
                                     && ConnectivityService.btPairedDevices.length === 0
                                     && (!ConnectivityService.btScanning
                                         || ConnectivityService.btNearbyDevices.length === 0)
                            text: ConnectivityService.btScanning
                                  ? "Searching for devices..."
                                  : "No paired or connected devices.\nTap 'Scan nearby' to find devices."
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey1
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            Layout.topMargin: 20
                        }

                        // ═══════════════════════════════════════
                        // CONNECTED section
                        // ═══════════════════════════════════════
                        Text {
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btDevices.length > 0
                            text: "CONNECTED"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                        }

                        Repeater {
                            model: ConnectivityService.btPowered
                                   ? ConnectivityService.btDevices : []

                            Rectangle {
                                id: connectedRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: 8
                                color: ThemeService.alpha(ThemeService.green, 0.12)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.green, 0.4)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Text {
                                        text: "\uf294"   // fa-bluetooth
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                        color: ThemeService.green
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: connectedRow.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "Connected · " + connectedRow.modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: ThemeService.green
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.preferredHeight: 30
                                        radius: 6
                                        color: btDiscMouse.containsMouse
                                            ? ThemeService.alpha(ThemeService.red, 0.25)
                                            : ThemeService.alpha(ThemeService.red, 0.1)
                                        border.width: 1
                                        border.color: ThemeService.alpha(ThemeService.red, 0.3)

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
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ConnectivityService.disconnectBtDevice(connectedRow.modelData.mac)
                                        }
                                    }
                                }
                            }
                        }

                        // ═══════════════════════════════════════
                        // PAIRED (but not connected) section
                        // ═══════════════════════════════════════
                        Text {
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btPairedDevices.length > 0
                            text: "PAIRED · TAP TO RECONNECT"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                        }

                        Repeater {
                            model: ConnectivityService.btPowered
                                   ? ConnectivityService.btPairedDevices : []

                            Rectangle {
                                id: pairedRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8
                                color: pairedRowMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.fg, 0.06)
                                    : ThemeService.alpha(ThemeService.bg2, 0.4)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: "\uf294"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: ThemeService.blue
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: pairedRow.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: pairedRow.modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: ThemeService.grey2
                                        }
                                    }

                                    // Forget button
                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 6
                                        color: btForgetMouse.containsMouse
                                            ? ThemeService.alpha(ThemeService.red, 0.18)
                                            : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf2ed"   // fa-trash
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: btForgetMouse.containsMouse
                                                ? ThemeService.red : ThemeService.grey1
                                        }

                                        MouseArea {
                                            id: btForgetMouse
                                            anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ConnectivityService.unpairBtDevice(pairedRow.modelData.mac)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: pairedRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    anchors.rightMargin: 38
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.connectBtDevice(pairedRow.modelData.mac)
                                }
                            }
                        }

                        // ═══════════════════════════════════════
                        // NEARBY (scan-discovered) section
                        // ═══════════════════════════════════════
                        Text {
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btScanning
                                     && ConnectivityService.btNearbyDevices.length > 0
                            text: "NEARBY · TAP TO PAIR"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.blue
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                        }

                        Repeater {
                            model: (ConnectivityService.btPowered
                                    && ConnectivityService.btScanning)
                                   ? ConnectivityService.btNearbyDevices : []

                            Rectangle {
                                id: nearbyRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8
                                color: nearbyRowMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.blue, 0.18)
                                    : ThemeService.alpha(ThemeService.bg2, 0.4)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.blue, 0.2)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: "\uf002"   // fa-search
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: ThemeService.blue
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: nearbyRow.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "Tap to pair · " + nearbyRow.modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: ThemeService.blue
                                        }
                                    }
                                }

                                MouseArea {
                                    id: nearbyRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.pairBtDevice(nearbyRow.modelData.mac)
                                }
                            }
                        }
                    }
                }

                // ─── Audio tab ───
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "audio"
                    spacing: 12

                    Text {
                        text: "Audio devices and settings are managed"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.grey0
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Text {
                        text: "by your system mixer (pavucontrol / wpctl)."
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.grey0
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: openPavuMouse.containsMouse
                            ? ThemeService.alpha(ThemeService.blue, 0.22)
                            : ThemeService.alpha(ThemeService.blue, 0.12)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.blue, 0.5)

                        Text {
                            anchors.centerIn: parent
                            text: "\uf013  Open pavucontrol"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }

                        MouseArea {
                            id: openPavuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConnectivityService.openAudioSettings()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ─── v6.16.2.3.2: Input tab (mouse / touchpad) ───
                // Live-applies via MouseSettingsService → hyprctl keyword.
                // Persists to ~/.config/hypr/zen-mouse.conf (sourced by
                // hyprland.conf) so changes survive Hyprland restarts.
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "input"
                    spacing: 14

                    // Section label
                    Text {
                        text: "Mouse"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }

                    // Sensitivity slider  (-1.0 … +1.0)
                    // v7.0.0-beta.1-hf41: replaced QQC2 Slider with the
                    // same custom Rectangle slider used by volume in
                    // the Audio tab. Visually consistent across the
                    // shell, plus cleaner drag behavior (no binding
                    // loop, no theme override quirks).
                    //
                    // Range is signed (-1.0 to +1.0) so the "ratio"
                    // calculation maps -1.0 → 0, 0 → 0.5, +1.0 → 1.0
                    // for the visual fill. Filled portion grows from
                    // CENTER, not left edge, to make the sign visible
                    // — negative = fill left of center, positive =
                    // fill right of center.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Sensitivity"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.grey0
                                Layout.fillWidth: true
                            }
                            Text {
                                text: MouseSettingsService.sensitivity.toFixed(2)
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                color: ThemeService.blue
                            }
                        }
                        Item {
                            id: sensSliderTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            readonly property real value: MouseSettingsService.sensitivity
                            // Map -1.0..+1.0 → 0.0..1.0 (center-anchored visually)
                            readonly property real ratio:
                                Math.max(0, Math.min(1, (value + 1.0) / 2.0))

                            // Track background
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 4; radius: 2
                                color: ThemeService.alpha(ThemeService.fg, 0.15)
                            }
                            // Center tick marker (visual anchor at 0.0)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width / 2 - width / 2
                                width: 2; height: 8
                                color: ThemeService.alpha(ThemeService.fg, 0.35)
                                radius: 1
                            }
                            // Filled portion — grows from CENTER outward
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4; radius: 2
                                color: ThemeService.blue
                                x: sensSliderTrack.value >= 0
                                   ? parent.width / 2
                                   : parent.width * sensSliderTrack.ratio
                                width: Math.abs(
                                    parent.width * sensSliderTrack.ratio
                                    - parent.width / 2)
                                Behavior on width { NumberAnimation { duration: 60 } }
                                Behavior on x { NumberAnimation { duration: 60 } }
                            }
                            // Knob
                            Rectangle {
                                width: 14; height: 14; radius: 7
                                y: (parent.height - height) / 2
                                x: Math.max(0,
                                    parent.width * sensSliderTrack.ratio - width / 2)
                                color: ThemeService.fg
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.bg0, 0.4)
                                Behavior on x { NumberAnimation { duration: 60 } }
                            }
                            // Drag / click / wheel area
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                function _setFromX(x) {
                                    const r = Math.max(0, Math.min(1, x / width))
                                    // Map 0..1 → -1.0..+1.0, snap to 0.05
                                    let v = r * 2.0 - 1.0
                                    v = Math.round(v / 0.05) * 0.05
                                    v = Math.max(-1.0, Math.min(1.0, v))
                                    MouseSettingsService.sensitivity = v
                                    MouseSettingsService.apply(true)
                                }
                                onPressed: function(m) { _setFromX(m.x) }
                                onPositionChanged: function(m) {
                                    if (pressed) _setFromX(m.x)
                                }
                                onWheel: function(w) {
                                    const cur = MouseSettingsService.sensitivity
                                    const next = w.angleDelta.y > 0
                                                 ? Math.min(1.0, cur + 0.05)
                                                 : Math.max(-1.0, cur - 0.05)
                                    MouseSettingsService.sensitivity = Math.round(next * 100) / 100
                                    MouseSettingsService.apply(true)
                                    w.accepted = true
                                }
                                // Double-click → reset to 0 (baseline)
                                onDoubleClicked: {
                                    MouseSettingsService.sensitivity = 0.0
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Scroll factor slider (0.1 … 3.0)
                    // v7.0.0-beta.1-hf41: same custom Rectangle slider
                    // design as Sensitivity above. Range is positive-
                    // only (0.1 .. 3.0) with 1.0 as the "baseline" tick.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Scroll speed"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.grey0
                                Layout.fillWidth: true
                            }
                            Text {
                                text: MouseSettingsService.scrollFactor.toFixed(2) + "×"
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                color: ThemeService.blue
                            }
                        }
                        Item {
                            id: scrollSliderTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            readonly property real value: MouseSettingsService.scrollFactor
                            // Map 0.1..3.0 → 0.0..1.0
                            readonly property real ratio:
                                Math.max(0, Math.min(1, (value - 0.1) / (3.0 - 0.1)))
                            // Position of 1.0 baseline along the track (0..1)
                            readonly property real baselineRatio:
                                (1.0 - 0.1) / (3.0 - 0.1)

                            // Track background
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 4; radius: 2
                                color: ThemeService.alpha(ThemeService.fg, 0.15)
                            }
                            // Baseline tick at 1.0×
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * scrollSliderTrack.baselineRatio
                                   - width / 2
                                width: 2; height: 8
                                color: ThemeService.alpha(ThemeService.fg, 0.35)
                                radius: 1
                            }
                            // Filled portion (left → current position)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * scrollSliderTrack.ratio
                                height: 4; radius: 2
                                color: ThemeService.blue
                                Behavior on width { NumberAnimation { duration: 60 } }
                            }
                            // Knob
                            Rectangle {
                                width: 14; height: 14; radius: 7
                                y: (parent.height - height) / 2
                                x: Math.max(0,
                                    parent.width * scrollSliderTrack.ratio - width / 2)
                                color: ThemeService.fg
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.bg0, 0.4)
                                Behavior on x { NumberAnimation { duration: 60 } }
                            }
                            // Drag / click / wheel area
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                function _setFromX(x) {
                                    const r = Math.max(0, Math.min(1, x / width))
                                    let v = 0.1 + r * (3.0 - 0.1)
                                    v = Math.round(v * 10) / 10
                                    v = Math.max(0.1, Math.min(3.0, v))
                                    MouseSettingsService.scrollFactor = v
                                    MouseSettingsService.apply(true)
                                }
                                onPressed: function(m) { _setFromX(m.x) }
                                onPositionChanged: function(m) {
                                    if (pressed) _setFromX(m.x)
                                }
                                onWheel: function(w) {
                                    const cur = MouseSettingsService.scrollFactor
                                    const next = w.angleDelta.y > 0
                                                 ? Math.min(3.0, cur + 0.1)
                                                 : Math.max(0.1, cur - 0.1)
                                    MouseSettingsService.scrollFactor = Math.round(next * 10) / 10
                                    MouseSettingsService.apply(true)
                                    w.accepted = true
                                }
                                // Double-click → reset to 1.0 (baseline)
                                onDoubleClicked: {
                                    MouseSettingsService.scrollFactor = 1.0
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Natural scroll (mouse wheel)
                    // v7.0.0-beta.1-hf43: replaced QQC2 Switch with the
                    // same rounded toggle pill used by Bluetooth/WiFi/
                    // Audio toggles in this same Control Panel. 42×22
                    // pill with sliding 18×18 circular thumb. Green when
                    // active, neutral when off. Visually consistent with
                    // all other on/off controls in the shell.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "Natural scroll"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fg
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 22
                            radius: 11
                            color: MouseSettingsService.naturalScroll
                                   ? ThemeService.alpha(ThemeService.green, 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: ThemeService.fg
                                y: 2
                                x: MouseSettingsService.naturalScroll
                                   ? parent.width - width - 2 : 2
                                Behavior on x {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    MouseSettingsService.naturalScroll = !MouseSettingsService.naturalScroll
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Touchpad natural scroll (separate)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "Touchpad natural scroll"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fg
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 22
                            radius: 11
                            color: MouseSettingsService.touchpadNaturalScroll
                                   ? ThemeService.alpha(ThemeService.green, 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: ThemeService.fg
                                y: 2
                                x: MouseSettingsService.touchpadNaturalScroll
                                   ? parent.width - width - 2 : 2
                                Behavior on x {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    MouseSettingsService.touchpadNaturalScroll = !MouseSettingsService.touchpadNaturalScroll
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Reset button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 7
                        color: resetInputMa.containsMouse
                            ? ThemeService.alpha(ThemeService.fg, 0.14)
                            : ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: "Reset to defaults"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fgDim
                        }

                        MouseArea {
                            id: resetInputMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MouseSettingsService.sensitivity = 0.0
                                MouseSettingsService.scrollFactor = 1.0
                                MouseSettingsService.naturalScroll = false
                                MouseSettingsService.touchpadNaturalScroll = false
                                MouseSettingsService.apply(true)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
