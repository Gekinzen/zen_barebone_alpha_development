import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * ThemesPage v6 — Full theme management UI
 * - Dropdown shows all available themes (builtin + custom)
 * - Live swatch preview
 * - Import: file picker → copy to custom/
 * - Export: save current theme to external path
 * - Delete: only custom themes (builtin protected)
 */
ScrollView {
    id: root
    clip: true

    Process {
        id: filePicker
        running: false
        property string mode: "import"
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim()
                if (!path) return
                if (filePicker.mode === "import") {
                    ThemeService.importTheme(path)
                } else if (filePicker.mode === "export") {
                    ThemeService.exportCurrentTheme(path)
                }
            }
        }
    }

    function openImportPicker() {
        filePicker.mode = "import"
        filePicker.command = ["bash", "-c",
            "if command -v zenity > /dev/null; then " +
            "  zenity --file-selection --title='Import Theme JSON' --file-filter='*.json' 2>/dev/null; " +
            "elif command -v kdialog > /dev/null; then " +
            "  kdialog --getopenfilename '" + Quickshell.env("HOME") + "' '*.json' 2>/dev/null; " +
            "fi"]
        filePicker.running = true
    }

    function openExportPicker() {
        filePicker.mode = "export"
        filePicker.command = ["bash", "-c",
            "if command -v zenity > /dev/null; then " +
            "  zenity --file-selection --save --confirm-overwrite --title='Export Theme' " +
            "    --filename='" + ThemeService.themeId + ".json' 2>/dev/null; " +
            "elif command -v kdialog > /dev/null; then " +
            "  kdialog --getsavefilename '" + Quickshell.env("HOME") + "/" + ThemeService.themeId + ".json' '*.json' 2>/dev/null; " +
            "fi"]
        filePicker.running = true
    }

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 16

        // Header
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Themes"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Switch, import, export color themes"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        ControlCenterBanner {
            feature: "Advanced Theme Editing"
            description: "Per-app color tuning, bezier/curves, palette editor in Hypr Control Center"
        }

        // ── Theme Switcher ──
        SettingsSection {
            title: "Current Theme"

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    radius: 12
                    color: ThemeService.bg1
                    border.width: 2
                    border.color: ThemeService.blue

                    // Theme color preview — 4 accent dots instead of broken icon
                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: 4

                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.blue }
                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.green }
                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.red }
                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.purple }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: ThemeService.themeName
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }
                    Text {
                        text: ThemeService.themeDescription || ("ID: " + ThemeService.themeId)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    Text {
                        text: ThemeService.currentIsBuiltin ? "● Builtin theme" : "◆ Custom theme"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.currentIsBuiltin ? ThemeService.green : ThemeService.orange
                    }
                }
            }

            // Theme picker dropdown
            SettingRow {
                label: "Switch Theme"
                description: "Found " + ThemeService.availableThemes.length + " themes (" +
                             ThemeService.availableThemes.filter(t => t.is_builtin).length + " builtin, " +
                             ThemeService.availableThemes.filter(t => !t.is_builtin).length + " custom)"

                RowLayout {
                    spacing: 8

                    ZenComboBox {
                        id: themeCombo
                        Layout.preferredWidth: 260
                        model: ThemeService.availableThemes.map(t =>
                            (t.is_builtin ? "● " : "◆ ") + t.name)
                        currentIndex: {
                            const idx = ThemeService.availableThemes.findIndex(t => t.id === ThemeService.themeId)
                            return idx >= 0 ? idx : 0
                        }
                        onActivated: {
                            const theme = ThemeService.availableThemes[currentIndex]
                            if (theme) ThemeService.applyTheme(theme)
                        }
                    }

                    Button {
                        text: "\uf021"
                        font.family: "JetBrainsMono Nerd Font"
                        onClicked: ThemeService.refreshThemeList()
                        ToolTip.visible: hovered
                        ToolTip.text: "Refresh list"
                    }
                }
            }
        }

        // ── Palette ──
        SettingsSection {
            title: "Palette Preview"
            subtitle: "Colors for the current theme"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                // Backgrounds
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Backgrounds"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [
                                { label: "bg0", key: "bg0", color: ThemeService.bg0 },
                                { label: "bg1", key: "bg1", color: ThemeService.bg1 },
                                { label: "bg2", key: "bg2", color: ThemeService.bg2 },
                                { label: "bg3", key: "bg3", color: ThemeService.bg3 },
                                { label: "bg4", key: "bg4", color: ThemeService.bg4 }
                            ]
                            delegate: PaletteBox {
                                required property var modelData
                                label: modelData.label
                                paletteKey: modelData.key
                                value: modelData.color
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // Foreground
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Foreground & Greys"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [
                                { label: "fg",    key: "fg",    color: ThemeService.fg },
                                { label: "grey0", key: "grey0", color: ThemeService.grey0 },
                                { label: "grey1", key: "grey1", color: ThemeService.grey1 },
                                { label: "grey2", key: "grey2", color: ThemeService.grey2 }
                            ]
                            delegate: PaletteBox {
                                required property var modelData
                                label: modelData.label
                                paletteKey: modelData.key
                                value: modelData.color
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // Accents
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Accents"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [
                                { label: "red",    key: "red",    color: ThemeService.red },
                                { label: "orange", key: "orange", color: ThemeService.orange },
                                { label: "yellow", key: "yellow", color: ThemeService.yellow },
                                { label: "green",  key: "green",  color: ThemeService.green },
                                { label: "aqua",   key: "aqua",   color: ThemeService.aqua },
                                { label: "blue",   key: "blue",   color: ThemeService.blue },
                                { label: "purple", key: "purple", color: ThemeService.purple }
                            ]
                            delegate: PaletteBox {
                                required property var modelData
                                label: modelData.label
                                paletteKey: modelData.key
                                value: modelData.color
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        // ── Import / Export / Delete ──
        SettingsSection {
            title: "Share Themes"
            subtitle: "Import JSON files, export to share with friends, delete custom themes"

            SettingRow {
                label: "Import Theme"
                description: "Load a .json theme file into your custom folder"

                Button {
                    text: "\uf019  Import..."
                    font.family: "JetBrainsMono Nerd Font"
                    onClicked: root.openImportPicker()
                }
            }

            SettingRow {
                label: "Export Current"
                description: "Save the current theme as a JSON file"

                Button {
                    text: "\uf093  Export..."
                    font.family: "JetBrainsMono Nerd Font"
                    onClicked: root.openExportPicker()
                }
            }

            SettingRow {
                label: "Delete Current"
                description: ThemeService.currentIsBuiltin
                             ? "⚠ Cannot delete builtin themes"
                             : "Delete the current custom theme"

                Button {
                    text: "\uf1f8  Delete"
                    font.family: "JetBrainsMono Nerd Font"
                    enabled: !ThemeService.currentIsBuiltin
                    onClicked: {
                        const current = ThemeService.availableThemes.find(t => t.id === ThemeService.themeId)
                        if (current && !current.is_builtin) ThemeService.deleteCustomTheme(current)
                    }
                }
            }
        }

        // ── Status message ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ThemeService.statusMsg.length > 0 ? 32 : 0
            visible: ThemeService.statusMsg.length > 0
            radius: 6
            color: ThemeService.alpha(ThemeService.blue, 0.15)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.blue, 0.3)

            Text {
                anchors.centerIn: parent
                text: ThemeService.statusMsg
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.fg
            }
        }

        // ── v6.16.4.11: Custom Themes Manager ──
        // Lists user-created themes (from ~/.config/hypr-control-center/themes/custom/)
        // and provides rename / delete / "save current palette as new theme" actions.
        // Additive — the existing theme grid above stays untouched.
        HMSection {
            title: "Custom Themes"
            subtitle: "Your saved palettes. Click a theme above to activate; edit colors in General → Theme Palette, then save here."

            // Save-new button — invokes existing ThemeService.saveAsCustomTheme()
            // which already prompts via zenity and writes the JSON. We don't
            // re-implement any of that logic — just surface the entry point.
            HMRow {
                label: "Save current palette as new theme"
                description: "Captures the active palette (including General-page edits) as a new custom theme file"
                icon: "\uf0c7"

                Rectangle {
                    width: 92
                    height: 30
                    radius: 8
                    color: saveNewMa.containsMouse
                        ? ThemeService.alpha(ThemeService.blue, 0.95)
                        : ThemeService.alpha(ThemeService.blue, 0.8)

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0c7  Save as…"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: saveNewMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: customSaveNamePrompt.running = true
                    }
                }

                Process {
                    id: customSaveNamePrompt
                    running: false
                    command: ["bash", "-c",
                        "zenity --entry --title='Save Custom Theme' " +
                        "--text='Theme name:' --entry-text='my-theme' 2>/dev/null"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const name = this.text.trim()
                            if (name.length > 0) {
                                ThemeService.saveAsCustomTheme(name)
                            }
                        }
                    }
                }
            }

            // List of existing custom themes — rename / delete / activate buttons
            Repeater {
                model: ThemeService.availableThemes.filter(function(t) { return !t.is_builtin })

                HMRow {
                    required property var modelData
                    label: modelData.name
                    description: modelData.description || "Custom theme · " + modelData.id
                    icon: (ThemeService.themeName === modelData.name) ? "\uf00c" : "\uf1fc"

                    Row {
                        spacing: 6

                        // Activate
                        Rectangle {
                            visible: ThemeService.themeName !== modelData.name
                            width: 76
                            height: 28
                            radius: 6
                            color: actMa.containsMouse
                                ? ThemeService.alpha(ThemeService.green, 0.3)
                                : ThemeService.alpha(ThemeService.green, 0.15)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.green, 0.35)

                            Text {
                                anchors.centerIn: parent
                                text: "Activate"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.green
                            }

                            MouseArea {
                                id: actMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeService.applyTheme(modelData)
                            }
                        }

                        // Rename
                        Rectangle {
                            width: 76
                            height: 28
                            radius: 6
                            color: renMa.containsMouse
                                ? ThemeService.alpha(ThemeService.fg, 0.1)
                                : ThemeService.alpha(ThemeService.bg2, 0.5)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "Rename"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.fg
                            }

                            MouseArea {
                                id: renMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    renameTarget.themeRef = modelData
                                    renameTarget.running = true
                                }
                            }

                            // Per-row zenity rename dialog. Scoped to this
                            // row delegate so only this theme is affected.
                            Process {
                                id: renameTarget
                                property var themeRef: null
                                running: false
                                command: ["bash", "-c",
                                    "zenity --entry --title='Rename Theme' " +
                                    "--text='New name:' --entry-text='" +
                                    (modelData.name || "").replace(/'/g, "'\\''") +
                                    "' 2>/dev/null"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        const newName = this.text.trim()
                                        if (newName.length > 0 && renameTarget.themeRef) {
                                            ThemeService.renameCustomTheme(renameTarget.themeRef, newName)
                                        }
                                    }
                                }
                            }
                        }

                        // Delete
                        Rectangle {
                            width: 32
                            height: 28
                            radius: 6
                            color: delMa.containsMouse
                                ? ThemeService.alpha(ThemeService.red, 0.3)
                                : ThemeService.alpha(ThemeService.red, 0.12)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.red, 0.3)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: ThemeService.red
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    deleteConfirm.themeRef = modelData
                                    deleteConfirm.running = true
                                }
                            }

                            Process {
                                id: deleteConfirm
                                property var themeRef: null
                                running: false
                                command: ["bash", "-c",
                                    "zenity --question --title='Delete Theme' " +
                                    "--text='Delete \"" +
                                    (modelData.name || "").replace(/'/g, "'\\''") +
                                    "\"?\\n\\nThis cannot be undone.' 2>/dev/null && echo YES"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        if (this.text.trim() === "YES" && deleteConfirm.themeRef) {
                                            ThemeService.deleteCustomTheme(deleteConfirm.themeRef)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                visible: ThemeService.availableThemes.filter(function(t) { return !t.is_builtin }).length === 0
                radius: 8
                color: ThemeService.alpha(ThemeService.bg2, 0.3)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: "No custom themes yet. Edit colors in General → Theme Palette, then click 'Save as…' above."
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        PageFooter {
            description: "Applies via current-theme.json"
            onResetRequested: {
                const dflt = ThemeService.availableThemes.find(t => t.id === "tokyo-night")
                if (dflt) ThemeService.applyTheme(dflt)
            }
        }

        Item { Layout.preferredHeight: 24 }
    }
}
