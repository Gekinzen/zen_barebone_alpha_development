import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * InputPage v6.16.2.3.2-hotfix
 *
 * Main-Settings counterpart to the compact Input tab in Control Panel.
 * Same backing service (MouseSettingsService) → changes here reflect
 * instantly in the Control Panel sliders and vice-versa (both bind to
 * the same singleton).
 *
 * This page exposes:
 *   - Mouse sensitivity (Hyprland input:sensitivity, -1.0..+1.0)
 *   - Scroll factor (Hyprland input:scroll_factor, 0.1..3.0)
 *   - Mouse natural scroll
 *   - Touchpad natural scroll
 *   - Reset all to Hyprland defaults
 *   - Helpful explanation of what each setting does + the Hyprland
 *     keyword each maps to (so power users can verify with hyprctl)
 *
 * Lives in Settings → INPUT & DISPLAY → Input.
 */
Flickable {
    id: root

    property int availableWidth: width

    contentWidth: width
    contentHeight: contentCol.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: contentCol
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 20

        // ═══ Header ═══
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Input"
                color: ThemeService.fg
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                text: "Mouse, scroll, and touchpad behavior. Changes apply " +
                      "live via hyprctl and persist to ~/.config/hypr/zen-mouse.conf."
                color: ThemeService.grey0
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // ═══ Mouse section ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: mouseSection.implicitHeight + 32
            radius: 12
            color: ThemeService.alpha(ThemeService.bg1 || ThemeService.bg0, 0.5)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: mouseSection
                anchors.fill: parent
                anchors.margins: 16
                spacing: 18

                Text {
                    text: "Mouse"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                // ── Sensitivity ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Pointer sensitivity"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        Text {
                            text: MouseSettingsService.sensitivity.toFixed(2)
                            color: ThemeService.blue
                            font.family: Theme.monoFont
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        text: "Negative = slower, positive = faster. Maps to " +
                              "Hyprland input:sensitivity. Range -1.0 to +1.0."
                        color: ThemeService.grey0
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: -1.0; to: 1.0; stepSize: 0.05
                        value: MouseSettingsService.sensitivity
                        onMoved: {
                            MouseSettingsService.sensitivity = value
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Scroll factor ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Scroll speed"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        Text {
                            text: MouseSettingsService.scrollFactor.toFixed(2) + "×"
                            color: ThemeService.blue
                            font.family: Theme.monoFont
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        text: "Multiplier for scroll wheel. Maps to " +
                              "Hyprland input:scroll_factor. Range 0.1 to 3.0."
                        color: ThemeService.grey0
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0.1; to: 3.0; stepSize: 0.1
                        value: MouseSettingsService.scrollFactor
                        onMoved: {
                            MouseSettingsService.scrollFactor = value
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Natural scroll (mouse) ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Natural scroll (mouse wheel)"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            text: "Inverts wheel direction (macOS-style). " +
                                  "Maps to input:natural_scroll."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    Switch {
                        checked: MouseSettingsService.naturalScroll
                        onToggled: {
                            MouseSettingsService.naturalScroll = checked
                            MouseSettingsService.apply(true)
                        }
                    }
                }
            }
        }

        // ═══ Touchpad section ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: tpSection.implicitHeight + 32
            radius: 12
            color: ThemeService.alpha(ThemeService.bg1 || ThemeService.bg0, 0.5)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: tpSection
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                Text {
                    text: "Touchpad"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Natural scroll (touchpad)"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            text: "Separate from mouse natural scroll. " +
                                  "Maps to input:touchpad:natural_scroll."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    Switch {
                        checked: MouseSettingsService.touchpadNaturalScroll
                        onToggled: {
                            MouseSettingsService.touchpadNaturalScroll = checked
                            MouseSettingsService.apply(true)
                        }
                    }
                }
            }
        }

        // ═══ Reset section ═══
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 12

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 38
                radius: 8
                color: resetMa.containsMouse
                    ? ThemeService.alpha(ThemeService.fg, 0.14)
                    : ThemeService.alpha(ThemeService.fg, 0.06)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: "Reset all to defaults"
                    color: ThemeService.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    id: resetMa
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
        }

        // ═══ Diagnostics ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: diagCol.implicitHeight + 24
            radius: 10
            color: ThemeService.alpha(ThemeService.bg1 || ThemeService.bg0, 0.35)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.06)

            ColumnLayout {
                id: diagCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Text {
                    text: "Verify in terminal"
                    color: ThemeService.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "hyprctl getoption input:sensitivity"
                    color: ThemeService.grey0
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
                Text {
                    text: "hyprctl getoption input:scroll_factor"
                    color: ThemeService.grey0
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
                Text {
                    text: "cat ~/.config/hypr/zen-mouse.conf"
                    color: ThemeService.grey0
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
            }
        }
    }
}
