import QtQuick
import QtQuick.Layouts

/*
 * WorkflowProfilePicker v7.0.0-alpha.13 — Karui (軽い)
 *
 * Compact 5-tile row showing all workflow profiles. Tap any to
 * activate. Active profile gets blue ring + filled background.
 *
 * Designed to embed inside ControlPanel as a top-level row.
 * Theme-aware via ThemeService — re-themes on theme switch.
 */
Rectangle {
    id: picker

    color: "transparent"
    implicitHeight: 76

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "\uf0b1"   // briefcase / workflow
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: ThemeService.blue
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Workflow"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: ThemeService.alpha(ThemeService.fg, 0.7)
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: DenshoService.denshoMode
                text: "・流れ"
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 10
                color: ThemeService.alpha(ThemeService.fg, 0.45)
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: WorkflowProfileService.currentProfile
                      ? WorkflowProfileService.currentProfile.charAt(0).toUpperCase()
                        + WorkflowProfileService.currentProfile.slice(1)
                      : ""
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: ThemeService.alpha(ThemeService.fg, 0.5)
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
            }
        }

        // Tiles
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: WorkflowProfileService.profilesList()

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 8

                    readonly property bool isActive: WorkflowProfileService.currentProfile === modelData.id

                    color: isActive
                           ? ThemeService.alpha(ThemeService.blue, 0.20)
                           : (tileMa.containsMouse
                              ? LookService.surfaceColor(ThemeService.bg2, 0.85)
                              : LookService.surfaceColor(ThemeService.bg2, 0.45))
                    border.width: isActive ? 1.5 : 1
                    border.color: isActive
                                  ? ThemeService.blue
                                  : ThemeService.alpha(ThemeService.fg, 0.08)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: parent.parent.isActive
                                   ? ThemeService.blue
                                   : ThemeService.fg
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: DenshoService.denshoMode
                                  ? modelData.kanji
                                  : modelData.label
                            font.family: DenshoService.denshoMode
                                         ? "Noto Sans CJK JP"
                                         : Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.alpha(ThemeService.fg, 0.85)
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: tileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WorkflowProfileService.activate(modelData.id)
                    }
                }
            }
        }
    }
}
