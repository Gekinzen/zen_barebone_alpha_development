import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * SysRowPage v6.13 — Settings → System Tray
 *
 * Customize the SysRow expand drawer:
 *   - Toggle visibility of each module
 *   - Switch display mode (icon+bargraph vs icon+text)
 *   - Set custom colors per module (or use theme default)
 *   - Export/import full rice config as JSON for sharing
 */
Item {
    id: root

    // v8.0.0-alpha-hf133 — colour → "#RRGGBB", channel-safe.
    //
    // `"" + someColor` gives "#RRGGBB" when opaque and "#AARRGGBB" when not, and
    // ColorSwatch reads the first six characters as RGB. Feeding it a translucent
    // colour therefore rotates the channels — the exact hf120 bug. Build the hex
    // from `.r/.g/.b` and the alpha byte can never sneak in.
    function _hex(c) {
        function b(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2) }
        return "#" + b(c.r) + b(c.g) + b(c.b)
    }

    property string importText: ""

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            // Page header
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
                        text: "System Tray"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: ThemeService.fg
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Customize the expandable SysRow modules and export/import rices"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: ThemeService.grey1
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24
                spacing: 16

                // ═══════════════════════════════════════
                // DISPLAY MODE
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Display Mode"
                    subtitle: "How modules show data in the bar"

                    SettingRow {
                        label: "Module format"
                        description: SysRowState.displayMode === "icon"
                                     ? "Icon + bar graph (▁▂▃▄▅▆▇█)"
                                     : "Icon + text value (42%, 23.4G)"

                        RowLayout {
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "icon", label: " ▅" },
                                    { id: "text", label: " 42%" }
                                ]

                                Rectangle {
                                    required property var modelData
                                    property bool selected: SysRowState.displayMode === modelData.id

                                    width: 64; height: 28; radius: 6
                                    color: selected
                                           ? ThemeService.alpha(ThemeService.blue, 0.2)
                                           : (modeMouse.containsMouse
                                              ? ThemeService.alpha(ThemeService.fg, 0.06)
                                              : ThemeService.alpha(ThemeService.fg, 0.03))
                                    border.width: selected ? 1 : 0
                                    border.color: ThemeService.alpha(ThemeService.blue, 0.5)

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: selected ? ThemeService.blue : ThemeService.grey0
                                    }

                                    MouseArea {
                                        id: modeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            SysRowState.displayMode = modelData.id
                                            SysRowState.saveState()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // MODULE VISIBILITY TOGGLES
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Visible Modules"
                    subtitle: "Toggle which modules appear when expanded"

                    Repeater {
                        model: [
                            { key: "showSound",     label: "Sound",       icon: "\uf028", desc: "PipeWire volume" },
                            { key: "showCpu",       label: "CPU",         icon: "\uf2db", desc: "Processor usage + temp" },
                            { key: "showRam",       label: "RAM",         icon: "\uefc5", desc: "Memory usage" },
                            { key: "showTemp",      label: "Temperature", icon: "\uf2c9", desc: "CPU/GPU temperature" },
                            { key: "showNetwork",   label: "Network",     icon: "\udb86\udd28", desc: "WiFi / Ethernet status" },
                            { key: "showBluetooth", label: "Bluetooth",   icon: "\uf293", desc: "Bluetooth devices" },
                            { key: "showBattery",   label: "Battery",     icon: "\uf240", desc: "Battery level + charging (laptops only — auto-hides on desktop)" }
                        ]

                        SettingRow {
                            required property var modelData
                            // v8.0.0-alpha-hf177 — was
                            //   label: modelData.icon + "  " + modelData.label
                            // which welded the glyph to the word (see the note
                            // at the top of SettingRow.qml). Icon now has its
                            // own Text + its own font; the RowLayout owns the
                            // gap, exactly like Bar Modules.
                            icon: modelData.icon
                            label: modelData.label
                            description: modelData.desc

                            HMSwitch {
                                compact: true
                                activeColor: ThemeService.alpha(ThemeService.green, 0.85)
                                checked: SysRowState[modelData.key]
                                onToggled: {
                                    SysRowState[modelData.key] = !SysRowState[modelData.key]
                                    SysRowState.saveState()
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // CUSTOM COLORS
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Custom Colors"
                    subtitle: "Leave empty to use theme-reactive colors (auto)"

                    Repeater {
                        model: [
                            // v8.0.0-alpha-hf177 — same glyphs as the visibility
                            // section above, so the two lists read as one page
                            // instead of "the one with icons" and "the other one".
                            { key: "cpuColor",     label: "CPU color",     icon: "\uf2db", fallback: "auto (usage-based)" },
                            { key: "ramColor",     label: "RAM color",     icon: "\uefc5", fallback: "auto (usage-based)" },
                            { key: "tempColor",    label: "Temp color",    icon: "\uf2c9", fallback: "auto (temp-based)" },
                            { key: "soundColor",   label: "Sound color",   icon: "\uf028", fallback: "auto (theme fg)" },
                            { key: "networkColor", label: "Network color", icon: "\udb86\udd28", fallback: "auto (theme fg)" },
                            { key: "btColor",      label: "Bluetooth color", icon: "\uf293", fallback: "auto (theme blue)" }
                        ]

                        SettingRow {
                            required property var modelData
                            icon: modelData.icon
                            label: modelData.label
                            description: SysRowState[modelData.key]
                                         ? SysRowState[modelData.key]
                                         : modelData.fallback

                            // ══ v8.0.0-alpha-hf133 — THIS SWATCH NEVER OPENED ══
                            //
                            // "sa system tray hindi ma-select yun mga color picker nila"
                            //
                            // It wasn't a picker. It was a bare `Rectangle` painted
                            // with the current value — no MouseArea, no click handler,
                            // nothing to open. Every other colour row in the shell uses
                            // `ColorSwatch`, which routes through the `ColorPickerState`
                            // singleton to the one global `ColorPickerOverlay` that
                            // hf114 mounted in the Control Center. This page was written
                            // before that plumbing existed and was never migrated.
                            //
                            // Now it is a real ColorSwatch: click the square, the picker
                            // opens. The hex field it already had is ColorSwatch's own,
                            // and the ✕ still clears back to the theme-reactive default.
                            RowLayout {
                                spacing: 6

                                ColorSwatch {
                                    // "" means auto (theme-reactive). Seed the picker
                                    // with the theme colour it would have drawn, so you
                                    // start from what you can see, not from black.
                                    //
                                    // NOT `"" + ThemeService.grey2`. Qt stringifies an
                                    // opaque colour as "#RRGGBB" but a translucent one
                                    // as "#AARRGGBB", and ColorSwatch._rgb() takes the
                                    // first six characters — which would hand the picker
                                    // "#bf99a6" for a colour whose real RGB is #99a6b3.
                                    // That is the hf120 channel-rotation bug, again.
                                    // Build the hex from the channels and there is
                                    // nothing to get wrong.
                                    value: SysRowState[modelData.key].length > 0
                                           ? SysRowState[modelData.key]
                                           : root._hex(ThemeService.grey2)
                                    onValueEdited: hex => {
                                        SysRowState[modelData.key] = hex
                                        SysRowState.saveState()
                                    }
                                }

                                // Clear button — back to auto
                                Rectangle {
                                    width: 24; height: 24; radius: 4
                                    visible: SysRowState[modelData.key].length > 0
                                    color: clearMouse.containsMouse
                                           ? ThemeService.alpha(ThemeService.red, 0.15) : "transparent"

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.pixelSize: 10
                                        color: ThemeService.red
                                    }

                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        ToolTip.visible: containsMouse
                                        ToolTip.delay: 450
                                        ToolTip.text: "Back to the theme-reactive colour"
                                        onClicked: {
                                            SysRowState[modelData.key] = ""
                                            SysRowState.saveState()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // EXPORT / IMPORT RICE
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Rice Export / Import"
                    subtitle: "Share your entire Zen Shell config as a single JSON file"

                    // Export
                    SettingRow {
                        label: "Export current rice"
                        description: "Saves panel + sysrow + theme + bar layout"

                        RowLayout {
                            spacing: 6

                            Rectangle {
                                width: 80; height: 24; radius: 4
                                color: LookService.surfaceColor(ThemeService.bg2, 0.6)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.fg, 0.1)

                                TextInput {
                                    id: exportNameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: ThemeService.fg
                                    text: "my-rice"
                                    selectByMouse: true
                                }
                            }

                            Rectangle {
                                width: 60; height: 28; radius: 6
                                color: exportMouse.containsMouse
                                       ? ThemeService.alpha(ThemeService.green, 0.2)
                                       : ThemeService.alpha(ThemeService.green, 0.1)

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.centerIn: parent
                                    text: "Export"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: ThemeService.green
                                }

                                MouseArea {
                                    id: exportMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const path = SysRowState.exportRice(exportNameInput.text)
                                        exportStatus.text = "Exported → " + path
                                        exportStatus.visible = true
                                        SysRowState.listExports()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        id: exportStatus
                        visible: false
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.green
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Import
                    SettingRow {
                        label: "Import rice from clipboard"
                        description: "Paste JSON content and click Import"

                        Rectangle {
                            width: 60; height: 28; radius: 6
                            color: importMouse.containsMouse
                                   ? ThemeService.alpha(ThemeService.blue, 0.2)
                                   : ThemeService.alpha(ThemeService.blue, 0.1)

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                anchors.centerIn: parent
                                text: "Import"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.blue
                            }

                            MouseArea {
                                id: importMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Read clipboard via wl-paste
                                    importProc.command = ["bash", "-c", "wl-paste 2>/dev/null"]
                                    importProc.running = true
                                }
                            }
                        }
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        id: importStatus
                        visible: false
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.blue
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Saved exports list
                    SettingRow {
                        label: "Saved exports"
                        description: SysRowState.exportList.length + " file(s) in exports/"
                    }

                    Repeater {
                        model: SysRowState.exportList

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.leftMargin: 12
                            spacing: 8

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: "\uf15b"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: ThemeService.grey0
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: ThemeService.fg
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.date
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: ThemeService.grey1
                            }

                            Rectangle {
                                width: 50; height: 22; radius: 4
                                color: loadMouse.containsMouse
                                       ? ThemeService.alpha(ThemeService.blue, 0.15)
                                       : ThemeService.alpha(ThemeService.blue, 0.08)

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.centerIn: parent
                                    text: "Load"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeService.blue
                                }

                                MouseArea {
                                    id: loadMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        loadProc.command = ["bash", "-c", "cat '" + modelData.path + "'"]
                                        loadProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // RESET
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Reset"

                    SettingRow {
                        label: "Reset SysRow to defaults"
                        description: "Restores all toggles, colors, and display mode"

                        Rectangle {
                            width: 60; height: 28; radius: 6
                            color: resetMouse.containsMouse
                                   ? ThemeService.alpha(ThemeService.red, 0.15)
                                   : ThemeService.alpha(ThemeService.red, 0.08)

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                anchors.centerIn: parent
                                text: "Reset"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.red
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SysRowState.resetDefaults()
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }

    // Import process — reads clipboard JSON
    Process {
        id: importProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.length > 0 && text.startsWith("{")) {
                    const ok = SysRowState.importRice(text)
                    importStatus.text = ok ? "Import successful — settings applied" : "Import failed — invalid JSON"
                    importStatus.color = ok ? ThemeService.green : ThemeService.red
                } else {
                    importStatus.text = "Clipboard is empty or not valid JSON"
                    importStatus.color = ThemeService.red
                }
                importStatus.visible = true
            }
        }
    }

    // Load saved export process
    Process {
        id: loadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.length > 0) {
                    const ok = SysRowState.importRice(text)
                    importStatus.text = ok ? "Rice loaded successfully" : "Load failed"
                    importStatus.color = ok ? ThemeService.green : ThemeService.red
                    importStatus.visible = true
                }
            }
        }
    }

    Component.onCompleted: SysRowState.listExports()
}


