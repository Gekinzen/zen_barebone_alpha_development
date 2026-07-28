import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

/*
 * SystemTray v6.16.4.12.6 (Hikari · Frosted)
 *
 * v6.16.4.12.6:
 *   - Background switched from Theme.alpha(Theme.bg0, 0.9) → ThemeService.bg0
 *     at alpha 0.32 so it falls below Hyprland's `ignore_alpha 0.5` blur
 *     threshold for the zen-shell-bar layer. The tray now reads as part of
 *     the frosted bar instead of a solid pill.
 *   - Border + hover highlight bind to ThemeService so live theme switches
 *     and matugen wallpaper-sync repaint the tray immediately.
 *   - Layout, click handling, icon rendering, and SystemTray model bindings
 *     untouched. Wala tayo babawasan.
 */
Rectangle {
    id: trayRoot

    // v7.0.0-beta.1-hf93: explicit vertical mode. Vertical → tray icons
    // stack in a column sized to the bar thickness. Default false →
    // original horizontal row.
    property bool zenVertical: false

    visible: SystemTray.items && SystemTray.items.values.length > 0
    implicitWidth: visible ? (zenVertical ? Math.round(Theme.moduleHeight) : trayRow.implicitWidth + 20) : 0
    implicitHeight: zenVertical ? (visible ? trayRow.implicitHeight + 20 : 0) : 40
    height: implicitHeight
    radius: Theme.styleMode === "round" ? (zenVertical ? width / 2 : height / 2) : Theme.moduleRadius

    // Frosted: low alpha so Hyprland layer blur passes through
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.32)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.10)

    // Subtle inner highlight for depth
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.04)
    }

    GridLayout {
        id: trayRow
        anchors.centerIn: parent
        columns: trayRoot.zenVertical ? 1 : 32
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: SystemTray.items

            Rectangle {
                id: trayItem
                required property var modelData
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Theme.styleMode === "round" ? 12 : 6
                color: trayMa.containsMouse
                       ? ThemeService.alpha(ThemeService.fg, 0.10)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: trayItem.modelData.icon
                    sourceSize: Qt.size(18, 18)
                    smooth: true
                }

                MouseArea {
                    id: trayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            trayItem.modelData.activate()
                        } else {
                            trayItem.modelData.display(trayRoot, trayItem.x, trayRoot.height)
                        }
                    }
                }
            }
        }
    }
}
