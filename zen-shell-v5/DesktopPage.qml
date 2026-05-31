import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * DesktopPage v7.0.0-beta.1-hf82o — Karui (軽い)
 *
 * Settings page for the desktop FILE/FOLDER ICON layer. Widgets
 * (clock, weather, sysmon, sticky notes) have their own existing
 * settings page (Desktop Widgets, since v6.x) — this page only
 * controls the new file-icon overlay added in hf82o.
 *
 * Sections:
 *   1. General — enable, scan path, show folder icons, icon size,
 *                label color
 *   2. Maintenance — reset positions, refresh scan
 *
 * Wala tayong babawasan — additive page; existing DesktopWidgets
 * settings page (sidebar id "widgets") unchanged.
 */
ScrollView {
    id: rootView
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
        // hf82r: match GeneralPage spacing exactly
        width: rootView.availableWidth - 48
        x: 24
        y: 20
        spacing: 18

        DenshoPageHeader {
            Layout.fillWidth: true
            title: "Desktop Icons"
            subtitle: "File & folder icons on the desktop, Android-style free-form drag"
            kanji: "卓上"
            romaji: "Takujō"
        }

        // ═════════════════════════════════════════════════════════
        // Info banner — point user to Widgets page for widgets
        // ═════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hintCol.implicitHeight + 20
            radius: 10
            color: Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.10)
            border.color: Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.30)
            border.width: 1

            Column {
                id: hintCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                Text {
                    text: "Looking for widgets?"
                    color: ThemeService.fg
                    font.bold: true
                    font.pixelSize: 13
                }
                Text {
                    text: "Clock, weather, system monitor, and sticky notes are on the Desktop Widgets page (sidebar above). This page only controls file/folder icons."
                    color: ThemeService.alpha(ThemeService.fg, 0.85)
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // 1. GENERAL
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "General"
            subtitle: "Toggle the desktop icon overlay and how it scans for files"

            HMRow {
                label: "Show desktop icons"
                description: "Renders draggable file/folder icons on each monitor"
                HMSwitch {
                    checked: DesktopIconsState.enabled
                    onToggled: DesktopIconsState.enabled = checked
                }
            }

            // v7.0.0-beta.1-hf83: single-widget mode.
            HMRow {
                visible: DesktopIconsState.enabled
                separator: true
                label: "Single widget"
                description: "Collect all icons into one movable, resizable panel (taskbar-style icons)"
                HMSwitch {
                    checked: DesktopIconsState.widgetMode
                    onToggled: DesktopIconsState.widgetMode = checked
                }
            }

            HMRow {
                visible: DesktopIconsState.enabled && DesktopIconsState.widgetMode
                label: "Widget icon size"
                description: "Glyph size of each tile inside the panel (panel resizes by drag)"
                NumericStepper {
                    from: 32; to: 128; stepSize: 8; suffix: "px"
                    value: DesktopIconsState.widgetIconSize
                    onValueEdited: v => DesktopIconsState.widgetIconSize = Math.round(v)
                }
            }

            HMRow {
                visible: DesktopIconsState.enabled && DesktopIconsState.widgetMode
                label: "Reset widget position"
                description: "Move the panel back to 80,80 at its default size"
                ZenButton {
                    text: "Reset panel"
                    iconText: "\uf0e2"
                    onClicked: DesktopIconsState.setWidgetGeometry(80, 80, 560, 380)
                }
            }

            HMRow {
                visible: DesktopIconsState.enabled
                separator: true
                label: "Scan path"
                description: "Folder to scan for icons (defaults to ~/Desktop)"
                TextField {
                    id: pathField
                    width: 320
                    text: DesktopIconsState.scanPath
                    onEditingFinished: DesktopIconsState.scanPath = text
                    color: ThemeService.fg
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(ThemeService.fg.r,
                                       ThemeService.fg.g,
                                       ThemeService.fg.b, 0.06)
                        border.color: pathField.activeFocus
                            ? ThemeService.blue
                            : Qt.rgba(ThemeService.fg.r,
                                      ThemeService.fg.g,
                                      ThemeService.fg.b, 0.15)
                        border.width: 1
                    }
                }
            }

            HMRow {
                visible: DesktopIconsState.enabled
                label: "Show folder icons"
                description: "Hide if you only want files/.desktop launchers"
                HMSwitch {
                    checked: DesktopIconsState.showFolderIcons
                    onToggled: DesktopIconsState.showFolderIcons = checked
                }
            }

            HMRow {
                visible: DesktopIconsState.enabled
                label: "Icon size"
                description: "Pixel size of each icon glyph (label fits below)"
                NumericStepper {
                    from: 32; to: 128; stepSize: 8; suffix: "px"
                    value: DesktopIconsState.iconSize
                    onValueEdited: v => DesktopIconsState.iconSize = Math.round(v)
                }
            }

            HMRow {
                visible: DesktopIconsState.enabled
                label: "Label color"
                description: "auto / light / dark"
                ZenDropdown {
                    width: 160
                    model: ["auto", "light", "dark"]
                    currentIndex: {
                        const i = model.indexOf(DesktopIconsState.labelColor)
                        return i >= 0 ? i : 0
                    }
                    onActivated: DesktopIconsState.labelColor = model[currentIndex]
                }
            }

            // hf82r: arrange mode + grid size
            HMRow {
                visible: DesktopIconsState.enabled
                separator: true
                label: "Arrange"
                description: "free = drag anywhere (Android-style) · grid = snap to grid on drop · auto = auto-flow, drag disabled"
                ZenDropdown {
                    width: 160
                    model: ["free", "grid", "auto"]
                    currentIndex: {
                        const i = model.indexOf(DesktopIconsState.arrangeMode)
                        return i >= 0 ? i : 0
                    }
                    onActivated: DesktopIconsState.arrangeMode = model[currentIndex]
                }
            }

            // hf82w: Style dropdown — visual rendering mode, independent of arrange
            HMRow {
                visible: DesktopIconsState.enabled
                separator: true
                label: "Style"
                description: "default = normal 128px icons · compact = small dense, hover labels · squircle = squircle icons + drop-to-folder"
                ZenDropdown {
                    width: 160
                    model: ["default", "compact", "squircle"]
                    currentIndex: {
                        const i = model.indexOf(DesktopIconsState.style)
                        return i >= 0 ? i : 0
                    }
                    onActivated: DesktopIconsState.style = model[currentIndex]
                }
            }

            HMRow {
                visible: DesktopIconsState.enabled
                          && DesktopIconsState.arrangeMode !== "free"
                label: "Grid size"
                description: "Pixel size of each grid cell (drives snap + auto-flow spacing)"
                NumericStepper {
                    from: 64; to: 200; stepSize: 8; suffix: "px"
                    value: DesktopIconsState.gridSize
                    onValueEdited: v => DesktopIconsState.gridSize = Math.round(v)
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // 2. MAINTENANCE
        // ═════════════════════════════════════════════════════════
        HMSection {
            visible: DesktopIconsState.enabled
            title: "Maintenance"

            HMRow {
                label: "Reset icon positions"
                description: "Clear all saved icon (x, y) overrides — auto-flow takes over"
                ZenButton {
                    text: "Reset positions"
                    iconText: "\uf0e2"
                    onClicked: DesktopIconsState.iconPositions = ({})
                }
            }

            HMRow {
                separator: true
                label: "Refresh scan"
                description: "Re-scan the desktop folder immediately (auto-refresh every 30s)"
                ZenButton {
                    text: "Refresh"
                    accent: true
                    iconText: "\uf021"
                    onClicked: DesktopIconsService.refresh()
                }
            }

            HMRow {
                separator: true
                label: "Reset everything to defaults"
                description: "Clears icon positions; scan path keeps user value"
                ZenButton {
                    text: "Reset all"
                    danger: true
                    iconText: "\uf0e2"
                    onClicked: DesktopIconsState.resetDefaults()
                }
            }
        }

        Item { Layout.preferredHeight: 24 }
    }
}
