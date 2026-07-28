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
    //
    // v7.0.0-beta.1-hf42: registered the 5 hf39 productivity modules
    // + "workflow" (which was missing despite being in the default
    // barLayout). Without this they were invisible to the Settings
    // UI even though Bar.qml's switch knew about them. Now all
    // 18 modules are pickable.
    readonly property var allModules: [
        "start", "taskbar", "workspaces", "window",
        "music", "sysrow", "tray", "battery", "powerbadge",
        "notifications", "clock",
        "weather", "sysmonitor",
        "clipboard",          // v7.0.0-alpha.6
        "workflow",           // v7.0.0-alpha.13 (was missing from catalog!)
        // v7.0.0-beta.1-hf39 — productivity features
        "quicknotes",
        "focusspaces",
        "networkpulse",
        "smartdim",
        "titletranslator"
    ]

    // v7.0.0-beta.1-hf42: Display labels + descriptions for each module
    // so the +Add dropdown can show friendly names instead of raw IDs.
    // Looked up by module id; falls back to capitalizing the id if
    // not registered here.
    readonly property var moduleMetadata: ({
        "start":          { label: "Start menu",       icon: "\uf015" },
        "taskbar":        { label: "Taskbar",          icon: "\uf03a" },
        "workspaces":     { label: "Workspaces",       icon: "\uf245" },
        "window":         { label: "Active window",    icon: "\uf2d2" },
        "music":          { label: "Music player",     icon: "\uf001" },
        "sysrow":         { label: "System tray row",  icon: "\uf2db" },
        "tray":           { label: "System tray",      icon: "\uf2db" },
        "battery":        { label: "Battery",          icon: "\uf240" },
        "powerbadge":     { label: "Power profile",    icon: "\uf0e7" },
        "notifications":  { label: "Notifications",    icon: "\uf0f3" },
        "clock":          { label: "Clock + calendar", icon: "\uf017" },
        "weather":        { label: "Weather",          icon: "\uf0c2" },
        "sysmonitor":     { label: "CPU/RAM monitor",  icon: "\uf080" },
        "clipboard":      { label: "Clipboard",        icon: "\uf0ea" },
        "workflow":       { label: "Workflow profile", icon: "\uf0c0" },
        // hf39 productivity modules
        "quicknotes":      { label: "Quick Notes",        icon: "\uf249" },
        "focusspaces":     { label: "Focus Spaces",       icon: "\uf2bb" },
        "networkpulse":    { label: "Network Pulse",      icon: "\uf0e8" },
        "smartdim":        { label: "Smart Dim",          icon: "\uf185" },
        "titletranslator": { label: "Title Translator",   icon: "\uf1ab" }
    })

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
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Panel"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Layout, style, position, border, and colors for the bar"
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
        // v6.16.4.12: PANEL POSITION
        // v6.16.4.12.7.1: Extended to 4 options (Top/Bottom/Left/Right)
        // for upcoming vertical-bar support. In this drop the BAR
        // ITSELF still renders horizontally regardless — what changes
        // is popup positioning. Selecting Left/Right today applies the
        // 4-direction popup logic but won't yet rotate the bar's
        // RowLayout to a ColumnLayout (that's a separate larger drop).
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Panel Position"
            subtitle: "Where the bar sits on your screen. Popups always grow AWAY from the bar."

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    // v7.0.0-beta.1-hf90: Left/Right re-enabled — vertical
                    // bar (Tategaki) Phase 1 renders a real side bar now.
                    model: [
                        { pos: "top",    icon: "\uf062", label: "Top",    orientation: "h" },
                        { pos: "bottom", icon: "\uf063", label: "Bottom", orientation: "h" },
                        { pos: "left",   icon: "\uf060", label: "Left",   orientation: "v" },
                        { pos: "right",  icon: "\uf061", label: "Right",  orientation: "v" }
                    ]
                    delegate: Rectangle {
                        id: posCard
                        required property var modelData
                        readonly property bool isSelected: PanelState.panelPosition === modelData.pos
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        radius: 10
                        color: isSelected
                               ? ThemeService.alpha(ThemeService.blue, 0.18)
                               : LookService.surfaceColor(ThemeService.bg2, 0.5)
                        border.width: 2
                        border.color: isSelected
                                      ? ThemeService.blue
                                      : ThemeService.alpha(ThemeService.fg, 0.12)

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            // Mini preview — orientation-aware
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 60; height: 40; radius: 4
                                color: ThemeService.alpha(ThemeService.fg, 0.06)
                                border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.1)

                                // Bar mini-rectangle. Width/height/x/y
                                // computed per-position so the preview
                                // visually matches the option label.
                                Rectangle {
                                    readonly property bool horiz: posCard.modelData.orientation === "h"
                                    width: horiz ? parent.width - 4 : 6
                                    height: horiz ? 6 : parent.height - 4
                                    radius: 2
                                    x: {
                                        if (posCard.modelData.pos === "left")  return 2
                                        if (posCard.modelData.pos === "right") return parent.width - 8
                                        return 2
                                    }
                                    y: {
                                        if (posCard.modelData.pos === "top")    return 2
                                        if (posCard.modelData.pos === "bottom") return parent.height - 8
                                        return 2
                                    }
                                    color: posCard.isSelected
                                           ? ThemeService.blue
                                           : ThemeService.alpha(ThemeService.fg, 0.2)

                                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.alignment: Qt.AlignHCenter
                                text: posCard.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: posCard.isSelected
                                       ? ThemeService.blue : ThemeService.fg
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                PanelState.panelPosition = posCard.modelData.pos
                                PanelState.saveState()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // v6.11: BAR DISPLAY TARGET
        // ═══════════════════════════════════════════════════════
        // ═══════════════════════════════════════════════════════
        // v8.0.0-alpha-hf117 — floating-window placement
        // Visual 3x3 grid, same idiom as NotificationPage's position
        // selector. Nine anchors + "remember last drag".
        // ═══════════════════════════════════════════════════════
        SettingsSection {
            title: "Window Placement"
            subtitle: "Where the Control Center and Settings windows open on the focused monitor"

            // ── reusable picker, instantiated twice ──
            component PlacementGrid: Item {
                id: pg
                property string mode: "center"
                // v8.0.0-alpha-hf123: when the window remembers its dragged
                // position, the anchor is inert. Say so, don't just leave nine
                // cells looking unselected.
                property bool inert: false
                signal picked(string id)

                Layout.fillWidth: true
                Layout.preferredHeight: 250
                enabled: !pg.inert
                opacity: pg.inert ? 0.4 : 1
                Behavior on opacity { NumberAnimation { duration: 140 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        width: 300; height: 168; radius: 8
                        color: LookService.surfaceColor(ThemeService.bg2, 0.6)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.1)

                        Grid {
                            anchors.fill: parent
                            anchors.margins: 8
                            columns: 3; rows: 3; spacing: 6

                            Repeater {
                                model: [
                                    { id: "top-left",      glyph: "\u2196" },
                                    { id: "top-center",    glyph: "\u2191" },
                                    { id: "top-right",     glyph: "\u2197" },
                                    { id: "center-left",   glyph: "\u2190" },
                                    { id: "center",        glyph: "\u2022" },
                                    { id: "center-right",  glyph: "\u2192" },
                                    { id: "bottom-left",   glyph: "\u2199" },
                                    { id: "bottom-center", glyph: "\u2193" },
                                    { id: "bottom-right",  glyph: "\u2198" }
                                ]
                                Rectangle {
                                    required property var modelData
                                    readonly property bool selected: pg.mode === modelData.id
                                    width: (300 - 16 - 12) / 3
                                    height: (168 - 16 - 12) / 3
                                    radius: 6
                                    color: selected ? ThemeService.alpha(ThemeService.blue, 0.25)
                                          : (cellMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08)
                                                                     : "transparent")
                                    border.width: selected ? 2 : 0
                                    border.color: ThemeService.blue

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.glyph
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 17
                                            color: selected ? ThemeService.blue : ThemeService.grey1
                                        }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.id
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            color: selected ? ThemeService.fg : ThemeService.grey2
                                        }
                                    }
                                    MouseArea {
                                        id: cellMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: pg.picked(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pg.inert ? "Anchor ignored while the window remembers its position"
                                       : "Monitor"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.grey2
                    }
                }
            }

            // ── Control Center ──
            SettingRow {
                label: "Control Center"
                description: "Where SUPER+C opens the Zen Control Center"
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: PanelState.dashRememberDrag
                          ? "reopens where you dragged it"
                          : ZenWindowPlacement.labelFor(PanelState.dashPlacement)
                    font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0
                }
            }
            SettingRow {
                label: "Remember last position"
                description: "Reopen wherever you dragged it. The anchor below is ignored while this is on."
                HMSwitch {
                    checked: PanelState.dashRememberDrag
                    onToggled: { PanelState.dashRememberDrag = !PanelState.dashRememberDrag; PanelState.saveState() }
                }
            }
            PlacementGrid {
                mode: PanelState.dashPlacement
                inert: PanelState.dashRememberDrag
                onPicked: (id) => { PanelState.dashPlacement = id; PanelState.saveState() }
            }
            SettingRow {
                visible: !PanelState.dashRememberDrag && PanelState.dashPlacement !== "center"
                label: "Edge margin"
                description: "Gap from the screen edge"
                NumericStepper {
                    value: PanelState.dashMargin
                    from: 0; to: 200; stepSize: 4; suffix: "px"
                    onValueEdited: (v) => { PanelState.dashMargin = v; PanelState.saveState() }
                }
            }

            // ── Settings window ──
            SettingRow {
                label: "Settings window"
                description: "Same nine anchors, tracked separately"
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: PanelState.settingsRememberDrag
                          ? "reopens where you dragged it"
                          : ZenWindowPlacement.labelFor(PanelState.settingsPlacement)
                    font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0
                }
            }
            SettingRow {
                label: "Remember last position"
                description: "Applies to the Settings window only"
                HMSwitch {
                    checked: PanelState.settingsRememberDrag
                    onToggled: { PanelState.settingsRememberDrag = !PanelState.settingsRememberDrag; PanelState.saveState() }
                }
            }
            PlacementGrid {
                mode: PanelState.settingsPlacement
                inert: PanelState.settingsRememberDrag
                onPicked: (id) => { PanelState.settingsPlacement = id; PanelState.saveState() }
            }
            SettingRow {
                visible: !PanelState.settingsRememberDrag && PanelState.settingsPlacement !== "center"
                label: "Edge margin"
                description: "Gap from the screen edge"
                NumericStepper {
                    value: PanelState.settingsMargin
                    from: 0; to: 200; stepSize: 4; suffix: "px"
                    onValueEdited: (v) => { PanelState.settingsMargin = v; PanelState.saveState() }
                }
            }

            // ── Entrance ──
            SettingRow {
                label: "Slide in from the edge"
                description: "Notification-style entrance. The window flies in from whichever edge it's anchored to; a centered window just rises."
                HMSwitch {
                    checked: PanelState.windowSlideIn
                    onToggled: { PanelState.windowSlideIn = !PanelState.windowSlideIn; PanelState.saveState() }
                }
            }
        }

        SettingsSection {
            title: "Display Target"
            subtitle: "Which monitor(s) show the bar"

            SettingRow {
                label: "Show Bar On"
                description: "All monitors, primary only, or a specific display"

                ZenDropdown {
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
                           : LookService.surfaceColor(ThemeService.bg2, 0.5)
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
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
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
                           : LookService.surfaceColor(ThemeService.bg2, 0.5)
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
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
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
                           : LookService.surfaceColor(ThemeService.bg2, 0.5)
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
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
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
                    ZenSlider {
                        width: 200
                        from: 0; to: 5; stepSize: 1
                        value: PanelState.borderWidth
                        enabled: PanelState.borderEnabled
                        onValueChanged: PanelState.setBorder(PanelState.borderEnabled, Math.round(value), PanelState.borderColor)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                    // v8: manual border color (custom hex) — additive; the
                    // theme-accent swatches below still work "as is".
                    ColorSwatch {
                        value: PanelState.borderColor
                        onValueEdited: hex => PanelState.setBorder(PanelState.borderEnabled, PanelState.borderWidth, "#" + hex.replace(/^#/, "").substring(0, 6))
                    }
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

            // v8: custom bar background color (glass, like the dock) —
            // manual color + opacity, separate from the theme.
            SettingRow {
                label: "Custom background"
                description: "Use a manual background color instead of the theme"
                HMSwitch {
                    checked: PanelState.bgOverrideEnabled
                    onToggled: PanelState.setBackground(checked, PanelState.bgOverrideColor, PanelState.bgOverrideOpacity)
                }
            }
            SettingRow {
                visible: PanelState.bgOverrideEnabled
                label: "Background color"
                ColorSwatch {
                    value: PanelState.bgOverrideColor
                    onValueEdited: hex => PanelState.setBackground(PanelState.bgOverrideEnabled, "#" + hex.replace(/^#/, "").substring(0, 6), PanelState.bgOverrideOpacity)
                }
            }
            SettingRow {
                visible: PanelState.bgOverrideEnabled
                label: "Background opacity"
                Row {
                    spacing: 8
                    ZenSlider {
                        width: 200; from: 0.0; to: 1.0; stepSize: 0.05
                        value: PanelState.bgOverrideOpacity
                        onValueChanged: PanelState.setBackground(PanelState.bgOverrideEnabled, PanelState.bgOverrideColor, value)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: PanelState.bgOverrideOpacity.toFixed(2); color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // v7.0.0-beta.1-hf83: auto-height opt-in. When on, the bar
            // hugs its tallest module instead of the fixed slider value.
            SettingRow {
                label: "Auto height"
                description: "Bar grows/shrinks to fit its icons automatically"
                HMSwitch {
                    checked: PanelState.barAutoHeight
                    onToggled: {
                        PanelState.barAutoHeight = checked
                        PanelState.saveState()
                    }
                }
            }

            SettingRow {
                visible: PanelState.barAutoHeight
                label: "Auto height padding"
                description: "Breathing room above + below the icons"
                Row {
                    spacing: 8
                    ZenSlider {
                        width: 200; from: 0; to: 24; stepSize: 1
                        value: PanelState.barAutoHeightPadding
                        onValueChanged: {
                            PanelState.barAutoHeightPadding = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: PanelState.barAutoHeightPadding + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // v7.0.0-beta.1-hf84: scale module content to the bar height.
            SettingRow {
                label: "Fit contents to bar"
                description: "Icons + text scale with bar height (taller bar = bigger icons)"
                HMSwitch {
                    checked: PanelState.barFitContents
                    onToggled: {
                        PanelState.barFitContents = checked
                        PanelState.saveState()
                    }
                }
            }

            // v7.0.0-beta.1-hf85: vertical breathing room around modules.
            SettingRow {
                label: "Content padding (top/bottom)"
                description: "Keeps modules centered with an even gap above + below"
                Row {
                    spacing: 8
                    ZenSlider {
                        width: 200; from: 0; to: 64; stepSize: 1
                        value: PanelState.barContentPaddingV
                        onValueChanged: {
                            PanelState.barContentPaddingV = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: PanelState.barContentPaddingV + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // v7.0.0-beta.1-hf86: manual module size multiplier.
            SettingRow {
                label: "Module size"
                description: "Scale all bar icons + text (works with or without Fit-contents)"
                Row {
                    spacing: 8
                    ZenSlider {
                        width: 200; from: 0.6; to: 2.0; stepSize: 0.05
                        value: PanelState.barModuleScale
                        onValueChanged: {
                            PanelState.barModuleScale = Math.round(value * 100) / 100
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: Math.round(PanelState.barModuleScale * 100) + "%"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // v7.0.0-beta.1-hf88: where the quick-settings popup anchors.
            SettingRow {
                label: "Quick Settings position"
                description: "Where the Control Center popup opens (until you drag it)"
                ZenDropdown {
                    width: 140
                    model: ["center", "top", "bottom"]
                    currentIndex: {
                        const i = model.indexOf(PanelState.controlPanelPosition)
                        return i >= 0 ? i : 0
                    }
                    onActivated: {
                        PanelState.controlPanelPosition = model[currentIndex]
                        PanelState.saveState()
                    }
                }
            }

            // v7.0.0-beta.1-hf99j: attached (Caelestia-style) mode.
            SettingRow {
                label: "Attach to bar"
                description: "Quick Settings hugs the bar edge (flush, squared corner) instead of floating"
                HMSwitch {
                    checked: PanelState.controlPanelAttached
                    onToggled: {
                        PanelState.controlPanelAttached = checked
                        PanelState.saveState()
                    }
                }
            }

            SettingRow {
                label: "Bar Height"
                description: PanelState.barAutoHeight
                    ? "Ignored while Auto height is on"
                    : "Height in pixels (default 60)"
                Row {
                    spacing: 8
                    enabled: !PanelState.barAutoHeight
                    opacity: PanelState.barAutoHeight ? 0.4 : 1.0
                    ZenSlider {
                        width: 200; from: 36; to: 80; stepSize: 2
                        value: PanelState.barHeight
                        onValueChanged: {
                            PanelState.barHeight = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: PanelState.barHeight + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Taskbar width cap"
                description: "How wide the taskbar may grow before < > scroll arrows appear (default 440)"
                Row {
                    spacing: 8
                    ZenSlider {
                        width: 200; from: 240; to: 900; stepSize: 20
                        value: PanelState.taskbarMaxWidth
                        onValueChanged: {
                            PanelState.taskbarMaxWidth = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: PanelState.taskbarMaxWidth + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Module Shape"
                description: "Round (circular) or pill (elongated)"

                ZenDropdown {
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
                    ZenSlider {
                        width: 200
                        from: 0.2; to: 1.0; stepSize: 0.05
                        value: Theme.barOpacity
                        onValueChanged: { Theme.barOpacity = value; PanelState.saveState() }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                    ZenSlider {
                        width: 200
                        from: 0; to: 30; stepSize: 1
                        value: Theme.barRadius
                        onValueChanged: { Theme.barRadius = Math.round(value); PanelState.saveState() }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                    ZenSlider {
                        width: 200
                        from: 18; to: 42; stepSize: 2
                        value: PanelState.startButtonIconSize
                        onValueChanged: {
                            PanelState.startButtonIconSize = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: PanelState.startButtonIconSize + "px"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ═══════════════════════════════════════════════════════
            // v6.16.4.12.7 (Tachiagari) — Start Button Border tint
            //
            // Toggle that lets the start button adopt the panel's
            // borderColor for its idle border (instead of the muted
            // Theme.bg1 default). Hover state still flips to blue
            // accent — that's a deliberately separate concern (click
            // affordance must always be obvious).
            //
            // Independent of `borderEnabled` above so a user can:
            //   - Have NO panel border but a colored start button rim
            //   - Have a panel border + matching start button rim
            //   - Have a panel border + plain start button (default)
            //
            // Width slider goes 0–4: 0 to hide the rim entirely (e.g.
            // pure floating logo look), 1 default (matches old hard-
            // coded value), 2–4 for a chunkier outline.
            // ═══════════════════════════════════════════════════════
            SettingRow {
                label: "Tint Start Button Border"
                description: "Use the panel's Border Color for the start button rim too. "
                             + "Independent of the panel border toggle."
                Row {
                    spacing: 10
                    HMSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: PanelState.startButtonUseBorderColor
                        onToggled: {
                            PanelState.startButtonUseBorderColor = checked
                            PanelState.saveState()
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 11
                        color: PanelState.startButtonUseBorderColor
                               ? PanelState.borderColor
                               : ThemeService.bg1
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.verticalCenter: parent.verticalCenter
                        text: PanelState.startButtonUseBorderColor
                              ? ("→ " + PanelState.borderColor)
                              : "default (theme bg1)"
                        color: ThemeService.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            SettingRow {
                label: "Start Button Border Width"
                description: "0 = no border, 1 = default. Affects the start button rim only."
                Row {
                    spacing: 8
                    ZenSlider {
                        width: 200
                        from: 0; to: 4; stepSize: 1
                        value: PanelState.startButtonBorderWidth
                        onValueChanged: {
                            PanelState.startButtonBorderWidth = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: PanelState.startButtonBorderWidth + "px"
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
                    ZenDropdown {
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
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Pick a built-in"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
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
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
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
                    ZenSlider {
                        width: 200
                        from: 20; to: 48; stepSize: 2
                        value: PanelState.workspaceDotActive
                        onValueChanged: {
                            PanelState.workspaceDotActive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                    ZenSlider {
                        width: 200
                        from: 16; to: 40; stepSize: 2
                        value: PanelState.workspaceDotInactive
                        onValueChanged: {
                            PanelState.workspaceDotInactive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                    ZenSlider {
                        width: 200
                        from: 8; to: 22; stepSize: 1
                        value: PanelState.workspaceFontActive
                        onValueChanged: {
                            PanelState.workspaceFontActive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                    ZenSlider {
                        width: 200
                        from: 6; to: 18; stepSize: 1
                        value: PanelState.workspaceFontInactive
                        onValueChanged: {
                            PanelState.workspaceFontInactive = Math.round(value)
                            PanelState.saveState()
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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

                                ZenButton {
                    text: "All → Center"
                    onClicked: root.moveToCenter()
                }
                                ZenButton {
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
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
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
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
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
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: modelData
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: ThemeService.fg
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Move right
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
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
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
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

                        ZenDropdown {
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

                                                ZenButton {
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
