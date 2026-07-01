import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * QuickNotesPage v7.0.0-beta.1-hf39 — Settings page for Quick Notes.
 *
 * Most interaction lives in the QuickNotesPanel popover (open via bar
 * module or hot corner). This Settings page covers:
 *   - Notes directory location
 *   - Total count + storage size
 *   - Re-scan / refresh button
 *   - Delete all notes (with confirm)
 *   - Auto-open new note on Super+N (info / requires hyprland bind)
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
                title: "Quick Notes"
                subtitle: "Markdown scratchpad with auto-save + pin-to-top"
                kanji: "覚書"
                romaji: "Oboegaki"
            }

            HMSection {
                title: "Library"
                subtitle: "Where your notes live on disk."

                HMRow {
                    label: "Notes directory"
                    description: QuickNotesService.notesDir
                    icon: "\uf07b"
                    separator: true

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 26
                        radius: 6
                        color: ThemeService.alpha(ThemeService.blue, 0.18)
                        border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Open"
                            color: ThemeService.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached({command:
                                ["xdg-open", QuickNotesService.notesDir]})
                        }
                    }
                }

                HMRow {
                    label: "Total notes"
                    description: "Including pinned and sticky."
                    icon: "\uf249"
                    separator: true

                    Text {
                        text: QuickNotesService.totalCount() + " note"
                              + (QuickNotesService.totalCount() === 1 ? "" : "s")
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }

                HMRow {
                    label: "Sticky notes"
                    description: "Pinned-to-screen floating windows."
                    icon: "\uf005"

                    Text {
                        text: QuickNotesService.stickyCount() + ""
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }

            HMSection {
                title: "Actions"
                subtitle: "Quick operations on your notes library."

                HMRow {
                    label: "Create new note"
                    description: "Opens a new blank note in the editor."
                    icon: "\uf067"
                    separator: true

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 26
                        radius: 6
                        color: ThemeService.alpha(ThemeService.green || "#98c379", 0.18)
                        border.color: ThemeService.alpha(ThemeService.green || "#98c379", 0.4)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "New note"
                            color: ThemeService.green || "#98c379"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                QuickNotesService.createNote()
                                PanelState.quickNotesVisible = true
                            }
                        }
                    }
                }

                HMRow {
                    label: "Refresh from disk"
                    description: "Re-scan the notes directory. Useful if you edited "
                               + "files externally (e.g. via vim)."
                    icon: "\uf021"

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 26
                        radius: 6
                        color: ThemeService.alpha(ThemeService.fg, 0.10)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.3)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Re-scan"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: QuickNotesService._scan()
                        }
                    }
                }
            }

            HMSection {
                title: "Hotkeys"
                subtitle: "Auto-installed by Zen Shell installer. Tweak in "
                        + "~/.config/hypr/modules/keybinds-update.conf."

                HMRow {
                    label: "Toggle Quick Notes panel"
                    description: "Opens the popover. If no current note, "
                               + "one is auto-created so you can start typing immediately."
                    icon: "\uf11c"
                    separator: true

                    Rectangle {
                        Layout.preferredWidth: kbdToggle.implicitWidth + 16
                        Layout.preferredHeight: 24
                        radius: 4
                        color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.7)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                        border.width: 1
                        Text {
                            id: kbdToggle
                            anchors.centerIn: parent
                            text: "Super + Shift + N"
                            color: ThemeService.fg
                            font.family: "monospace"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                HMRow {
                    label: "Create new note + open"
                    description: "ALWAYS creates a fresh note then opens panel. "
                               + "Useful for quick capture without selecting first."
                    icon: "\uf067"
                    separator: true

                    Rectangle {
                        Layout.preferredWidth: kbdNew.implicitWidth + 16
                        Layout.preferredHeight: 24
                        radius: 4
                        color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.7)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                        border.width: 1
                        Text {
                            id: kbdNew
                            anchors.centerIn: parent
                            text: "Super + Alt + N"
                            color: ThemeService.fg
                            font.family: "monospace"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                HMRow {
                    label: "Why not Super+N?"
                    description: "Super+N is reserved by your keybinds-update.conf for "
                               + "wifi-toggle.sh. Zen Shell uses Super+Shift+N to avoid "
                               + "the conflict. Free Super+N if you want by editing that file."
                    icon: "\uf059"

                    Text {
                        text: "ⓘ"
                        color: ThemeService.alpha(ThemeService.fg, 0.6)
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
