import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

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

    // v6.16.3.5.2: added "battery" and "powerbadge" so they're
    // pickable from the Module Layout zone dropdowns. Before this
    // they were only reachable by hand-editing bar-layout.json or
    // via the PowerBadge toggle in Bar Modules settings. Battery was
    // missing from the selectable set since v6.16.0 shipped.
    readonly property var allModules: [
        "start", "taskbar", "workspaces", "window",
        "music", "sysrow", "tray", "battery", "powerbadge",
        "notifications", "clock",
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

                ZenComboBox {
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
                HMSwitch {
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

                ZenComboBox {
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

            // ═══════════════════════════════════════════════════════
            // v6.16.3.5: Start Button Logo picker
            // ─────────────────────────────────────────────────────────
            // Three modes:
            //   auto    → auto-detect from /etc/os-release
            //   builtin → pick from the bundled logo grid
            //   custom  → browse a user image file
            //
            // Bundled logos live under ~/.local/share/quickshell/
            // zen-shell/logos/<id>.svg, installed by install.sh from
            // the tree's zen-shell-v5/assets/logos/. Adding a new one:
            // drop the SVG in the assets dir AND append an entry to
            // PanelState.builtinLogos. No other code changes needed.
            // ═══════════════════════════════════════════════════════
            SettingRow {
                label: "Start Button Logo"
                description: "Auto-detect your distro, pick from the built-in set, or use a custom image"
                Row {
                    spacing: 8
                    ZenComboBox {
                        id: logoModeCombo
                        width: 180
                        model: ["Auto (detect distro)", "Built-in logo", "Custom image"]
                        readonly property var ids: ["auto", "builtin", "custom"]
                        currentIndex: Math.max(0, ids.indexOf(PanelState.startButtonLogoMode))
                        onActivated: {
                            PanelState.startButtonLogoMode = ids[currentIndex]
                            PanelState.saveState()
                        }
                    }
                    // Live preview of the currently-effective logo
                    Rectangle {
                        width: 36; height: 36; radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.12)

                        Image {
                            anchors.centerIn: parent
                            width: 28; height: 28
                            readonly property string _r: PanelState.resolveStartButtonLogo()
                            source: _r !== ""
                                ? _r
                                : Quickshell.iconPath("distributor-logo-archlinux")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            sourceSize: Qt.size(56, 56)
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PanelState.startButtonLogoMode === "auto"
                        text: {
                            const tag = UserProfileService
                                ? String(UserProfileService.osLogo || "").toLowerCase()
                                : ""
                            if (!tag) return "detecting…"
                            for (let i = 0; i < PanelState.builtinLogos.length; i++) {
                                const e = PanelState.builtinLogos[i]
                                for (let j = 0; j < e.osReleaseIds.length; j++) {
                                    if (tag.indexOf(e.osReleaseIds[j]) >= 0) {
                                        return "matched: " + e.label
                                    }
                                }
                            }
                            return "no match (using system icon)"
                        }
                        color: ThemeService.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            // ─────────────────────────────────────────────────────────
            // BUILT-IN LOGO GRID (visible when mode = builtin)
            // ─────────────────────────────────────────────────────────
            // v6.16.3.5.1 FIX: was wrapped in SettingRow which has a
            // hardcoded implicitHeight of 48px — the grid (2 rows × 84px
            // = ~180px) overflowed its bounds and visually collided with
            // the next row ("Workspace Dot (Active)"). Now the whole
            // block is a standalone ColumnLayout that auto-sizes from
            // its children, so the parent SettingsSection.contentLayout
            // positions subsequent rows at the correct Y.
            //
            // Layout.leftMargin: 16 matches SettingRow's internal left
            // padding so header + grid visually align with the rest of
            // the section's rows.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                visible: PanelState.startButtonLogoMode === "builtin"
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    spacing: 2
                    Text {
                        text: "Pick a built-in"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }
                    Text {
                        text: "Bundled Arch, CachyOS, EndeavourOS, Fedora, Ubuntu, NixOS, generic Linux"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                Grid {
                    Layout.leftMargin: 16
                    columns: 4
                    rowSpacing: 10
                    columnSpacing: 10
                    Repeater {
                        model: PanelState.builtinLogos
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            width: 80; height: 84; radius: 10
                            readonly property bool selected:
                                PanelState.startButtonLogoBuiltinId === tile.modelData.id
                            color: tile.selected
                                ? ThemeService.alpha(ThemeService.blue, 0.18)
                                : (tileMa.containsMouse
                                    ? ThemeService.alpha(ThemeService.fg, 0.08)
                                    : ThemeService.alpha(ThemeService.fg, 0.04))
                            border.width: tile.selected ? 2 : 1
                            border.color: tile.selected
                                ? ThemeService.blue
                                : ThemeService.alpha(ThemeService.fg, 0.12)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 40; height: 40
                                    source: "file://" + PanelState._logosDir + "/" + tile.modelData.id + ".svg"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    sourceSize: Qt.size(80, 80)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tile.modelData.label
                                    color: ThemeService.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    width: 76
                                }
                            }

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    PanelState.startButtonLogoBuiltinId = tile.modelData.id
                                    PanelState.saveState()
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────────
            // CUSTOM IMAGE PATH (visible when mode = custom) — existing
            // v6.16.2 behavior preserved byte-identical below.
            // ─────────────────────────────────────────────────────────
            SettingRow {
                label: "Logo Image Path"
                description: "Absolute path to a PNG, SVG, or JPG file — auto-fits the button"
                visible: PanelState.startButtonLogoMode === "custom"
                Row {
                    spacing: 8
                    Rectangle {
                        width: 320
                        height: 32
                        radius: 6
                        color: ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                        TextInput {
                            id: logoPathInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            text: PanelState.startButtonLogoPath
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            selectByMouse: true
                            clip: true
                            onEditingFinished: {
                                PanelState.startButtonLogoPath = text
                                PanelState.saveState()
                            }
                        }
                    }
                    Rectangle {
                        width: 80; height: 32; radius: 6
                        color: browseMa.containsMouse
                            ? ThemeService.alpha(ThemeService.blue, 0.3)
                            : ThemeService.alpha(ThemeService.blue, 0.18)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.blue, 0.5)
                        Text {
                            anchors.centerIn: parent
                            text: "Browse…"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: browseMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: logoPicker.running = true
                        }
                    }
                }
            }

            // zenity file picker for logo selection (writes path to a tmp
            // file; we poll it via Process stdout)
            Process {
                id: logoPicker
                running: false
                command: ["bash", "-c",
                    "zenity --file-selection --title='Select Start Button Logo' " +
                    "--file-filter='Images | *.png *.svg *.jpg *.jpeg *.webp' " +
                    "--file-filter='All | *'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const p = text.trim()
                        if (p) {
                            PanelState.startButtonLogoPath = p
                            PanelState.saveState()
                        }
                    }
                }
            }

            SettingRow {
                label: "Theme Tint"
                description: "Blend with theme foreground (helps monochrome SVG logos)"
                visible: PanelState.startButtonLogoMode === "custom"
                HMSwitch {
                    checked: PanelState.startButtonLogoTint
                    onToggled: {
                        PanelState.startButtonLogoTint = !PanelState.startButtonLogoTint
                        PanelState.saveState()
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

                        ZenComboBox {
                            id: addCombo
                            Layout.preferredWidth: 180
                            // v6.16.3.5.2: dedup across ALL zones.
                            // Before: only filtered out modules in THIS zone,
                            // so a module already assigned to e.g. "center"
                            // still appeared as a pickable option in "left"
                            // and "right". Clicking Add would succeed but
                            // leave the module assigned to both zones —
                            // unintuitive and surfaces bar ambiguity.
                            // Now: a module is shown in at most ONE zone's
                            // dropdown — the zones it's NOT assigned to hide
                            // it entirely. User removes it from its current
                            // zone (× chip button) before it becomes pickable
                            // again anywhere. "kapag nakalagay na sa bar,
                            // hindi na mareselect yun mga naka assign na
                            // need muna alisin para ma gamit ulit."
                            property var availableForZone: {
                                const assigned = [].concat(
                                    root.modulesFor("left"),
                                    root.modulesFor("center"),
                                    root.modulesFor("right")
                                )
                                return root.allModules.filter(m => assigned.indexOf(m) === -1)
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
