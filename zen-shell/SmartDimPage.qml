import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * SmartDimPage v7.0.0-beta.1-hf39 — Settings page for Smart Dim.
 */
Item {
    id: root

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: contentCol.implicitHeight
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 24
            spacing: 16

            DenshoPageHeader {
                Layout.fillWidth: true
                title: "Smart Dim"
                subtitle: "Context-aware brightness automation"
                kanji: "明暗"
                romaji: "Meian"
            }

            HMSection {
                title: "Status"

                HMRow {
                    label: "Enable Smart Dim"
                    description: "Adjust brightness automatically based on the active window's "
                               + "class and your battery state."
                    icon: "\uf185"
                    separator: true

                    HMSwitch {
                        checked: SmartDimService.enabled
                        onToggled: SmartDimService.enabled = checked
                    }
                }

                HMRow {
                    label: "Baseline brightness"
                    description: "Snapshotted when Smart Dim is first enabled. Re-snapshot "
                               + "if you want a different default. Current: "
                               + (SmartDimService.baselineBrightness > 0
                                  ? SmartDimService.baselineBrightness + "%"
                                  : "(not set yet)")
                    icon: "\uf109"
                    separator: true

                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 26
                        radius: 6
                        color: ThemeService.alpha(ThemeService.blue, 0.18)
                        border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                        border.width: 1
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "Re-snapshot"
                            color: ThemeService.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SmartDimService.resnapshotBaseline()
                        }
                    }
                }

                HMRow {
                    label: "Active rule"
                    description: "Which rule is currently matching the active window."
                    icon: "\uf05a"

                    Rectangle {
                        Layout.preferredWidth: ruleText.implicitWidth + 16
                        Layout.preferredHeight: 22
                        radius: 11
                        color: SmartDimService.activeRuleName !== "none"
                               ? ThemeService.alpha(ThemeService.blue, 0.25)
                               : ThemeService.alpha(ThemeService.fg, 0.10)

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            id: ruleText
                            anchors.centerIn: parent
                            text: SmartDimService.activeRuleName
                            color: SmartDimService.activeRuleName !== "none"
                                   ? ThemeService.blue
                                   : ThemeService.alpha(ThemeService.fg, 0.6)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            HMSection {
                title: "Rules (" + SmartDimService.rules.length + ")"
                subtitle: "Rules are evaluated by priority — highest match wins. Edit the "
                        + "JSON config directly at ~/.config/quickshell/zen-shell/smart-dim.json "
                        + "for fine-grained tuning."

                Repeater {
                    model: SmartDimService.rules

                    HMRow {
                        label: modelData.name
                        description: {
                            var s = ""
                            if (modelData.kind === "absolute") {
                                s = "Set brightness to " + modelData.value + "%"
                            } else {
                                s = "Offset baseline by " + (modelData.value >= 0 ? "+" : "")
                                  + modelData.value + "%"
                            }
                            if (modelData.fullscreenRequired) s += " · fullscreen"
                            if (modelData.requireBattery) s += " · battery < " + modelData.batteryBelow + "%"
                            if (modelData.requireGameActive) s += " · game active"
                            s += " · priority " + modelData.priority
                            return s
                        }
                        icon: "\uf022"
                        separator: index < SmartDimService.rules.length - 1

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 22
                            radius: 11
                            color: SmartDimService.activeRuleName === modelData.name
                                   ? ThemeService.alpha(ThemeService.green || "#98c379", 0.4)
                                   : ThemeService.alpha(ThemeService.fg, 0.10)

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                anchors.centerIn: parent
                                text: SmartDimService.activeRuleName === modelData.name ? "●" : ""
                                color: ThemeService.green || "#98c379"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
