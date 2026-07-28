import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * TaskbarPage — v8.0.0-alpha-hf182
 *
 * Taskbar.qml is a single component mounted in three places: Bar, BarVertical and
 * ZenDock. Until hf182 it had no idea which one it was, so every taskbar setting was
 * unavoidably shared. It knows now (surface: "bar" | "dock"), which is what lets this
 * page offer the two separately — or linked, which is the old behaviour and the default.
 */
ScrollView {
    id: root
    clip: true

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                spacing: 10
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "任務列"
                    font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold
                    color: ThemeService.grey1
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Taskbar"
                    font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold
                    color: ThemeService.fg
                }
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "The app icons and the plate behind them — in the dock and in the bar"
                font.family: Theme.fontFamily; font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        SettingsSection {
            title: "Plate"
            subtitle: "The panel behind the icons. At 0% it stops drawing entirely — border and all — and the icons float on the wallpaper."

            SettingRow {
                label: "Link dock and bar"
                Row {
                    spacing: 8
                    HMSwitch {
                        checked: PanelState.taskbarLinkSurfaces
                        onToggled: {
                            PanelState.taskbarLinkSurfaces = checked
                            PanelState.saveState()
                        }
                    }
                }
            }

            SettingRow {
                label: PanelState.taskbarLinkSurfaces ? "Plate opacity" : "Dock plate"
                Row {
                    spacing: 8
                    ZenSlider {
                        id: dockOp
                        width: 200; from: 0.0; to: 1.0; stepSize: 0.02
                        value: PanelState.taskbarOpacity
                        onMoved: { PanelState.taskbarOpacity = value; PanelState.saveState() }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: Math.round(dockOp.value * 100) + "%"
                        color: ThemeService.fg; font.pixelSize: 12
                        font.family: Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                // Only meaningful once the two are unlinked.
                visible: !PanelState.taskbarLinkSurfaces
                label: "Bar plate"
                Row {
                    spacing: 8
                    ZenSlider {
                        id: barOp
                        width: 200; from: 0.0; to: 1.0; stepSize: 0.02
                        value: PanelState.taskbarBarOpacity
                        onMoved: { PanelState.taskbarBarOpacity = value; PanelState.saveState() }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: Math.round(barOp.value * 100) + "%"
                        color: ThemeService.fg; font.pixelSize: 12
                        font.family: Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        SettingsSection {
            title: "Icons"
            subtitle: "Size scales the icon inside its button, so it never changes the bar's layout or pushes icons into the overflow chevrons."

            SettingRow {
                label: "Icon size"
                Row {
                    spacing: 8
                    ZenSlider {
                        id: icoSize
                        width: 200; from: 0.6; to: 1.4; stepSize: 0.05
                        value: PanelState.taskbarIconScale
                        onMoved: { PanelState.taskbarIconScale = value; PanelState.saveState() }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: Math.round(icoSize.value * 100) + "%"
                        color: ThemeService.fg; font.pixelSize: 12
                        font.family: Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingRow {
                label: "Icon backgrounds"
                Row {
                    spacing: 8
                    HMSwitch {
                        checked: PanelState.taskbarIconBackgrounds
                        onToggled: {
                            PanelState.taskbarIconBackgrounds = checked
                            PanelState.saveState()
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            wrapMode: Text.WordWrap
            text: "For the macOS look: plate at 0% and Icon backgrounds off. The plate's colour "
                  + "comes from the theme, or from the Glass+ tint when that look is active — "
                  + "the same one colour every other surface uses, so it can't drift out of step "
                  + "with the rest of the shell. Overall bar height is under Dock → Height."
            color: ThemeService.grey2; font.family: Theme.fontFamily; font.pixelSize: 11
        }

        Item { Layout.preferredHeight: 12 }
    }
}
