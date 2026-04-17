import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * GeneralPage — HyprMod-style General settings
 *
 * Mirrors the HyprMod screenshot you shared: Gaps, Borders, Border Colors,
 * Layout, Snap. Each section is an HMSection; each option is an HMRow.
 *
 * Uses SettingsStateV2 as the state backend — independent from the legacy
 * SettingsState/AppearancePage so pwede pa rin gamitin pareho.
 */
ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    // v6.6: tracks whether the user has edited any theme color in the
    // Theme Palette section. Drives the "Save" button enabled state.
    property bool palettedDirty: false

    // Name prompt for "Save as profile" — uses zenity when available
    // so the user can name their custom theme, falls back to timestamped
    // default otherwise.
    Process {
        id: namePrompt
        running: false
        command: ["bash", "-c",
            "if command -v zenity >/dev/null 2>&1; then " +
            "  zenity --entry --title='Save as Custom Theme' " +
            "    --text='Name your theme profile:' " +
            "    --entry-text='My Custom Theme' 2>/dev/null; " +
            "else " +
            "  echo ''; " +  // empty → ThemeService uses timestamp default
            "fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim()
                // Empty or zenity cancel → let ThemeService auto-generate
                ThemeService.saveAsCustomTheme(name)
                root.palettedDirty = false
            }
        }
    }

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 20
        spacing: 18

        // ── Page header ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "General"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Window gaps, borders, layout, tearing, snap"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        // ═════════════════════════════════════════════════════════
        // GAPS
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Gaps"

            HMRow {
                label: "Inner gaps"
                description: "Gaps between windows in pixels"
                NumericStepper {
                    from: 0; to: 50; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.gapsIn
                    onValueEdited: v => {
                        SettingsStateV2.gapsIn = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword general:gaps_in " + Math.round(v))
                    }
                }
            }

            HMRow {
                label: "Outer gaps"
                description: "Gaps between windows and monitor edges in pixels"
                NumericStepper {
                    from: 0; to: 100; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.gapsOut
                    onValueEdited: v => {
                        SettingsStateV2.gapsOut = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword general:gaps_out " + Math.round(v))
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // BORDERS
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Borders"

            HMRow {
                label: "Border size"
                description: "Size of the border around windows"
                NumericStepper {
                    from: 0; to: 10; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.borderSize
                    onValueEdited: v => {
                        SettingsStateV2.borderSize = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword general:border_size " + Math.round(v))
                    }
                }
            }

            HMRow {
                label: "Resize on border"
                description: "Enables resizing windows by clicking and dragging on borders and gaps"
                Switch {
                    checked: SettingsStateV2.resizeOnBorder
                    onToggled: {
                        SettingsStateV2.resizeOnBorder = checked
                        SettingsStateV2.hyprctlNow("general:resize_on_border", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                label: "Extend border grab area"
                description: "Extends the area around the border where you can click and drag"
                NumericStepper {
                    from: 0; to: 50; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.extendBorderGrabArea
                    onValueEdited: v => {
                        SettingsStateV2.extendBorderGrabArea = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword general:extend_border_grab_area " + Math.round(v))
                    }
                }
            }

            HMRow {
                label: "Hover icon on border"
                description: "Show a cursor icon when hovering on borders"
                Switch {
                    checked: SettingsStateV2.hoverIconOnBorder
                    onToggled: {
                        SettingsStateV2.hoverIconOnBorder = checked
                        SettingsStateV2.hyprctlNow("general:hover_icon_on_border", checked ? "true" : "false")
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // BORDER COLORS
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Border Colors"

            HMRow {
                label: "Active border color"
                description: "Border color for the active window"
                ColorSwatch {
                    value: SettingsStateV2.activeBorderColor
                    onValueEdited: hex => {
                        SettingsStateV2.activeBorderColor = hex
                        SettingsStateV2.hyprctlColor("general:col.active_border", hex)
                    }
                }
            }

            HMRow {
                label: "Inactive border color"
                description: "Border color for inactive windows"
                ColorSwatch {
                    value: SettingsStateV2.inactiveBorderColor
                    onValueEdited: hex => {
                        SettingsStateV2.inactiveBorderColor = hex
                        SettingsStateV2.hyprctlColor("general:col.inactive_border", hex)
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // THEME PALETTE (v6.6) — overrides theme colors → custom profile
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Theme Palette"
            subtitle: "Override theme colors. Any change auto-saves as a custom profile."

            // Helper-generating repeater: one color row per palette slot
            Repeater {
                model: [
                    { key: "bg0",    label: "Background (bg0)",     desc: "Primary surface color" },
                    { key: "bg1",    label: "Surface (bg1)",        desc: "Cards, rows, sidebars" },
                    { key: "bg2",    label: "Surface alt (bg2)",    desc: "Inputs, hover tint" },
                    { key: "fg",     label: "Foreground (fg)",      desc: "Primary text color" },
                    { key: "grey0",  label: "Subtle text (grey0)",  desc: "Secondary labels, icons" },
                    { key: "red",    label: "Red",                   desc: "Errors, destructive accents" },
                    { key: "orange", label: "Orange",                desc: "Warnings" },
                    { key: "yellow", label: "Yellow",                desc: "Highlights, notices" },
                    { key: "green",  label: "Green",                 desc: "Success, confirmation" },
                    { key: "aqua",   label: "Aqua",                  desc: "Info" },
                    { key: "blue",   label: "Blue",                  desc: "Primary accent, links, focus" },
                    { key: "purple", label: "Purple",                desc: "Media, secondary accent" }
                ]

                delegate: HMRow {
                    required property var modelData
                    label: modelData.label
                    description: modelData.desc

                    ColorSwatch {
                        // Read live color from ThemeService (converts to #rrggbbaa for the swatch input)
                        value: {
                            const c = ThemeService[modelData.key] || "#ffffffff"
                            if (typeof c === "string") {
                                const h = c.replace(/^#/, "")
                                if (h.length === 6) return "#" + h.toLowerCase() + "ff"
                                return "#" + h.toLowerCase()
                            }
                            // QML color object → toString gives "#aarrggbb"; normalize
                            const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
                            const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
                            const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
                            return "#" + r + g + b + "ff"
                        }
                        onValueEdited: hex => {
                            // Strip alpha for ThemeService (palette is rgb, not rgba)
                            let h = hex.replace(/^#/, "")
                            if (h.length === 8) h = h.substring(0, 6)
                            ThemeService.setAccent(modelData.key, "#" + h)
                            // Mark that the user has edits pending
                            root.palettedDirty = true
                        }
                    }
                }
            }

            // Save-as-profile row
            HMRow {
                label: "Save edits as custom profile"
                description: "Writes the current palette to ~/.config/hypr-control-center/themes/custom/ and activates it"

                Row {
                    spacing: 8

                    Rectangle {
                        width: 84
                        height: 30
                        radius: 6
                        color: root.palettedDirty
                               ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.8)
                               : Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.5)
                        border.width: 1
                        border.color: root.palettedDirty
                                      ? ThemeService.blue
                                      : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.15)
                        opacity: root.palettedDirty ? 1.0 : 0.6

                        Text {
                            anchors.centerIn: parent
                            text: "Save"
                            color: root.palettedDirty ? "#ffffff" : ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.palettedDirty
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                // Prompt via zenity; fall back to auto-generated name
                                namePrompt.running = true
                            }
                        }
                    }

                    Rectangle {
                        width: 84
                        height: 30
                        radius: 6
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.15)
                        opacity: root.palettedDirty ? 1.0 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: "Revert"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.palettedDirty
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                // Revert = reload current-theme.json to bounce back to persisted colors
                                ThemeService.reload()
                                root.palettedDirty = false
                            }
                        }
                    }
                }
            }
        }

        HMSection {
            title: "Layout"

            HMRow {
                label: "Layout"
                description: "Which layout to use for tiling"
                ComboBox {
                    width: 140
                    model: ["dwindle", "master"]
                    currentIndex: SettingsStateV2.layout === "master" ? 1 : 0
                    onActivated: {
                        const v = model[currentIndex]
                        SettingsStateV2.layout = v
                        SettingsStateV2.hyprctlNow("general:layout", v)
                    }
                }
            }

            HMRow {
                label: "Allow tearing"
                description: "Allow screen tearing for reduced latency"
                Switch {
                    checked: SettingsStateV2.allowTearing
                    onToggled: {
                        SettingsStateV2.allowTearing = checked
                        SettingsStateV2.hyprctlNow("general:allow_tearing", checked ? "true" : "false")
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // SNAP
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Snap"

            HMRow {
                label: "Enable snap"
                description: "Enable snapping for floating windows"
                Switch {
                    checked: SettingsStateV2.snapEnabled
                    onToggled: {
                        SettingsStateV2.snapEnabled = checked
                        SettingsStateV2.hyprctlNow("general:snap:enabled", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.snapEnabled
                label: "Snap window gap"
                description: "Distance at which windows snap to each other"
                NumericStepper {
                    from: 0; to: 50; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.snapWindowGap
                    onValueEdited: v => {
                        SettingsStateV2.snapWindowGap = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword general:snap:window_gap " + Math.round(v))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.snapEnabled
                label: "Snap monitor gap"
                description: "Distance at which windows snap to monitor edges"
                NumericStepper {
                    from: 0; to: 50; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.snapMonitorGap
                    onValueEdited: v => {
                        SettingsStateV2.snapMonitorGap = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword general:snap:monitor_gap " + Math.round(v))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.snapEnabled
                label: "Respect gaps"
                description: "Snap respects the configured window gaps"
                Switch {
                    checked: SettingsStateV2.snapRespectGaps
                    onToggled: {
                        SettingsStateV2.snapRespectGaps = checked
                        SettingsStateV2.hyprctlNow("general:snap:respect_gaps", checked ? "true" : "false")
                    }
                }
            }
        }

        // Footer
        PageFooter {
            description: "Auto-saves • reads current Hyprland values on open"
            onResetRequested: SettingsStateV2.resetGeneralDefaults()
        }

        Item { Layout.preferredHeight: 24 }
    }
}
