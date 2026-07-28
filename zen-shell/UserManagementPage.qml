import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * UserManagementPage v7.0.0-beta.1-hf82p — Karui (軽い)
 *
 * Settings page for system user management. Lists all real users
 * (uid >= 1000) with per-row admin toggle + delete button. Add user
 * form at the bottom.
 *
 * SAFETY:
 *   - Current user row is visually distinguished with a "(YOU)" badge
 *   - Current user's Delete button is DISABLED + tooltip explains why
 *   - Current user's Admin toggle is DISABLED if it would demote them
 *   - Every destructive action shows a confirmation dialog first
 *   - lastError + lastAction surfaced in a prominent status banner
 *
 * pkexec backend handled by UserManagementService — see that file
 * for full safety model (triple-check, shell guard, audit log).
 *
 * Wala tayong babawasan — additive page; existing UserProfilePage
 * (for avatar + system info) untouched. This page is separate and
 * focuses on system-level user CRUD.
 */
ScrollView {
    id: rootView
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth

    // ── Add-user form state ──
    property string newName: ""
    property string newFullName: ""
    property string newPassword: ""
    property bool newIsAdmin: false
    // v7.0.0-beta.1-hf85: clone current user's Zen Shell + Hyprland rice
    // into the new account. Default true.
    property bool newCloneDotfiles: true

    // ── Confirmation dialog state ──
    //
    // dialogMode: "delete" | "delete-keep-home" | "demote" | "set-password"
    // dialogTarget: username being acted on
    property string dialogMode: ""
    property string dialogTarget: ""
    property string dialogNewPassword: ""

    ColumnLayout {
        // hf82r: match GeneralPage spacing exactly
        width: rootView.availableWidth - 48
        x: 24
        y: 20
        spacing: 18

        DenshoPageHeader {
            Layout.fillWidth: true
            title: "User Management"
            subtitle: "Add, remove, and toggle admin for system users (requires pkexec auth)"
            kanji: "利用者管理"
            romaji: "Riyōsha Kanri"
        }

        // ═════════════════════════════════════════════════════════
        // SAFETY NOTICE
        // ═════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: safetyCol.implicitHeight + 20
            radius: 10
            color: Qt.rgba(ThemeService.yellow.r, ThemeService.yellow.g,
                           ThemeService.yellow.b, 0.10)
            border.color: Qt.rgba(ThemeService.yellow.r, ThemeService.yellow.g,
                                  ThemeService.yellow.b, 0.30)
            border.width: 1

            Column {
                id: safetyCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Row {
                    spacing: 8
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf071"
                        font.family: Theme.iconFontFamily || "Font Awesome 6 Free"
                        font.pixelSize: 14
                        color: ThemeService.yellow
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Important safety rules"
                        color: ThemeService.fg
                        font.bold: true
                        font.pixelSize: 13
                    }
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "• You CANNOT delete the currently-logged-in user ('" +
                          UserManagementService.currentUser + "')\n" +
                          "• You CANNOT remove your own admin privilege (sudo lockout protection)\n" +
                          "• System accounts (uid < 1000) are never shown or touched\n" +
                          "• Each action requires a pkexec password prompt"
                    color: ThemeService.alpha(ThemeService.fg, 0.85)
                    font.pixelSize: 12
                    width: parent.width
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // STATUS / ERROR BANNER
        // ═════════════════════════════════════════════════════════
        Rectangle {
            visible: UserManagementService.lastAction.length > 0
                   || UserManagementService.lastError.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 8
            color: UserManagementService.lastError.length > 0
                ? Qt.rgba(ThemeService.red.r, ThemeService.red.g, ThemeService.red.b, 0.15)
                : Qt.rgba(ThemeService.green.r, ThemeService.green.g, ThemeService.green.b, 0.12)
            border.color: UserManagementService.lastError.length > 0
                ? Qt.rgba(ThemeService.red.r, ThemeService.red.g, ThemeService.red.b, 0.35)
                : Qt.rgba(ThemeService.green.r, ThemeService.green.g, ThemeService.green.b, 0.25)
            border.width: 1
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: UserManagementService.lastError.length > 0
                    ? UserManagementService.lastError
                    : UserManagementService.lastAction
                color: ThemeService.fg
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }

        // ═════════════════════════════════════════════════════════
        // 1. EXISTING USERS
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Users"
            subtitle: "Found " + (UserManagementService.users || []).length +
                      " user(s) with uid ≥ 1000"

            Repeater {
                model: UserManagementService.users

                delegate: HMRow {
                    id: userRow
                    required property var modelData
                    required property int index

                    label: modelData.name +
                           (modelData.isCurrent ? "  (YOU)" : "") +
                           (modelData.isAdmin ? "  · admin" : "")
                    description: (modelData.gecos || "(no full name)") +
                                 "  ·  uid " + modelData.uid +
                                 "  ·  " + (modelData.home || "")
                    separator: index > 0

                    RowLayout {
                        spacing: 8

                        // Admin toggle
                        HMSwitch {
                            id: adminSwitch
                            checked: userRow.modelData.isAdmin
                            enabled: !UserManagementService.isRunning
                                  && !(userRow.modelData.isAdmin && userRow.modelData.isCurrent)
                                  // ^^ disable demote of current user
                            onToggled: {
                                if (checked === userRow.modelData.isAdmin) return
                                // Demoting current user is blocked
                                if (!checked && userRow.modelData.isCurrent) {
                                    // Revert visually + show error
                                    checked = true
                                    UserManagementService.lastError =
                                        "Cannot remove your own admin privilege"
                                    return
                                }
                                if (!checked) {
                                    // Demoting another user — confirm
                                    rootView.dialogMode = "demote"
                                    rootView.dialogTarget = userRow.modelData.name
                                    confirmDialog.open()
                                    // Revert visually until confirmed
                                    checked = true
                                } else {
                                    // Promoting — straight through
                                    UserManagementService.setAdmin(userRow.modelData.name, true)
                                }
                            }
                        }

                        // Set password button
                        Rectangle {
                            width: 32; height: 28; radius: 6
                            color: pwMa.containsMouse
                                ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                          ThemeService.fg.b, 0.12)
                                : "transparent"
                            border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                                  ThemeService.fg.b, 0.15)
                            border.width: 1
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                anchors.centerIn: parent
                                text: "\uf084"   // fa-key
                                font.family: Theme.iconFontFamily || "Font Awesome 6 Free"
                                font.pixelSize: 12
                                color: ThemeService.fg
                            }
                            MouseArea {
                                id: pwMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !UserManagementService.isRunning
                                onClicked: {
                                    rootView.dialogMode = "set-password"
                                    rootView.dialogTarget = userRow.modelData.name
                                    rootView.dialogNewPassword = ""
                                    confirmDialog.open()
                                }
                            }
                        }

                        // Delete button
                        Rectangle {
                            width: 32; height: 28; radius: 6
                            color: rmMa.containsMouse && !userRow.modelData.isCurrent
                                ? Qt.rgba(ThemeService.red.r, ThemeService.red.g,
                                          ThemeService.red.b, 0.20)
                                : "transparent"
                            opacity: userRow.modelData.isCurrent ? 0.35 : 1.0
                            border.color: userRow.modelData.isCurrent
                                ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                          ThemeService.fg.b, 0.10)
                                : Qt.rgba(ThemeService.red.r, ThemeService.red.g,
                                          ThemeService.red.b, 0.40)
                            border.width: 1
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                anchors.centerIn: parent
                                text: "\uf1f8"   // fa-trash
                                font.family: Theme.iconFontFamily || "Font Awesome 6 Free"
                                font.pixelSize: 12
                                color: userRow.modelData.isCurrent
                                    ? ThemeService.fg
                                    : (rmMa.containsMouse ? ThemeService.red : ThemeService.fg)
                            }
                            MouseArea {
                                id: rmMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: userRow.modelData.isCurrent
                                    ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                enabled: !UserManagementService.isRunning
                                      && !userRow.modelData.isCurrent
                                onClicked: {
                                    rootView.dialogMode = "delete"
                                    rootView.dialogTarget = userRow.modelData.name
                                    confirmDialog.open()
                                }
                            }
                        }
                    }
                }
            }

            HMRow {
                visible: (UserManagementService.users || []).length === 0
                label: "No users found"
                description: "Either /etc/passwd couldn't be read or no users have uid ≥ 1000"
            }

            HMRow {
                separator: true
                label: "Refresh list"
                description: "Re-read /etc/passwd and /etc/group"
                                ZenButton {
                    text: "Refresh"
                    enabled: !UserManagementService.isRunning
                    onClicked: UserManagementService.refresh()
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // 2. ADD NEW USER
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Add new user"
            subtitle: "Creates the account with a home directory and bash shell. Requires pkexec auth."

            HMRow {
                label: "Username"
                description: "Lowercase letters, digits, _, - (must start with letter or _; max 32 chars)"
                TextField {
                    id: nameField
                    width: 240
                    text: rootView.newName
                    placeholderText: "e.g. kristine"
                    onTextChanged: rootView.newName = text
                    color: ThemeService.fg
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                       ThemeService.fg.b, 0.06)
                        border.color: nameField.activeFocus
                            ? ThemeService.blue
                            : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                      ThemeService.fg.b, 0.15)
                        border.width: 1
                    }
                }
            }

            HMRow {
                separator: true
                label: "Full name (optional)"
                description: "Displayed in login screens / GECOS"
                TextField {
                    id: gecosField
                    width: 240
                    text: rootView.newFullName
                    placeholderText: "e.g. Kristine"
                    onTextChanged: rootView.newFullName = text
                    color: ThemeService.fg
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                       ThemeService.fg.b, 0.06)
                        border.color: gecosField.activeFocus
                            ? ThemeService.blue
                            : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                      ThemeService.fg.b, 0.15)
                        border.width: 1
                    }
                }
            }

            HMRow {
                label: "Initial password"
                description: "Minimum 4 characters. User can change it later via passwd."
                TextField {
                    id: pwField
                    width: 240
                    text: rootView.newPassword
                    echoMode: TextInput.Password
                    placeholderText: "min 4 chars"
                    onTextChanged: rootView.newPassword = text
                    color: ThemeService.fg
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                       ThemeService.fg.b, 0.06)
                        border.color: pwField.activeFocus
                            ? ThemeService.blue
                            : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                      ThemeService.fg.b, 0.15)
                        border.width: 1
                    }
                }
            }

            HMRow {
                label: "Make admin"
                description: "Adds user to the wheel group (can use sudo)"
                HMSwitch {
                    checked: rootView.newIsAdmin
                    onToggled: rootView.newIsAdmin = checked
                }
            }

            HMRow {
                label: "Clone my dotfiles"
                description: "Copy your Zen Shell + Hyprland setup into the new account so it boots into the same desktop"
                HMSwitch {
                    checked: rootView.newCloneDotfiles
                    onToggled: rootView.newCloneDotfiles = checked
                }
            }

            HMRow {
                separator: true
                label: "Create user"
                description: "Will prompt for your admin password via pkexec"
                ZenButton {
                    text: UserManagementService.isRunning ? "Working…" : "Create"
                    accent: true
                    iconText: "\uf234"   // user-plus glyph
                    enabled: !UserManagementService.isRunning
                          && rootView.newName.length > 0
                          && rootView.newPassword.length >= 4
                    onClicked: {
                        UserManagementService.createUser(
                            rootView.newName,
                            rootView.newFullName,
                            rootView.newPassword,
                            rootView.newIsAdmin,
                            rootView.newCloneDotfiles)
                        // Clear form on submit (success or failure)
                        rootView.newName = ""
                        rootView.newFullName = ""
                        rootView.newPassword = ""
                        rootView.newIsAdmin = false
                        rootView.newCloneDotfiles = true
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // 3. AUDIT LOG POINTER
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Audit log"
            subtitle: "All actions written to ~/.cache/zen-shell/user-mgmt.log"

            HMRow {
                label: "View log in terminal"
                description: "tail -50 ~/.cache/zen-shell/user-mgmt.log"
                                ZenButton {
                    text: "Show"
                    onClicked: termProc.running = true
                }
            }
        }

        Item { Layout.preferredHeight: 24 }
    }

    Process {
        id: termProc
        running: false
        command: ["bash", "-c",
            "foot bash -c 'cat ~/.cache/zen-shell/user-mgmt.log 2>/dev/null | tail -50; " +
            "echo; echo --- press enter to close ---; read' 2>/dev/null || " +
            "kitty bash -c 'cat ~/.cache/zen-shell/user-mgmt.log 2>/dev/null | tail -50; " +
            "echo; echo --- press enter to close ---; read' 2>/dev/null || " +
            "xterm -e \"cat ~/.cache/zen-shell/user-mgmt.log | tail -50; read\""]
    }

    // ════════════════════════════════════════════════════════════
    // CONFIRMATION DIALOG
    // ════════════════════════════════════════════════════════════
    Dialog {
        id: confirmDialog
        anchors.centerIn: Overlay.overlay
        modal: true
        width: 440
        title: {
            switch (rootView.dialogMode) {
                case "delete":           return "Delete user '" + rootView.dialogTarget + "'?"
                case "delete-keep-home": return "Delete account (keep home)?"
                case "demote":           return "Remove admin from '" + rootView.dialogTarget + "'?"
                case "set-password":     return "Set new password for '" + rootView.dialogTarget + "'?"
            }
            return ""
        }

        contentItem: ColumnLayout {
            spacing: 12
            width: parent.width

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: rootView.dialogMode === "delete"
                Layout.fillWidth: true
                text: "This will run 'userdel -r " + rootView.dialogTarget +
                      "' which removes:\n" +
                      "  • The user account\n" +
                      "  • Their home directory at /home/" + rootView.dialogTarget + "\n" +
                      "  • Their mailbox if any\n\n" +
                      "This action CANNOT be undone."
                color: ThemeService.fg
                wrapMode: Text.WordWrap
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: rootView.dialogMode === "demote"
                Layout.fillWidth: true
                text: "Removes '" + rootView.dialogTarget + "' from the wheel group.\n" +
                      "They will no longer be able to use sudo."
                color: ThemeService.fg
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                visible: rootView.dialogMode === "set-password"
                Layout.fillWidth: true
                spacing: 6
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Enter new password for '" + rootView.dialogTarget + "':"
                    color: ThemeService.fg
                }
                TextField {
                    id: dlgPwField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "min 4 chars"
                    text: rootView.dialogNewPassword
                    onTextChanged: rootView.dialogNewPassword = text
                    color: ThemeService.fg
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                       ThemeService.fg.b, 0.06)
                        border.color: dlgPwField.activeFocus
                            ? ThemeService.blue
                            : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                      ThemeService.fg.b, 0.15)
                        border.width: 1
                    }
                }
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                Layout.fillWidth: true
                text: "You'll be prompted for your admin password via pkexec."
                color: ThemeService.alpha(ThemeService.fg, 0.7)
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        standardButtons: Dialog.Cancel | Dialog.Ok

        onAccepted: {
            switch (rootView.dialogMode) {
                case "delete":
                    UserManagementService.deleteUser(rootView.dialogTarget)
                    break
                case "delete-keep-home":
                    UserManagementService.deleteUserKeepHome(rootView.dialogTarget)
                    break
                case "demote":
                    UserManagementService.setAdmin(rootView.dialogTarget, false)
                    break
                case "set-password":
                    if (rootView.dialogNewPassword.length >= 4) {
                        UserManagementService.setPassword(
                            rootView.dialogTarget,
                            rootView.dialogNewPassword)
                    } else {
                        UserManagementService.lastError =
                            "Password must be at least 4 characters"
                    }
                    rootView.dialogNewPassword = ""
                    break
            }
            rootView.dialogMode = ""
            rootView.dialogTarget = ""
        }
        onRejected: {
            rootView.dialogMode = ""
            rootView.dialogTarget = ""
            rootView.dialogNewPassword = ""
        }
    }
}
