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

    // v7.0.0-beta.1-hf84: scale the glyph with the bar when Fit-contents
    // is on (1.0 otherwise → identical to before). Tooltip text is left
    // unscaled — it's a popup, not a bar element.
    readonly property real _fit: (typeof Theme !== "undefined" && Theme.barContentScale)
                                 ? Theme.barContentScale : 1.0

    signal clicked()

    // v7.0.0-beta.1-hf93: height capped to moduleHeight. In a horizontal
    // bar `parent.height` IS moduleHeight (unchanged). In a vertical
    // SysRow column, `parent.height` would be the whole column height, so
    // the cap keeps each icon a single module tall instead of ballooning.
    Layout.preferredWidth: iconText.implicitWidth + 12
    Layout.preferredHeight: Math.min(parent ? parent.height : 28, Theme.moduleHeight)
    implicitWidth: iconText.implicitWidth + 12
    implicitHeight: Math.min(parent ? parent.height : 28, Theme.moduleHeight)

    Text {
        id: iconText
        anchors.centerIn: parent
        text: root.icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(14 * root._fit)
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
    // Same pattern as Taskbar.qml PopupWindow: anchor.item + edges.
    // Quickshell auto-positions relative to the anchor item on Wayland.
    //
    // v6.16.4.12.7.1 (Tachiagari hotfix 1): Edges/gravity now bound to
    // PanelState.popupAnchorEdges / popupAnchorGravity, which already
    // encodes the 4-direction policy:
    //   Bar bottom → popup floats UP (Edges.Top)
    //   Bar top    → popup drops DOWN (Edges.Bottom)
    //   Bar left   → popup slides RIGHT (Edges.Right)
    //   Bar right  → popup slides LEFT (Edges.Left)
    // Future-proofs against the upcoming vertical bar rotation drop.
    PopupWindow {
        id: tipPopup
        anchor.item: root
        anchor.edges: PanelState.popupAnchorEdges
        anchor.gravity: PanelState.popupAnchorGravity
        visible: iconMouse.containsMouse && root.tipTitle.length > 0
        // v7.0.0-beta.1-hf4: implicit* (bare width/height deprecated)
        implicitWidth: Math.max(tipCol.implicitWidth + 24, 100)
        implicitHeight: tipCol.implicitHeight + 16
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
