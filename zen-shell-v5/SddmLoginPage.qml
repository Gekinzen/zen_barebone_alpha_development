import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * SddmLoginPage v7.0.0-beta.1-hf95.12 — Settings page for the Zen Tokyo
 * SDDM login greeter.
 *
 * Toggles here are persisted by SettingsState (settings-state.json) and
 * read by:
 *   - ThemeService.sddmThemer  → only pushes theme changes to the greeter
 *     when "Enable SDDM login theme" is on.
 *   - zen-sddm-sync.sh         → reads loginEnabled + backgroundMode to
 *     decide whether to sync and how to render the background.
 *
 * The greeter itself is installed out-of-band by sddm/zen-sddm-install.sh
 * (system-level, needs root) — this page does NOT install it; it controls
 * whether the running shell keeps it in sync. Wala tayong babawasan.
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
                title: "Login Screen (SDDM)"
                subtitle: "Match the login greeter to your desktop theme"
                kanji: "ログイン"
                romaji: "Roguin"
            }

            HMSection {
                title: "Status"

                HMRow {
                    label: "Enable SDDM login theme"
                    description: "When on, SDDM becomes your login screen (the previous one is "
                               + "restored when off) and the Zen Tokyo greeter is kept in sync "
                               + "with your theme/wallpaper. The login-screen switch takes effect "
                               + "on your next reboot. Install the greeter first: "
                               + "sudo ./sddm/zen-sddm-install.sh"
                    icon: "\uf2f6"
                    separator: true

                    HMSwitch {
                        checked: SettingsState.sddmLoginEnabled
                        onToggled: {
                            SettingsState.sddmLoginEnabled = checked
                            if (checked) {
                                // Switch the active DM to SDDM, then sync.
                                dmSwitch.cmd = "enable"
                                dmSwitch.running = true
                                sddmSyncNow.running = true
                            } else {
                                // Restore the previous login screen.
                                dmSwitch.cmd = "restore"
                                dmSwitch.running = true
                            }
                        }
                    }
                }

                HMRow {
                    label: "Sync now"
                    description: "Push the current theme, wallpaper and avatar to the greeter "
                               + "immediately."
                    icon: "\uf021"

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 26
                        radius: 6
                        opacity: SettingsState.sddmLoginEnabled ? 1.0 : 0.4
                        color: ThemeService.alpha(ThemeService.blue, 0.18)
                        border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Sync now"
                            color: ThemeService.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: SettingsState.sddmLoginEnabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sddmSyncNow.running = true
                        }
                    }
                }
            }

            HMSection {
                title: "Background"
                opacity: SettingsState.sddmLoginEnabled ? 1.0 : 0.45
                enabled: SettingsState.sddmLoginEnabled

                HMRow {
                    label: "Use my wallpaper (blurred)"
                    description: "Greeter background is your current desktop wallpaper, blurred "
                               + "and darkened — same look as the lock screen."
                    icon: "\uf03e"
                    separator: true

                    HMSwitch {
                        checked: SettingsState.sddmBackgroundMode === "wallpaper"
                        onToggled: {
                            SettingsState.sddmBackgroundMode = "wallpaper"
                            sddmSyncNow.running = true
                        }
                    }
                }

                HMRow {
                    label: "Use matugen colour"
                    description: "Greeter background is a solid colour derived from your active "
                               + "scheme (no wallpaper image)."
                    icon: "\udb80\udd0e"

                    HMSwitch {
                        checked: SettingsState.sddmBackgroundMode === "matugen"
                        onToggled: {
                            SettingsState.sddmBackgroundMode = "matugen"
                            sddmSyncNow.running = true
                        }
                    }
                }
            }
        }
    }

    // Fire-and-forget sync. The polkit rule from zen-sddm-install.sh lets
    // this run without a password; if the greeter isn't installed the
    // script simply isn't there and this is a no-op.
    Process {
        id: sddmSyncNow
        running: false
        command: ["bash", "-c",
            "if [ -x /usr/local/bin/zen-sddm-sync.sh ]; then " +
            "  pkexec /usr/local/bin/zen-sddm-sync.sh \"--user=$USER\" " +
            "    > /tmp/zen-sddm-sync.log 2>&1 || true; " +
            "fi"]
    }

    // hf95.13: actually switch the active display manager. `enable` makes
    // SDDM the login screen; `restore` brings back the previous DM. Takes
    // effect on next reboot/logout — it never stops the running session.
    property string _dmCmdHolder: "status"
    Process {
        id: dmSwitch
        property string cmd: "status"
        running: false
        command: ["bash", "-c",
            "if [ -x /usr/local/bin/zen-dm-switch.sh ]; then " +
            "  pkexec /usr/local/bin/zen-dm-switch.sh " + dmSwitch.cmd +
            "    > /tmp/zen-dm-switch.log 2>&1 || true; " +
            "else echo 'zen-dm-switch.sh not installed'; fi"]
    }
}
