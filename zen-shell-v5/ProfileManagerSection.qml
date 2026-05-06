import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * ProfileManagerSection v6.16.4.12 — Hikari 光
 *
 * UI component for the top of GeneralPage. Provides:
 *   - Active profile indicator
 *   - Save current state as profile (with zenity name prompt)
 *   - Profile list with Activate / Rename / Delete actions
 *   - Import from file (zenity file picker)
 *   - Export to file (copy to ~/Downloads or user-chosen path)
 *
 * Uses UserProfileExportService singleton as backend.
 */
ColumnLayout {
    id: profileRoot
    Layout.fillWidth: true
    spacing: 0

    // Zenity name prompt for saving
    Process {
        id: saveNamePrompt
        running: false
        command: ["bash", "-c",
            "if command -v zenity >/dev/null 2>&1; then " +
            "  zenity --entry --title='Save Profile' " +
            "    --text='Name your profile:' " +
            "    --entry-text='My Setup' 2>/dev/null; " +
            "else echo 'my-setup'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim()
                if (name.length > 0) UserProfileExportService.exportProfile(name)
            }
        }
    }

    // Zenity file picker for import
    Process {
        id: importFilePicker
        running: false
        command: ["bash", "-c",
            "zenity --file-selection --title='Import Profile' " +
            "  --file-filter='Zen Profiles|*.json' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim()
                if (path.length > 0) UserProfileExportService.importProfile(path)
            }
        }
    }

    // Export to Downloads
    Process { id: exportCopier; running: false }

    HMSection {
        title: "Profiles"
        subtitle: "Save, load, and share your entire shell configuration"

        // ── Active profile indicator ──
        HMRow {
            label: "Active Profile"
            description: UserProfileExportService.activeProfileName || "default"
            icon: "\udb80\udc04"
            separator: true

            RowLayout {
                spacing: 8

                // Save current
                Rectangle {
                    width: saveL.implicitWidth + 20; height: 30; radius: 6
                    color: saveMa.containsMouse ? ThemeService.alpha(ThemeService.green, 0.2) : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.green, 0.3)
                    Text { id: saveL; anchors.centerIn: parent; text: "\udb80\udd93  Save"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.green }
                    MouseArea { id: saveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: saveNamePrompt.running = true
                    }
                }

                // Quick overwrite current
                Rectangle {
                    width: overL.implicitWidth + 20; height: 30; radius: 6
                    color: overMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.2) : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.blue, 0.2)
                    Text { id: overL; anchors.centerIn: parent; text: "\udb81\udc50  Overwrite"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.blue }
                    MouseArea { id: overMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: UserProfileExportService.exportProfile(UserProfileExportService.activeProfileName)
                    }
                }
            }
        }

        // ── Import / Export buttons ──
        HMRow {
            label: "Share"
            description: "Import from file or export to ~/Downloads"
            icon: "\udb81\udc97"
            separator: true

            RowLayout {
                spacing: 8
                Rectangle {
                    width: impL.implicitWidth + 20; height: 30; radius: 6
                    color: impMa.containsMouse ? ThemeService.alpha(ThemeService.purple, 0.2) : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.purple, 0.2)
                    Text { id: impL; anchors.centerIn: parent; text: "\udb83\udfaa  Import"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.purple }
                    MouseArea { id: impMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: importFilePicker.running = true
                    }
                }
                Rectangle {
                    width: expL.implicitWidth + 20; height: 30; radius: 6
                    color: expMa.containsMouse ? ThemeService.alpha(ThemeService.orange, 0.2) : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.orange, 0.2)
                    Text { id: expL; anchors.centerIn: parent; text: "\udb83\udfab  Export"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.orange }
                    MouseArea { id: expMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const src = UserProfileExportService.profileDir + "/" + UserProfileExportService.activeProfileName + ".json"
                            const dst = Quickshell.env("HOME") + "/Downloads/" + UserProfileExportService.activeProfileName + "-profile.json"
                            exportCopier.command = ["cp", src, dst]
                            exportCopier.running = true
                            UserProfileExportService.statusMessage = "✓ Exported to ~/Downloads/"
                        }
                    }
                }
            }
        }

        // ── Profile list ──
        Repeater {
            model: UserProfileExportService.profileList

            HMRow {
                required property string modelData
                required property int index

                label: modelData
                description: modelData === UserProfileExportService.activeProfileName ? "● Active" : ""
                icon: modelData === UserProfileExportService.activeProfileName ? "\udb80\udcce" : "\udb80\udd9f"
                separator: index < UserProfileExportService.profileList.length - 1

                RowLayout {
                    spacing: 6

                    // Activate
                    Rectangle {
                        visible: modelData !== UserProfileExportService.activeProfileName
                        width: actL.implicitWidth + 16; height: 26; radius: 5
                        color: actMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.2) : ThemeService.alpha(ThemeService.bg2, 0.4)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.blue, 0.15)
                        Text { id: actL; anchors.centerIn: parent; text: "Activate"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.blue }
                        MouseArea { id: actMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: UserProfileExportService.loadProfile(modelData)
                        }
                    }

                    // Delete (not for "default")
                    Rectangle {
                        visible: modelData !== "default"
                        width: delL.implicitWidth + 16; height: 26; radius: 5
                        color: delMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.2) : "transparent"
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.red, 0.15)
                        Text { id: delL; anchors.centerIn: parent; text: "\udb80\udc6c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.red }
                        MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: UserProfileExportService.deleteProfile(modelData)
                        }
                    }
                }
            }
        }

        // ── Status message ──
        Text {
            visible: UserProfileExportService.statusMessage.length > 0
            text: UserProfileExportService.statusMessage
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: UserProfileExportService.statusMessage.startsWith("✓") ? ThemeService.green : ThemeService.yellow
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4

            // Auto-clear after 4 seconds
            Timer {
                running: parent.visible
                interval: 4000
                onTriggered: UserProfileExportService.statusMessage = ""
            }
        }
    }
}
