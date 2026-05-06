import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
 * PasswordPromptPanel — Modori v6.16.4.12.9.10
 *
 * Visual content for the in-shell WiFi password prompt. Hosted by
 * a PanelWindow (defined in shell.qml) at WlrLayer.Overlay so it
 * floats above all other surfaces including the Control Panel.
 *
 * The previous behavior used `zenity --password` which spawned a
 * separate window. On WMs without strict focus stealing, that
 * window often opened BEHIND the surface the user just clicked
 * (the Control Panel) — so the user thought nothing happened
 * and the connect attempt felt broken.
 *
 * This component:
 *   - Renders a backdrop dimming the whole screen
 *   - Centers a 380x200 prompt card with the SSID + password
 *     entry + Connect/Cancel buttons
 *   - Captures Esc → cancel and Return → submit
 *   - Auto-focuses the password entry on open
 *   - Reads state from PasswordPromptService singleton
 */
Item {
    id: root

    // Visible whenever the service has an active prompt.
    // The hosting PanelWindow uses this to drive its own visibility.
    readonly property bool active: PasswordPromptService.active

    anchors.fill: parent
    visible: active

    // ── Backdrop — dim screen, eat outside clicks ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        // Click outside the card → cancel
        MouseArea {
            anchors.fill: parent
            onClicked: PasswordPromptService._cancel()
        }
    }

    // ── Prompt card ──
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380
        height: cardCol.implicitHeight + 36
        radius: 14
        color: ThemeService.alpha(ThemeService.bg0, 0.98)
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.18)

        // Catch all clicks INSIDE the card so they don't propagate
        // to the backdrop's "click outside" handler.
        MouseArea {
            anchors.fill: parent
            onClicked: {}   // intentional no-op
        }

        // Subtle drop shadow via a sibling rectangle behind the card
        // would be nice but Qt6 Quickshell builds drop QtGraphicalEffects
        // — skip for now, the border + bg contrast is enough.

        ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // ── Header: lock icon + title ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\uf023"   // fa-lock
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: ThemeService.blue
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Wi-Fi password required"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }
                    Text {
                        text: PasswordPromptService.ssid
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey0
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // ── Password input ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 8
                color: ThemeService.alpha(ThemeService.bg2, 0.7)
                border.width: pwField.activeFocus ? 1 : 1
                border.color: pwField.activeFocus
                    ? ThemeService.alpha(ThemeService.blue, 0.6)
                    : ThemeService.alpha(ThemeService.fg, 0.1)

                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 6

                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        placeholderText: "Password"
                        echoMode: showPwToggle.checked
                            ? TextInput.Normal : TextInput.Password
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: ThemeService.fg
                        placeholderTextColor: ThemeService.grey1
                        background: Rectangle { color: "transparent" }
                        verticalAlignment: TextInput.AlignVCenter

                        // Submit on Enter
                        Keys.onReturnPressed: root._submit()
                        Keys.onEnterPressed: root._submit()
                        Keys.onEscapePressed: PasswordPromptService._cancel()

                        // Auto-focus when prompt opens
                        Connections {
                            target: PasswordPromptService
                            function onActiveChanged() {
                                if (PasswordPromptService.active) {
                                    pwField.text = ""
                                    Qt.callLater(pwField.forceActiveFocus)
                                }
                            }
                        }
                    }

                    // Show/hide password toggle (eye icon)
                    Rectangle {
                        id: showPwToggle
                        property bool checked: false
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 6
                        color: showPwMa.containsMouse
                            ? ThemeService.alpha(ThemeService.fg, 0.08)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: showPwToggle.checked ? "\uf070" : "\uf06e"   // fa-eye-slash / fa-eye
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: ThemeService.grey1
                        }

                        MouseArea {
                            id: showPwMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showPwToggle.checked = !showPwToggle.checked
                        }
                    }
                }
            }

            // ── Error message (if any) ──
            Text {
                Layout.fillWidth: true
                visible: PasswordPromptService.errorMessage.length > 0
                text: PasswordPromptService.errorMessage
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.red
                wrapMode: Text.WordWrap
            }

            // ── Buttons row: Cancel + Connect ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }   // spacer

                // Cancel button
                Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 34
                    radius: 8
                    color: cancelMa.containsMouse
                        ? ThemeService.alpha(ThemeService.fg, 0.08)
                        : ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.fg, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.fg
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PasswordPromptService._cancel()
                    }
                }

                // Connect button (primary)
                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 34
                    radius: 8
                    color: pwField.text.length === 0
                        ? ThemeService.alpha(ThemeService.blue, 0.3)
                        : (connectMa.containsMouse
                            ? ThemeService.alpha(ThemeService.blue, 0.85)
                            : ThemeService.alpha(ThemeService.blue, 0.7))

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Connect"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: connectMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: pwField.text.length > 0
                        cursorShape: enabled
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root._submit()
                    }
                }
            }
        }
    }

    function _submit() {
        if (pwField.text.length === 0) return
        PasswordPromptService._submit(pwField.text)
    }

    // Esc anywhere within the panel closes
    Keys.onEscapePressed: PasswordPromptService._cancel()
    focus: active
}
