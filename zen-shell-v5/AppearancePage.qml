import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ScrollView {
    id: root
    clip: true

    Process { id: ccLauncher; running: false }

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Appearance"
                font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Settings persist across restarts"
                font.family: Theme.fontFamily; font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        ControlCenterBanner {
            feature: "Advanced Appearance"
            description: "Border colors, shadows, layout, tearing"
        }

        SettingsSection {
            title: "General"

            SettingRow {
                label: "Gaps In"; description: "Space between windows"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 0; to: 50; stepSize: 1
                        value: SettingsState.gapsIn
                        onValueChanged: {
                            SettingsState.gapsIn = Math.round(value)
                            SettingsState.scheduleHyprctl("keyword general:gaps_in " + SettingsState.gapsIn)
                        }
                    }
                    Text { text: SettingsState.gapsIn + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Gaps Out"; description: "Space to screen edge"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 0; to: 100; stepSize: 1
                        value: SettingsState.gapsOut
                        onValueChanged: {
                            SettingsState.gapsOut = Math.round(value)
                            SettingsState.scheduleHyprctl("keyword general:gaps_out " + SettingsState.gapsOut)
                        }
                    }
                    Text { text: SettingsState.gapsOut + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Border Size"; description: "Window border thickness"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 0; to: 10; stepSize: 1
                        value: SettingsState.borderSize
                        onValueChanged: {
                            SettingsState.borderSize = Math.round(value)
                            SettingsState.scheduleHyprctl("keyword general:border_size " + SettingsState.borderSize)
                        }
                    }
                    Text { text: SettingsState.borderSize + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        SettingsSection {
            title: "Decoration"

            SettingRow {
                label: "Corner Rounding"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 0; to: 30; stepSize: 1
                        value: SettingsState.rounding
                        onValueChanged: {
                            SettingsState.rounding = Math.round(value)
                            SettingsState.scheduleHyprctl("keyword decoration:rounding " + SettingsState.rounding)
                        }
                    }
                    Text { text: SettingsState.rounding + "px"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Active Opacity"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 0.5; to: 1.0; stepSize: 0.05
                        value: SettingsState.activeOpacity
                        onValueChanged: {
                            SettingsState.activeOpacity = value
                            SettingsState.scheduleHyprctl("keyword decoration:active_opacity " + SettingsState.activeOpacity.toFixed(2))
                        }
                    }
                    Text { text: Math.round(SettingsState.activeOpacity * 100) + "%"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Inactive Opacity"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 0.5; to: 1.0; stepSize: 0.05
                        value: SettingsState.inactiveOpacity
                        onValueChanged: {
                            SettingsState.inactiveOpacity = value
                            SettingsState.scheduleHyprctl("keyword decoration:inactive_opacity " + SettingsState.inactiveOpacity.toFixed(2))
                        }
                    }
                    Text { text: Math.round(SettingsState.inactiveOpacity * 100) + "%"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        SettingsSection {
            title: "Blur"

            SettingRow {
                label: "Enable Blur"
                HMSwitch {
                    checked: SettingsState.blurEnabled
                    onToggled: {
                        SettingsState.blurEnabled = checked
                        SettingsState.hyprctlNow("decoration:blur:enabled", checked ? "true" : "false")
                    }
                }
            }

            SettingRow {
                label: "Blur Size"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 1; to: 20; stepSize: 1
                        value: SettingsState.blurSize
                        onValueChanged: {
                            SettingsState.blurSize = Math.round(value)
                            SettingsState.scheduleHyprctl("keyword decoration:blur:size " + SettingsState.blurSize)
                        }
                    }
                    Text { text: SettingsState.blurSize + ""; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            SettingRow {
                label: "Blur Passes"
                Row {
                    spacing: 8
                    Slider {
                        width: 200; from: 1; to: 5; stepSize: 1
                        value: SettingsState.blurPasses
                        onValueChanged: {
                            SettingsState.blurPasses = Math.round(value)
                            SettingsState.scheduleHyprctl("keyword decoration:blur:passes " + SettingsState.blurPasses)
                        }
                    }
                    Text { text: SettingsState.blurPasses + ""; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        PageFooter {
            description: "Auto-saves • reads current Hyprland values on open"
            onResetRequested: SettingsState.resetAppearanceDefaults()
        }

        Item { Layout.preferredHeight: 24 }
    }
}
