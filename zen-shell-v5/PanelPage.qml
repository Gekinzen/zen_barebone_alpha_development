import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * PanelPage v6 — Complete panel configuration
 *
 * Features:
 * - 3 style modes: Fullwidth / Floating / Island (visual selector)
 * - Border enable + width + color
 * - Background color override (separate from Theme.bg0)
 * - Module layout editor (drag to zones, won't crash when start removed)
 * - Opacity + radius (from Theme.qml)
 */
ScrollView {
    id: root
    clip: true

    readonly property var allModules: [
        "start", "taskbar", "workspaces", "window",
        "music", "sysrow", "tray", "notifications", "clock",
        "weather", "sysmonitor"
    ]

    function modulesFor(zone) {
        return Theme.barLayout[zone] || []
    }

    function addToZone(zone, module) {
        const layout = JSON.parse(JSON.stringify(Theme.barLayout))
        if (!layout[zone]) layout[zone] = []
        if (layout[zone].indexOf(module) === -1) {
            layout[zone].push(module)
            Theme.barLayout = layout
            PanelState.saveState()
        }
    }

    function removeFromZone(zone, module) {
        const layout = JSON.parse(JSON.stringify(Theme.barLayout))
        const idx = (layout[zone] || []).indexOf(module)
        if (idx !== -1) {
            layout[zone].splice(idx, 1)
            Theme.barLayout = layout
            PanelState.saveState()
        }
    }

    function moveModule(zone, module, direction) {
        // direction: -1 = up/left, +1 = down/right
        const layout = JSON.parse(JSON.stringify(Theme.barLayout))
        const list = layout[zone] || []
        const idx = list.indexOf(module)
        if (idx < 0) return
        const newIdx = idx + direction
        if (newIdx < 0 || newIdx >= list.length) return
        // Swap
        const tmp = list[newIdx]
        list[newIdx] = list[idx]
        list[idx] = tmp
        layout[zone] = list
        Theme.barLayout = layout
        PanelState.saveState()
    }

    function moveToCenter() {
        // Quick preset: all useful modules in center
        Theme.barLayout = {
            "left": [],
            "center": ["start", "workspaces", "window", "clock"],
            "right": []
        }
        PanelState.saveState()
    }

    function resetDefaults() {
        Theme.barLayout = {
            "left": ["start", "taskbar"],
            "center": ["workspaces", "window"],
            "right": ["music", "sysrow", "tray", "notifications", "clock"]
        }
        Theme.barOpacity = 0.50
        Theme.barRadius = 16
        Theme.styleMode = "round"
        PanelState.resetDefaults()
    }

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Panel"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Layout, style, border, and colors for the bottom bar"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        ControlCenterBanner {
            feature: "Waybar Module Manager"
            description: "Drag-drop modules, drawer config, theme sync"
        }

        // ═══════════════════════════════════════════════════════
        // v6.11: BAR DISPLAY TARGET
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Display Target"
            subtitle: "Which monitor(s) show the bar"

            SettingRow {
                label: "Show Bar On"
                description: "All monitors, primary only, or a specific display"

                ComboBox {
                    id: displayTargetCombo
                    width: 260

                    property var monitorNames: {
                        const names = ["All Monitors", "Primary Monitor"]
                        for (let i = 0; i < Quickshell.screens.length; i++) {
                            names.push(Quickshell.screens[i].name)
                        }
                        return names
                    }

                    model: monitorNames

                    currentIndex: {
                        if (PanelState.barTargetDisplay === "all") return 0
                        if (PanelState.barTargetDisplay === "primary") return 1
                        for (let i = 0; i < Quickshell.screens.length; i++) {
                            if (Quickshell.screens[i].name === PanelState.barTargetDisplay) return i + 2
                        }
                        return 0
                    }

                    onActivated: {
                        if (currentIndex === 0) PanelState.barTargetDisplay = "all"
                        else if (currentIndex === 1) PanelState.barTargetDisplay = "primary"
                        else PanelState.barTargetDisplay = Quickshell.screens[currentIndex - 2].name
                        PanelState.saveState()
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // PANEL STYLE (3 modes)
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Panel Style"
            subtitle: "Choose how the bar is laid out on your screen"

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Fullwidth preview
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    radius: 10
                    color: PanelState.panelMode === "fullwidth"
                           ? ThemeService.alpha(ThemeService.blue, 0.18)
                           : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 2
                    border.color: PanelState.panelMode === "fullwidth" ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.12)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Mini preview: bar spans full width at bottom
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 10
                                radius: 2
                                color: ThemeService.alpha(ThemeService.blue, 0.7)
                            }
                        }

                        Text {
                            text: "Full-width"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PanelState.setMode("fullwidth")
                    }
                }

                // Floating preview
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    radius: 10
                    color: PanelState.panelMode === "floating"
                           ? ThemeService.alpha(ThemeService.blue, 0.18)
                           : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 2
                    border.color: PanelState.panelMode === "floating" ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.12)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottomMargin: 4
                                height: 10
                                radius: 4
                                color: ThemeService.alpha(ThemeService.blue, 0.7)
                            }
                        }

                        Text {
                            text: "Floating"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PanelState.setMode("floating")
                    }
                }

                // Island preview
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    radius: 10
                    color: PanelState.panelMode === "island"
                           ? ThemeService.alpha(ThemeService.blue, 0.18)
                           : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 2
                    border.color: PanelState.panelMode === "island" ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.12)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 4
                                width: parent.width * 0.4
                                height: 10
                                radius: 5
                                color: ThemeService.alpha(ThemeService.blue, 0.7)
                            }
                        }

                        Text {
                            text: "Island"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PanelState.setMode("island")
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // BORDER
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Border"

            SettingRow {
                label: "Enable Border"
                Switch {
                    checked: PanelState.borderEnabled
                    onToggled: PanelState.setBorder(checked, PanelState.borderWidth, PanelState.borderColor)
                }
            }

            SettingRow {
                label: "Border Width"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 0; to: 5; stepSize: 1
                        value: PanelState.borderWidth
                        enabled: PanelState.borderEnabled
                        onValueChanged: PanelState.setBorder(PanelState.borderEnabled, Math.round(value), PanelState.borderColor)
                    }
                    Text {
                        text: PanelState.borderWidth + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                label: "Border Color"
                description: "Pick from theme accents"

                RowLayout {
                    spacing: 4
                    Repeater {
                        model: [
                            { c: ThemeService.bg3, name: "bg3" },
                            { c: ThemeService.blue, name: "blue" },
                            { c: ThemeService.purple, name: "purple" },
                            { c: ThemeService.green, name: "green" },
                            { c: ThemeService.red, name: "red" },
                            { c: ThemeService.yellow, name: "yellow" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            color: modelData.c
                            border.width: Qt.colorEqual(PanelState.borderColor, modelData.c) ? 3 : 1
                            border.color: Qt.colorEqual(PanelState.borderColor, modelData.c) ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.3)

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PanelState.setBorder(PanelState.borderEnabled, PanelState.borderWidth, modelData.c)
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // BACKGROUND & STYLE
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Background & Shape"

            SettingRow {
                label: "Bar Height"
                description: "Height in pixels (default 60)"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 36; to: 80; stepSize: 2
                        value: PanelState.barHeight
                        onValueChanged: {
                            PanelState.barHeight = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text { text: PanelState.barHeight + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Module Shape"
                description: "Round (circular) or pill (elongated)"

                ComboBox {
                    width: 140
                    model: ["Round", "Pill"]
                    currentIndex: Theme.styleMode === "round" ? 0 : 1
                    onActivated: { Theme.styleMode = (currentIndex === 0) ? "round" : "pill"; PanelState.saveState() }
                }
            }

            SettingRow {
                label: "Bar Opacity"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 0.2; to: 1.0; stepSize: 0.05
                        value: Theme.barOpacity
                        onValueChanged: { Theme.barOpacity = value; PanelState.saveState() }
                    }
                    Text {
                        text: Math.round(Theme.barOpacity * 100) + "%"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                label: "Bar Corner Radius"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 0; to: 30; stepSize: 1
                        value: Theme.barRadius
                        onValueChanged: { Theme.barRadius = Math.round(value); PanelState.saveState() }
                    }
                    Text {
                        text: Theme.barRadius + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // v6.11: START BUTTON & WORKSPACE SIZES
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Start Button & Workspaces"
            subtitle: "Adjust icon and workspace dot sizes"

            SettingRow {
                label: "Start Button Icon"
                description: "Size of the Arch logo icon (default 26)"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 18; to: 42; stepSize: 2
                        value: PanelState.startButtonIconSize
                        onValueChanged: {
                            PanelState.startButtonIconSize = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        text: PanelState.startButtonIconSize + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                label: "Workspace Dot (Active)"
                description: "Size of the active workspace indicator (default 32)"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 20; to: 48; stepSize: 2
                        value: PanelState.workspaceDotActive
                        onValueChanged: {
                            PanelState.workspaceDotActive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        text: PanelState.workspaceDotActive + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                label: "Workspace Dot (Inactive)"
                description: "Size of inactive workspace dots (default 26)"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 16; to: 40; stepSize: 2
                        value: PanelState.workspaceDotInactive
                        onValueChanged: {
                            PanelState.workspaceDotInactive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        text: PanelState.workspaceDotInactive + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                label: "Workspace Font (Active)"
                description: "Font size for active workspace number (default 13)"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 8; to: 22; stepSize: 1
                        value: PanelState.workspaceFontActive
                        onValueChanged: {
                            PanelState.workspaceFontActive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        text: PanelState.workspaceFontActive + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                label: "Workspace Font (Inactive)"
                description: "Font size for inactive workspace numbers (default 11)"
                Row {
                    spacing: 8
                    Slider {
                        width: 200
                        from: 6; to: 18; stepSize: 1
                        value: PanelState.workspaceFontInactive
                        onValueChanged: {
                            PanelState.workspaceFontInactive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        text: PanelState.workspaceFontInactive + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // MODULE LAYOUT
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Module Layout"
            subtitle: "Drag modules between zones. Empty zones are fine (won't crash)."

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    text: "All → Center"
                    onClicked: root.moveToCenter()
                }
                Button {
                    text: "Reset Layout"
                    onClicked: root.resetDefaults()
                }
                Item { Layout.fillWidth: true }
            }

            Repeater {
                model: [
                    { id: "left",   label: "Left Zone" },
                    { id: "center", label: "Center Zone" },
                    { id: "right",  label: "Right Zone" }
                ]
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: ThemeService.grey0
                    }

                    // Module chips
                    Flow {
                        id: chipFlow
                        Layout.fillWidth: true
                        spacing: 6
                        property string zoneId: modelData.id

                        Repeater {
                            model: root.modulesFor(chipFlow.zoneId)
                            delegate: Rectangle {
                                required property string modelData

                                radius: 14
                                color: ThemeService.alpha(ThemeService.blue, 0.15)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                                height: 28
                                width: chipRow.implicitWidth + 16

                                Row {
                                    id: chipRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    spacing: 4

                                    // Move left
                                    Text {
                                        text: "◀"
                                        font.pixelSize: 9
                                        color: moveLeftArea.containsMouse ? ThemeService.blue : ThemeService.grey1
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea {
                                            id: moveLeftArea
                                            anchors.fill: parent
                                            anchors.margins: -3
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.moveModule(chipFlow.zoneId, modelData, -1)
                                        }
                                    }

                                    Text {
                                        text: modelData
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: ThemeService.fg
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Move right
                                    Text {
                                        text: "▶"
                                        font.pixelSize: 9
                                        color: moveRightArea.containsMouse ? ThemeService.blue : ThemeService.grey1
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea {
                                            id: moveRightArea
                                            anchors.fill: parent
                                            anchors.margins: -3
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.moveModule(chipFlow.zoneId, modelData, 1)
                                        }
                                    }

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: xHover.containsMouse ? ThemeService.alpha(ThemeService.red, 0.3) : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00d"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            color: xHover.containsMouse ? ThemeService.red : ThemeService.grey0
                                        }

                                        MouseArea {
                                            id: xHover
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.removeFromZone(chipFlow.zoneId, modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Add dropdown for this zone
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ComboBox {
                            id: addCombo
                            Layout.preferredWidth: 180
                            property var availableForZone: {
                                return root.allModules.filter(m => root.modulesFor(modelData.id).indexOf(m) === -1)
                            }
                            model: availableForZone
                        }

                        Button {
                            text: "+ Add"
                            enabled: addCombo.count > 0
                            onClicked: {
                                if (addCombo.currentText) {
                                    root.addToZone(modelData.id, addCombo.currentText)
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        PageFooter {
            description: "Panel config saves to panel-state.json"
            onResetRequested: root.resetDefaults()
        }

        Item { Layout.preferredHeight: 24 }
    }
}
