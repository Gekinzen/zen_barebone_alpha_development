import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * DesktopFolderPopup v7.0.0-beta.1-hf82w
 *
 * squircle-style folder grid popup. Opens when a folder icon
 * is tapped. Shows the folder's members in a tight grid (4 columns),
 * with rename + delete actions in the header. Closes on outside click
 * or Esc.
 *
 * Long-press an icon inside → drag back to desktop area below the
 * popup → removes from folder (handled by detecting drop below the
 * popup's bottom edge).
 *
 * Architecture:
 *   - Modal Dialog, centered in Overlay.overlay
 *   - Editable folder name in header (click to rename)
 *   - GridLayout of DesktopIcon instances using the same render logic
 *     as desktop (Squircle style applied)
 *   - Outside-click closes via Dialog's standard modal behavior
 */
Dialog {
    id: root

    property string folderId: ""

    // Cached folder ref — refreshes when folderId changes
    property var folder: folderId.length > 0
        ? DesktopFoldersState.folderForMember(_anyMember()) || _findById()
        : null

    // Members resolved to entry objects (lookup against DesktopIconsService)
    readonly property var memberEntries: {
        if (!folder || !folder.members) return []
        const all = DesktopIconsService.entries || []
        const out = []
        for (let i = 0; i < folder.members.length; i++) {
            for (let j = 0; j < all.length; j++) {
                if (all[j].name === folder.members[i]) {
                    out.push(all[j])
                    break
                }
            }
        }
        return out
    }

    function _findById() {
        const all = DesktopFoldersState.folders || []
        for (let i = 0; i < all.length; i++) {
            if (all[i].id === folderId) return all[i]
        }
        return null
    }
    function _anyMember() {
        const f = _findById()
        if (f && f.members && f.members.length > 0) return f.members[0]
        return ""
    }

    title: ""
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 480

    background: Rectangle {
        color: Qt.rgba(0.10, 0.10, 0.12, 0.96)
        radius: 28
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 16

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true

            TextField {
                id: nameField
                Layout.fillWidth: true
                text: root.folder ? (root.folder.name || "Folder") : ""
                font.pixelSize: 18
                font.bold: true
                color: "#ffffff"
                background: Rectangle {
                    color: nameField.activeFocus
                        ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.color: nameField.activeFocus
                        ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                    border.width: 1
                    radius: 6
                }
                placeholderText: "Folder name"
                onEditingFinished: {
                    if (root.folderId && text.length > 0 && text !== root.folder.name) {
                        DesktopFoldersState.renameFolder(root.folderId, text)
                    }
                }
            }

            // Delete folder button
            Rectangle {
                width: 32; height: 32; radius: 16
                color: deleteMa.containsMouse
                    ? Qt.rgba(0.85, 0.30, 0.30, 0.35)
                    : Qt.rgba(1, 1, 1, 0.06)
                Text {
                    anchors.centerIn: parent
                    text: "\uf2ed"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#ffffff"
                }
                MouseArea {
                    id: deleteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Confirm via window opacity flash then delete
                        if (root.folderId) {
                            DesktopFoldersState.deleteFolder(root.folderId)
                            root.close()
                        }
                    }
                }
            }
        }

        // ── Icon grid (4 columns, tight) ──
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 12
            rowSpacing: 12

            Repeater {
                model: root.memberEntries

                delegate: Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 110
                    color: cellMa.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    radius: 12

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        // Icon — uses same lookup as DesktopIcon (taskbar pattern)
                        Image {
                            width: 56; height: 56
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: {
                                const n = modelData.iconName || modelData.icon || ""
                                if (n && n.charAt(0) === "/") return "file://" + n
                                if (n && Quickshell.iconPath) {
                                    const themed = Quickshell.iconPath(n, true)
                                    if (themed && themed.length > 0) return themed
                                }
                                const base = (modelData.name || "")
                                    .replace(/\.desktop$/, "").toLowerCase()
                                if (base && Quickshell.iconPath) {
                                    return Quickshell.iconPath(base, true) || ""
                                }
                                return ""
                            }
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            width: 88
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (modelData.name || "")
                                .replace(/\.desktop$/, "")
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.pixelSize: 10
                            color: "#dddddd"
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Tap to launch
                        onClicked: {
                            if (parent.modelData.isDesktopFile) {
                                launchProc.command =
                                    ["gtk-launch", parent.modelData.name.replace(/\.desktop$/, "")]
                                launchProc.running = false
                                launchProc.running = true
                            } else {
                                openProc.command = ["xdg-open", parent.modelData.path]
                                openProc.running = false
                                openProc.running = true
                            }
                            root.close()
                        }
                        // Right-click to remove from folder
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressed: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                DesktopFoldersState.removeFromFolder(
                                    root.folderId, parent.modelData.name)
                            }
                        }
                    }
                }
            }
        }

        // Tip text
        Text {
            Layout.fillWidth: true
            text: "Tap to open  ·  Right-click to remove from folder"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Launch helpers
    Process { id: launchProc; running: false }
    Process { id: openProc; running: false }
}
