import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * NotificationListPanel v7.0.0-beta.1-hf82c — Karui (軽い)
 *
 * Live list of notifications from NotificationService. Designed to
 * be embedded inside Control Panel's Notifications tab (alpha.12+)
 * OR shown as a standalone panel.
 *
 * Visual:
 *
 *   ┌──────────────────────────────────────────────┐
 *   │ Notifications  (3 unread)         [Clear all] │
 *   │ [ ] Do not disturb                            │
 *   ├──────────────────────────────────────────────┤
 *   │ ● Brave            2m ago                  × │
 *   │   Download complete                           │
 *   │   /home/paul/Downloads/file.tgz              │
 *   ├──────────────────────────────────────────────┤
 *   │   Discord          15m ago                 × │
 *   │   New message from kristine                   │
 *   ├──────────────────────────────────────────────┤
 *   │   System           1h ago                  × │
 *   │   Battery low — 18%                           │
 *   └──────────────────────────────────────────────┘
 *
 * Colors via ThemeService for live theme-switch support.
 */
Rectangle {
    id: panel

    color: ThemeService.alpha(ThemeService.bg0, 0.98)
    radius: 10
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)
    clip: true

    implicitWidth: 400
    implicitHeight: 480

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\uf0f3"   // Nerd Font: bell
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: ThemeService.blue
            }

            Text {
                text: "Notifications"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: ThemeService.fg
            }

            Text {
                text: "(" + NotificationService.unreadCount + " unread)"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.alpha(ThemeService.fg, 0.6)
                Layout.fillWidth: true
            }

            // Clear all button
            Rectangle {
                Layout.preferredWidth: clearText.implicitWidth + 16
                Layout.preferredHeight: 26
                radius: 6
                color: clearMa.containsMouse
                       ? ThemeService.alpha(ThemeService.red, 0.18)
                       : "transparent"
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear all"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: clearMa.containsMouse
                           ? ThemeService.red
                           : ThemeService.alpha(ThemeService.fg, 0.7)
                }

                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearAll()
                }
            }
        }

        // ── DND toggle ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\uf186"   // Nerd Font: moon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: NotificationService.dndEnabled
                       ? ThemeService.blue
                       : ThemeService.grey0
            }

            Text {
                text: "Do not disturb"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.fg
                Layout.fillWidth: true
            }

            // Switch
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 18
                radius: 9
                color: NotificationService.dndEnabled
                       ? ThemeService.blue
                       : ThemeService.alpha(ThemeService.fg, 0.18)
                Behavior on color { ColorAnimation { duration: 160 } }

                Rectangle {
                    width: 14; height: 14; radius: 7
                    color: ThemeService.fg
                    y: 2
                    x: NotificationService.dndEnabled ? 20 : 2
                    Behavior on x {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.dndEnabled = !NotificationService.dndEnabled
                }
            }
        }

        // ── Divider ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: ThemeService.alpha(ThemeService.fg, 0.08)
        }

        // ── Empty state ──
        Item {
            visible: NotificationService.notifications.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                width: parent.width

                Text {
                    text: "\uf0f3"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 36
                    color: ThemeService.alpha(ThemeService.fg, 0.25)
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "No notifications"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: ThemeService.alpha(ThemeService.fg, 0.5)
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: NotificationService.dndEnabled
                          ? "Do not disturb is on"
                          : "You're all caught up"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.alpha(ThemeService.fg, 0.35)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ── Notifications list ──
        ListView {
            id: list
            visible: NotificationService.notifications.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            cacheBuffer: 200

            model: NotificationService.notifications

            ScrollBar.vertical: ScrollBar {
                policy: list.contentHeight > list.height
                        ? ScrollBar.AsNeeded
                        : ScrollBar.AlwaysOff
                width: 5
                contentItem: Rectangle {
                    radius: 2
                    color: ThemeService.alpha(ThemeService.fg, 0.3)
                }
            }

            delegate: Rectangle {
                id: notifRow
                required property var modelData
                required property int index

                width: ListView.view.width
                height: rowCol.implicitHeight + 18
                radius: 8
                color: rowMa.containsMouse
                       ? ThemeService.alpha(ThemeService.bg2, 0.85)
                       : ThemeService.alpha(ThemeService.bg2, 0.45)
                border.width: 1
                border.color: {
                    // v7.0.0-beta.1-hf13: null-guard modelData access
                    if (modelData && modelData.urgency === 2) return ThemeService.alpha(ThemeService.red, 0.4)
                    return ThemeService.alpha(ThemeService.fg, 0.06)
                }
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: NotificationService.markRead(modelData.id)
                }

                ColumnLayout {
                    id: rowCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Unread dot
                        Rectangle {
                            // v7.0.0-beta.1-hf20: defensive null guards.
                            // Entries can momentarily be undefined during
                            // burst pruning + re-render.
                            visible: !!(modelData && !modelData.read)
                            width: 6; height: 6; radius: 3
                            color: (modelData && modelData.urgency === 2)
                                   ? ThemeService.red
                                   : ThemeService.blue
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: (modelData && modelData.appName) || "Notification"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: ThemeService.alpha(ThemeService.fg, 0.65)
                            // hf82: lock to PlainText — same Lark/Teams
                            // SIGSEGV path as hf79 fixed for body, but
                            // applies to appName too. Service-level
                            // sanitization strips tags at reception;
                            // pinning textFormat closes the AutoText →
                            // RichText auto-upgrade path here.
                            textFormat: Text.PlainText
                        }

                        Text {
                            // v7.0.0-beta.1-hf13: null-guard against
                            // entries that may have undefined timestamp
                            // (corrupted history JSON, race during load,
                            // etc.) — without this, panel._formatAge
                            // would throw TypeError per delegate,
                            // accumulating to SIGSEGV when many rows
                            // render at once.
                            text: modelData && modelData.timestamp
                                  ? panel._formatAge(modelData.timestamp)
                                  : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.alpha(ThemeService.fg, 0.4)
                            Layout.fillWidth: true
                        }

                        // Dismiss × button
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: dismissMa.containsMouse
                                   ? ThemeService.alpha(ThemeService.red, 0.28)
                                   : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: dismissMa.containsMouse
                                       ? ThemeService.red
                                       : ThemeService.alpha(ThemeService.fg, 0.5)
                            }

                            MouseArea {
                                id: dismissMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationService.dismiss(modelData.id)
                            }
                        }
                    }

                    Text {
                        text: (modelData && modelData.summary) || ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: ThemeService.fg
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        // hf82: same PlainText lock as toast — kills
                        // AutoText → RichText auto-promote on
                        // markup-containing summary lines.
                        textFormat: Text.PlainText
                    }

                    Text {
                        visible: !!(modelData && modelData.body && modelData.body.length > 0)
                        // hf79: sanitize body — same Lark crash fix as ZenNotifyToast
                        text: {
                            if (!modelData || !modelData.body) return ""
                            let b = String(modelData.body)
                            if (b.length > 1500) b = b.substring(0, 1500) + "…"
                            b = b.replace(/<\s*\/?\s*(img|script|style|object|iframe|embed|video|audio|svg|table|tr|td|th|div|span|p|ul|ol|li|h[1-6]|form|input|button)\b[^>]*>/gi, "")
                            b = b.replace(/data:[^"'\s>]+/gi, "")
                            return b
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.alpha(ThemeService.fg, 0.75)
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: Text.StyledText  // hf79: was RichText — Lark crash fix
                    }
                }
            }
        }
    }

    // Helper: format timestamp as "2m ago", "1h ago", "3d ago"
    function _formatAge(ts) {
        const ageMs = Date.now() - ts
        const sec = Math.floor(ageMs / 1000)
        if (sec < 60) return "now"
        const min = Math.floor(sec / 60)
        if (min < 60) return min + "m ago"
        const hr = Math.floor(min / 60)
        if (hr < 24) return hr + "h ago"
        const day = Math.floor(hr / 24)
        return day + "d ago"
    }
}
