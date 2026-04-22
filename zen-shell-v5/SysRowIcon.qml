import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * SysRowIcon v6.14 — Clickable icon for SysRow expand drawer
 *
 * v6.14: Tooltip rewritten to use PopupWindow with anchor.item —
 * same approach as Taskbar.qml. PopupWindow auto-positions itself
 * relative to the anchor item on Wayland, so no manual coordinate
 * math is needed. Works correctly in all bar modes (fullwidth,
 * floating, island).
 *
 * Old approach (v6.13): separate PanelWindow in shell.qml with
 * manual margins.left calculation — broke in floating/island modes.
 */
Item {
    id: root

    property string icon: ""
    property string tipTitle: ""
    property string tipDetail: ""
    property color iconColor: ThemeService.fg

    signal clicked()

    Layout.preferredWidth: iconText.implicitWidth + 12
    Layout.preferredHeight: parent ? parent.height : 28
    implicitWidth: iconText.implicitWidth + 12
    implicitHeight: parent ? parent.height : 28

    Text {
        id: iconText
        anchors.centerIn: parent
        text: root.icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: root.iconColor
    }

    Rectangle {
        id: iconBg
        anchors.fill: parent
        radius: 6
        color: iconMouse.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
    }

    MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // ── Tooltip — PopupWindow anchored to this icon ──
    // Same pattern as Taskbar.qml PopupWindow: anchor.item + Edges.Top
    // Quickshell auto-positions above the anchor item on Wayland.
    PopupWindow {
        id: tipPopup
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        visible: iconMouse.containsMouse && root.tipTitle.length > 0
        width: Math.max(tipCol.implicitWidth + 24, 100)
        height: tipCol.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.95)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)

            Column {
                id: tipCol
                anchors.centerIn: parent
                spacing: 3

                Text {
                    text: root.tipTitle
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                    visible: root.tipTitle.length > 0
                }

                Repeater {
                    model: root.tipDetail.split("\n")

                    Text {
                        required property string modelData
                        text: modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.grey0
                    }
                }
            }
        }
    }
}
