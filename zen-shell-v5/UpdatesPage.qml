import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell

/*
 * UpdatesPage v7.0.0-alpha.1 — Settings → System → Updates
 *
 * UI for ZenUpdateService:
 *   - Current version + channel + codename header card
 *   - "Check for updates" button + last-checked timestamp
 *   - Update-available banner card (when applicable) with Install button
 *   - Auto-check toggle + interval selector
 *   - Update channel selector (Stable / Beta / Alpha)
 *   - Snapshots list with Restore / Pin / Delete per row
 *   - Status footer (last action, last message)
 *
 * Mirrors the visual conventions of GeneralPage / DecorationPage:
 * SettingsSection containers, SettingRow for each control, ColorSwatch /
 * NumericStepper / ZenComboBox for inputs.
 *
 * Wala tayong babawasan — page is purely additive. Removing it is safe
 * (no other surface depends on it).
 */
Item {
    id: root

    // Inner content with consistent padding (ZenSettings clamps width to 1100)
    ScrollView {
        anchors.fill: parent
        anchors.topMargin: 24
        anchors.bottomMargin: 24
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: root.width - 48
            spacing: 16

            // ═══════════════════════════════════════════════
            // CURRENT VERSION HEADER
            // ═══════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: 12
                color: ThemeService.alpha(ThemeService.bg1, 0.6)
                border.color: ThemeService.alpha(ThemeService.fg, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 16

                    // Channel badge dot
                    Rectangle {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        radius: 6
                        color: {
                            switch (ZenVersion.channel) {
                                case "stable": return ThemeService.green
                                case "beta":   return ThemeService.blue
                                default:       return ThemeService.orange
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: ZenVersion.version + "  ·  " + ZenVersion.codename +
                                  " (" + ZenVersion.codenameKanji + ")"
                            color: ThemeService.fg
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Text {
                            text: ZenVersion.channel.toUpperCase() + "  ·  released " +
                                  ZenVersion.releaseDate
                            color: ThemeService.grey1
                            font.pixelSize: 12
                        }
                    }

                    Button {
                        id: checkButton
                        text: ZenUpdateService.checking ? "Checking…" : "Check for updates"
                        enabled: !ZenUpdateService.checking
                        onClicked: ZenUpdateService.checkForUpdates()

                        background: Rectangle {
                            radius: 8
                            color: checkButton.hovered
                                ? ThemeService.alpha(ThemeService.blue, 0.85)
                                : ThemeService.blue
                        }
                        contentItem: Text {
                            text: checkButton.text
                            color: ThemeService.bg0
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 14; rightPadding: 14
                            topPadding: 8;   bottomPadding: 8
                        }
                    }
                }
            }

            // Last checked + error line
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: {
                    if (ZenUpdateService.lastCheckError)
                        return "⚠  " + ZenUpdateService.lastCheckError
                    if (ZenUpdateService.lastChecked)
                        return "Last checked: " + ZenUpdateService.relativeAge(ZenUpdateService.lastChecked)
                    return "Never checked"
                }
                color: ZenUpdateService.lastCheckError
                       ? ThemeService.red
                       : ThemeService.grey1
                font.pixelSize: 11
            }

            // ═══════════════════════════════════════════════
            // UPDATE-AVAILABLE BANNER (conditional)
            // ═══════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? bannerCol.implicitHeight + 32 : 0
                visible: ZenUpdateService.updateAvailable
                radius: 12
                color: ThemeService.alpha(ThemeService.green, 0.12)
                border.color: ThemeService.alpha(ThemeService.green, 0.4)
                border.width: 1

                ColumnLayout {
                    id: bannerCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "\uf062"  // arrow-up nerd icon
                            color: ThemeService.green
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 18
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Update available — " + ZenUpdateService.latestVersion
                            color: ThemeService.fg
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Button {
                            id: installBtn
                            text: ZenUpdateService.lastUpdateStatus === "running" &&
                                  ZenUpdateService.lastUpdateAction === "install"
                                  ? "Installing…" : "Install update"
                            enabled: ZenUpdateService.lastUpdateStatus !== "running"
                            onClicked: confirmInstallDialog.open()
                            background: Rectangle {
                                radius: 8
                                color: installBtn.hovered
                                    ? ThemeService.alpha(ThemeService.green, 0.85)
                                    : ThemeService.green
                            }
                            contentItem: Text {
                                text: installBtn.text
                                color: ThemeService.bg0
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12; rightPadding: 12
                                topPadding: 6;   bottomPadding: 6
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: ZenUpdateService.latestReleaseDate
                              ? "Released " + ZenUpdateService.latestReleaseDate
                              : ""
                        color: ThemeService.grey1
                        font.pixelSize: 11
                        visible: text.length > 0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: ZenUpdateService.latestReleaseNotes
                        color: ThemeService.fg
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 6
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }

            // ═══════════════════════════════════════════════
            // UPDATE PREFERENCES
            // ═══════════════════════════════════════════════
            SettingsSection {
                Layout.fillWidth: true
                title: "Update preferences"

                SettingRow {
                    label: "Check automatically"
                    description: "Background check every " +
                                 ZenUpdateService.autoCheckIntervalHours + "h"
                    // hf82j: was Qt's plain `Switch` (ugly platform-native
                    // look); now uses the project-standard HMSwitch pill
                    // toggle that matches General / Battery / Widgets / etc.
                    HMSwitch {
                        checked: ZenUpdateService.autoCheckEnabled
                        onToggled: ZenUpdateService.autoCheckEnabled = checked
                    }
                }

                SettingRow {
                    label: "Check interval (hours)"
                    description: "Lower = more frequent. Throttled to interval/2 minimum."
                    enabled: ZenUpdateService.autoCheckEnabled

                    NumericStepper {
                        value: ZenUpdateService.autoCheckIntervalHours
                        from: 1
                        to: 168
                        stepSize: 1
                        onValueChanged: ZenUpdateService.autoCheckIntervalHours = value
                    }
                }

                SettingRow {
                    label: "Update channel"
                    description: "Alpha = bleeding edge · Beta = candidate · Stable = tagged release"

                    Row {
                        spacing: 6
                        Repeater {
                            model: ["stable", "beta", "alpha"]
                            delegate: Rectangle {
                                width: 78
                                height: 30
                                radius: 8
                                color: ZenUpdateService.preferredChannel === modelData
                                    ? ThemeService.blue
                                    : ThemeService.alpha(ThemeService.bg2, 0.6)
                                border.color: ZenUpdateService.preferredChannel === modelData
                                    ? "transparent"
                                    : ThemeService.alpha(ThemeService.fg, 0.1)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                    color: ZenUpdateService.preferredChannel === modelData
                                        ? ThemeService.bg0 : ThemeService.fg
                                    font.pixelSize: 12
                                    font.bold: ZenUpdateService.preferredChannel === modelData
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ZenUpdateService.preferredChannel = modelData
                                }
                            }
                        }
                    }
                }

                SettingRow {
                    label: "Snapshot before installing"
                    description: "Create a rollback point automatically before each update"
                    // hf82j: HMSwitch (was Qt platform Switch).
                    HMSwitch {
                        checked: ZenUpdateService.autoSnapshotBeforeUpdate
                        onToggled: ZenUpdateService.autoSnapshotBeforeUpdate = checked
                    }
                }

                SettingRow {
                    label: "Keep snapshots"
                    description: "Older unpinned snapshots auto-pruned beyond this count"

                    NumericStepper {
                        value: ZenUpdateService.maxSnapshotsRetained
                        from: 1
                        to: 20
                        stepSize: 1
                        onValueChanged: ZenUpdateService.maxSnapshotsRetained = value
                    }
                }
            }

            // ═══════════════════════════════════════════════
            // SNAPSHOTS / ROLLBACK
            // ═══════════════════════════════════════════════
            SettingsSection {
                Layout.fillWidth: true
                title: "Snapshots & rollback"

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: ZenUpdateService.snapshots.length + " snapshot" +
                              (ZenUpdateService.snapshots.length === 1 ? "" : "s") +
                              " · stored at ~/.local/share/zen-shell/snapshots/"
                        color: ThemeService.grey1
                        font.pixelSize: 11
                    }

                    Button {
                        id: snapNowBtn
                        text: "Snapshot now"
                        enabled: ZenUpdateService.lastUpdateStatus !== "running"
                        onClicked: ZenUpdateService.createSnapshot("manual")
                        background: Rectangle {
                            radius: 8
                            color: snapNowBtn.hovered
                                ? ThemeService.alpha(ThemeService.bg2, 0.9)
                                : ThemeService.alpha(ThemeService.bg2, 0.6)
                            border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                            border.width: 1
                        }
                        contentItem: Text {
                            text: snapNowBtn.text
                            color: ThemeService.fg
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 12; rightPadding: 12
                            topPadding: 6;   bottomPadding: 6
                        }
                    }

                    Button {
                        id: refreshBtn
                        text: "↻"
                        onClicked: ZenUpdateService.refreshSnapshots()
                        background: Rectangle {
                            radius: 8
                            color: refreshBtn.hovered
                                ? ThemeService.alpha(ThemeService.bg2, 0.9)
                                : ThemeService.alpha(ThemeService.bg2, 0.6)
                            border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                            border.width: 1
                        }
                        contentItem: Text {
                            text: refreshBtn.text
                            color: ThemeService.fg
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10; rightPadding: 10
                            topPadding: 6;   bottomPadding: 6
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    visible: ZenUpdateService.snapshots.length === 0
                    radius: 10
                    color: ThemeService.alpha(ThemeService.bg2, 0.3)
                    border.color: ThemeService.alpha(ThemeService.fg, 0.06)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "No snapshots yet — run install.sh or click \"Snapshot now\""
                        color: ThemeService.grey1
                        font.pixelSize: 12
                    }
                }

                // Snapshot rows
                Repeater {
                    model: ZenUpdateService.snapshots
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: 10
                        color: rowMA.containsMouse
                            ? ThemeService.alpha(ThemeService.bg2, 0.8)
                            : ThemeService.alpha(ThemeService.bg2, 0.5)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.08)
                        border.width: 1

                        MouseArea {
                            id: rowMA
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 12

                            // Pin badge column
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: modelData.pinned ? ThemeService.yellow : "transparent"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: (modelData.version || "?") +
                                          (modelData.codename ? "  ·  " + modelData.codename : "") +
                                          (modelData.channel ? "  ·  " + modelData.channel : "")
                                    color: ThemeService.fg
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: ZenUpdateService.relativeAge(modelData.timestamp) +
                                          "  ·  " + ZenUpdateService.formatBytes(modelData.sizeBytes || 0)
                                    color: ThemeService.grey1
                                    font.pixelSize: 11
                                }
                            }

                            // Restore button
                            Button {
                                id: restoreBtn
                                text: "Restore"
                                enabled: ZenUpdateService.lastUpdateStatus !== "running"
                                onClicked: {
                                    confirmRestoreDialog.snapshotPath = modelData.path
                                    confirmRestoreDialog.snapshotVersion = modelData.version
                                    confirmRestoreDialog.open()
                                }
                                background: Rectangle {
                                    radius: 6
                                    color: restoreBtn.hovered
                                        ? ThemeService.alpha(ThemeService.blue, 0.85)
                                        : ThemeService.alpha(ThemeService.blue, 0.7)
                                }
                                contentItem: Text {
                                    text: restoreBtn.text
                                    color: ThemeService.bg0
                                    font.pixelSize: 11
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 10; rightPadding: 10
                                    topPadding: 5;   bottomPadding: 5
                                }
                            }

                            // Pin / unpin button
                            Button {
                                id: pinBtn
                                text: modelData.pinned ? "Unpin" : "Pin"
                                enabled: ZenUpdateService.lastUpdateStatus !== "running"
                                onClicked: ZenUpdateService.pinSnapshot(modelData.path,
                                                                        !modelData.pinned)
                                background: Rectangle {
                                    radius: 6
                                    color: pinBtn.hovered
                                        ? ThemeService.alpha(ThemeService.bg1, 0.95)
                                        : ThemeService.alpha(ThemeService.bg1, 0.7)
                                    border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                                    border.width: 1
                                }
                                contentItem: Text {
                                    text: pinBtn.text
                                    color: ThemeService.fg
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 10; rightPadding: 10
                                    topPadding: 5;   bottomPadding: 5
                                }
                            }

                            // Delete button
                            Button {
                                id: delBtn
                                text: "Delete"
                                enabled: !modelData.pinned &&
                                         ZenUpdateService.lastUpdateStatus !== "running"
                                onClicked: {
                                    confirmDeleteDialog.snapshotPath = modelData.path
                                    confirmDeleteDialog.snapshotVersion = modelData.version
                                    confirmDeleteDialog.open()
                                }
                                background: Rectangle {
                                    radius: 6
                                    color: delBtn.hovered && delBtn.enabled
                                        ? ThemeService.alpha(ThemeService.red, 0.85)
                                        : ThemeService.alpha(ThemeService.red, 0.5)
                                    opacity: delBtn.enabled ? 1.0 : 0.4
                                }
                                contentItem: Text {
                                    text: delBtn.text
                                    color: ThemeService.bg0
                                    font.pixelSize: 11
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 10; rightPadding: 10
                                    topPadding: 5;   bottomPadding: 5
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════
            // STATUS FOOTER
            // ═══════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 40 : 0
                visible: ZenUpdateService.lastUpdateMessage.length > 0
                radius: 8
                color: {
                    switch (ZenUpdateService.lastUpdateStatus) {
                        case "success": return ThemeService.alpha(ThemeService.green, 0.15)
                        case "failure": return ThemeService.alpha(ThemeService.red, 0.15)
                        case "running": return ThemeService.alpha(ThemeService.blue, 0.15)
                        default:        return ThemeService.alpha(ThemeService.bg2, 0.5)
                    }
                }
                border.color: {
                    switch (ZenUpdateService.lastUpdateStatus) {
                        case "success": return ThemeService.alpha(ThemeService.green, 0.4)
                        case "failure": return ThemeService.alpha(ThemeService.red, 0.4)
                        case "running": return ThemeService.alpha(ThemeService.blue, 0.4)
                        default:        return ThemeService.alpha(ThemeService.fg, 0.1)
                    }
                }
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    Text {
                        text: {
                            switch (ZenUpdateService.lastUpdateStatus) {
                                case "success": return "✓"
                                case "failure": return "✗"
                                case "running": return "⟳"
                                default:        return "·"
                            }
                        }
                        color: {
                            switch (ZenUpdateService.lastUpdateStatus) {
                                case "success": return ThemeService.green
                                case "failure": return ThemeService.red
                                case "running": return ThemeService.blue
                                default:        return ThemeService.grey1
                            }
                        }
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: ZenUpdateService.lastUpdateMessage
                        color: ThemeService.fg
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // CONFIRMATION DIALOGS
    // ═══════════════════════════════════════════════════════════

    Dialog {
        id: confirmInstallDialog
        modal: true
        anchors.centerIn: parent
        width: 420
        title: "Install update?"
        standardButtons: Dialog.NoButton

        background: Rectangle {
            radius: 12
            color: ThemeService.bg1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "Install " + ZenUpdateService.latestVersion + "?"
                color: ThemeService.fg
                font.pixelSize: 16
                font.bold: true
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: ZenUpdateService.autoSnapshotBeforeUpdate
                    ? "A snapshot of your current install will be created first. " +
                      "You can roll back any time."
                    : "⚠  Snapshot-before-update is OFF. Rollback will not be available."
                color: ZenUpdateService.autoSnapshotBeforeUpdate
                    ? ThemeService.grey1 : ThemeService.yellow
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancel"
                    onClicked: confirmInstallDialog.close()
                    background: Rectangle {
                        radius: 8
                        color: ThemeService.alpha(ThemeService.bg2, 0.7)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text; color: ThemeService.fg
                        font.pixelSize: 12
                        leftPadding: 14; rightPadding: 14
                        topPadding: 6; bottomPadding: 6
                    }
                }
                Button {
                    text: "Install"
                    onClicked: {
                        ZenUpdateService.installLatest()
                        confirmInstallDialog.close()
                    }
                    background: Rectangle {
                        radius: 8
                        color: ThemeService.green
                    }
                    contentItem: Text {
                        text: parent.text; color: ThemeService.bg0
                        font.pixelSize: 12; font.bold: true
                        leftPadding: 14; rightPadding: 14
                        topPadding: 6; bottomPadding: 6
                    }
                }
            }
        }
    }

    Dialog {
        id: confirmRestoreDialog
        modal: true
        anchors.centerIn: parent
        width: 440
        property string snapshotPath: ""
        property string snapshotVersion: ""

        background: Rectangle {
            radius: 12
            color: ThemeService.bg1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "Restore " + confirmRestoreDialog.snapshotVersion + "?"
                color: ThemeService.fg
                font.pixelSize: 16
                font.bold: true
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: "Your current installation will be snapshotted first as a safety net, " +
                      "then the selected snapshot will be restored. Shell restart required."
                color: ThemeService.grey1
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancel"
                    onClicked: confirmRestoreDialog.close()
                    background: Rectangle {
                        radius: 8
                        color: ThemeService.alpha(ThemeService.bg2, 0.7)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text; color: ThemeService.fg
                        font.pixelSize: 12
                        leftPadding: 14; rightPadding: 14
                        topPadding: 6; bottomPadding: 6
                    }
                }
                Button {
                    text: "Restore"
                    onClicked: {
                        ZenUpdateService.rollbackTo(confirmRestoreDialog.snapshotPath)
                        confirmRestoreDialog.close()
                    }
                    background: Rectangle {
                        radius: 8
                        color: ThemeService.blue
                    }
                    contentItem: Text {
                        text: parent.text; color: ThemeService.bg0
                        font.pixelSize: 12; font.bold: true
                        leftPadding: 14; rightPadding: 14
                        topPadding: 6; bottomPadding: 6
                    }
                }
            }
        }
    }

    Dialog {
        id: confirmDeleteDialog
        modal: true
        anchors.centerIn: parent
        width: 400
        property string snapshotPath: ""
        property string snapshotVersion: ""

        background: Rectangle {
            radius: 12
            color: ThemeService.bg1
            border.color: ThemeService.alpha(ThemeService.red, 0.3)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "Delete snapshot " + confirmDeleteDialog.snapshotVersion + "?"
                color: ThemeService.fg
                font.pixelSize: 16
                font.bold: true
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: "This cannot be undone. Pin the snapshot first if you want to protect it."
                color: ThemeService.grey1
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancel"
                    onClicked: confirmDeleteDialog.close()
                    background: Rectangle {
                        radius: 8
                        color: ThemeService.alpha(ThemeService.bg2, 0.7)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text; color: ThemeService.fg
                        font.pixelSize: 12
                        leftPadding: 14; rightPadding: 14
                        topPadding: 6; bottomPadding: 6
                    }
                }
                Button {
                    text: "Delete"
                    onClicked: {
                        ZenUpdateService.deleteSnapshot(confirmDeleteDialog.snapshotPath)
                        confirmDeleteDialog.close()
                    }
                    background: Rectangle {
                        radius: 8
                        color: ThemeService.red
                    }
                    contentItem: Text {
                        text: parent.text; color: ThemeService.bg0
                        font.pixelSize: 12; font.bold: true
                        leftPadding: 14; rightPadding: 14
                        topPadding: 6; bottomPadding: 6
                    }
                }
            }
        }
    }
}
