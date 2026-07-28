import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * DockPowerButton v8.0.0-alpha-hf126 — the dock's "power" module.
 *
 * A round power glyph that opens a small session menu: Lock, Suspend,
 * Logout, Restart, Shutdown. Same five actions and the same commands the
 * Start Menu uses — one source of truth for what "shutdown" means.
 *
 * Why a PopupWindow and not a Rectangle:
 *   The dock is a layer-shell surface sized to its content. A Rectangle
 *   menu would be clipped by the dock's own height. PopupWindow gets its
 *   own surface, anchored to this button, and it survives outside the
 *   dock's bounds. Same approach as CalendarButton.
 *
 * v8.0.0-alpha-hf131 — the menu used to open nowhere near the button.
 *   It anchored to the dock WINDOW and computed its offset from `root.x`,
 *   which is local to the Loader the dock mounts modules through — always 0.
 *   And it picked its direction from PanelState (the BAR's edge), not from
 *   DockState. Now: `anchor.item: root`, edges/gravity from DockState.
 *   See the block comment on the PopupWindow below.
 */
Item {
    id: root

    readonly property int btnSize: 36
    implicitWidth: btnSize
    implicitHeight: btnSize

    readonly property var actions: [
        { icon: "\uf023", label: "Lock",     cmd: "hyprlock",              danger: false },
        { icon: "\uf186", label: "Suspend",  cmd: "systemctl suspend",     danger: false },
        { icon: "\uf2f5", label: "Logout",   cmd: "hyprctl dispatch exit", danger: false },
        { icon: "\uf021", label: "Restart",  cmd: "systemctl reboot",      danger: false },
        { icon: "\uf011", label: "Shutdown", cmd: "systemctl poweroff",    danger: true  }
    ]

    Process { id: runner; running: false }
    function _run(cmd) {
        popup.visible = false
        runner.command = ["bash", "-c", cmd]
        runner.running = true
    }

    // ── the button ──
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        readonly property real hoverAlpha: popup.visible ? 0.28
                                         : (ma.containsMouse ? (ma.pressed ? 0.30 : 0.18) : 0.0)
        color: Qt.rgba(ThemeService.red.r, ThemeService.red.g, ThemeService.red.b, hoverAlpha)
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            anchors.centerIn: parent
            text: "\uf011"                       // Nerd Font power glyph
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: popup.visible || ma.containsMouse ? ThemeService.red : ThemeService.grey1
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.visible = !popup.visible
        }
    }

    // ── the menu ──
    //
    // ══ v8.0.0-alpha-hf131 — THE MENU OPENED NOWHERE NEAR THE BUTTON ══
    //
    // "kapag click ko yun power button sa dock, hindi naka-align yun prompt"
    //
    // Two bugs, and they compounded.
    //
    // ONE — the coordinate space. This used `anchor.window: QsWindow.window`
    // with a hand-computed `anchor.rect.x` built from `root.x`. But `root.x` is
    // the item's x **in its immediate parent**, not in the anchor window. The
    // dock mounts its modules through a Loader inside a RowLayout inside the
    // island pill, so `root.x` is 0 — not the ~1206 it would be in window
    // coordinates. Measured on a 1920 dock:
    //
    //     root.x (local to its Loader)  = 0
    //     window x of the button        = 1206
    //     anchor.rect.x = 0 + 18 - 95   = -77      <- 77px LEFT of the dock
    //
    // The compositor then slid the popup back on-screen, which is why the menu
    // appeared parked at the far left with nothing under it.
    //
    // (CalendarButton does the same arithmetic but lives directly in the bar's
    // row, where local x ≈ window x. It looks fine, so it stays as it is.)
    //
    // TWO — the wrong edge. `PanelState.isTop / isLeft / isRight` describe the
    // BAR. On the default layout — top bar, bottom dock — `isTop` is true, so
    // the menu was told to open *downward* from a dock already sitting on the
    // bottom edge. It ran off the screen and got flipped.
    //
    // The fix is the pattern Taskbar and SysRowIcon have used since v6.14:
    // `anchor.item`, and let Quickshell do the window mapping. Edges and gravity
    // come from DockState, which knows which edge the DOCK is on.
    PopupWindow {
        id: popup

        readonly property int _w: 190
        readonly property int _h: powerCol.implicitHeight + 12
        readonly property int _gap: 8

        anchor.item: root
        // Inflate the anchor rect by the gap on the axis the menu grows along,
        // so the popup clears the button instead of touching it.
        anchor.rect.x: 0
        anchor.rect.y: -popup._gap
        anchor.rect.width: root.width
        anchor.rect.height: root.height + (popup._gap * 2)
        // The DOCK's edge, not the bar's. Bottom dock → menu grows up.
        anchor.edges: DockState.popupAnchorEdges
        anchor.gravity: DockState.popupAnchorGravity

        implicitWidth: popup._w
        implicitHeight: popup._h
        color: "transparent"
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: 10
            // v8.0.0-alpha-hf150 — the power menu follows the look.
            color: LookService.popupColor(0.98)
            border.width: LookService.bodyBorderWidth(1)
            border.color: LookService.popupInkAlpha(0.14)

            ColumnLayout {
                id: powerCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 7
                        color: rowMa.containsMouse
                               ? ThemeService.alpha(modelData.danger ? ThemeService.red : ThemeService.fg, 0.14)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            Text {
                                style: Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: modelData.danger ? ThemeService.red : ThemeService.grey1
                            }
                            Text {
                                style: Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.fillWidth: true
                                text: modelData.label
                                elide: Text.ElideRight
                                color: LookService.popupInk
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._run(modelData.cmd)
                        }
                    }
                }
            }
        }

        // Dismissal follows CalendarButton: toggled by the button, closed by
        // choosing an action. NO HyprlandFocusGrab — v6.12 tore it out because
        // it stole focus and killed the Taskbar's context menu. Don't put it back.
        //
        // Escape also closes, and the popup gives up the key as soon as it hides.
        Keys.onEscapePressed: popup.visible = false
        onVisibleChanged: if (visible) forceActiveFocus()
    }
}
