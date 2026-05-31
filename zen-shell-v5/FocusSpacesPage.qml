import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * FocusSpacesPage v7.0.0-beta.1-hf39 — Settings page for Focus Spaces.
 *
 * Lists all saved spaces. Per row: name, window count, restore button,
 * update-snapshot button, delete button. Save-current-as button at top.
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
                title: "Focus Spaces"
                subtitle: "Save and restore per-app workspace layouts"
                kanji: "領域"
                romaji: "Ryōiki"
            }

            HMSection {
                title: "Save current layout"
                subtitle: "Captures all open windows with positions + workspace assignments."

                HMRow {
                    label: "New Focus Space"
                    description: "Pick a name then capture the current layout."
                    icon: "\uf067"

                    RowLayout {
                        spacing: 6

                        TextField {
                            id: nameField
                            Layout.preferredWidth: 140
                            placeholderText: "e.g. Coding, Email…"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fg
                            background: Rectangle {
                                radius: 4
                                color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.6)
                                border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                                border.width: 1
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 26
                            radius: 6
                            color: ThemeService.alpha(ThemeService.green || "#98c379", 0.18)
                            border.color: ThemeService.alpha(ThemeService.green || "#98c379", 0.4)
                            border.width: 1
                            opacity: nameField.text.trim().length > 0 ? 1 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: ThemeService.green || "#98c379"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: nameField.text.trim().length > 0
                                onClicked: {
                                    FocusSpacesService.saveCurrentAs(
                                        nameField.text.trim(), "", "")
                                    nameField.text = ""
                                }
                            }
                        }
                    }
                }
            }

            HMSection {
                title: "Saved Spaces (" + FocusSpacesService.count() + ")"
                subtitle: FocusSpacesService.count() === 0
                          ? "No spaces saved yet. Save one above."
                          : "Click a space name to restore it."

                Repeater {
                    model: FocusSpacesService.spaces

                    HMRow {
                        label: modelData.name
                        description: (modelData.windows ? modelData.windows.length : 0)
                                   + " windows · captured "
                                   + new Date(modelData.created * 1000).toLocaleDateString()
                        icon: modelData.icon || "\uf2bb"
                        separator: index < FocusSpacesService.count() - 1

                        RowLayout {
                            spacing: 6

                            Rectangle {
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 24
                                radius: 5
                                color: FocusSpacesService.activeSpaceId === modelData.id
                                       ? ThemeService.alpha(ThemeService.blue, 0.4)
                                       : ThemeService.alpha(ThemeService.blue, 0.18)
                                border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Restore"
                                    color: ThemeService.blue
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: FocusSpacesService.restoreSpace(modelData.id)
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 24
                                radius: 5
                                color: ThemeService.alpha(ThemeService.fg, 0.10)
                                border.color: ThemeService.alpha(ThemeService.fg, 0.25)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Update"
                                    color: ThemeService.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: FocusSpacesService.updateExisting(modelData.id)
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 24
                                radius: 5
                                color: ThemeService.alpha(ThemeService.red || "#e06c75", 0.15)
                                border.color: ThemeService.alpha(ThemeService.red || "#e06c75", 0.4)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf2ed"
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 10
                                    color: ThemeService.red || "#e06c75"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: FocusSpacesService.deleteSpace(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
