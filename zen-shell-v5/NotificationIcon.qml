import QtQuick
import Quickshell
import Quickshell.Io

/*
 * NotificationIcon v6.16.4.12.6 (Hikari · Frosted)
 *
 * v6.16.4.12.6:
 *   - Background switched from Theme.alpha(Theme.bg0, 0.9) → ThemeService.bg0
 *     at alpha 0.32 so it falls below Hyprland's `ignore_alpha 0.5` blur
 *     threshold for the zen-shell-bar layer. The bell now reads as part of
 *     the frosted bar instead of a solid pill.
 *   - Border + glyph color bind to ThemeService so live theme switches and
 *     matugen wallpaper-sync repaint immediately. Notification + DND glyph
 *     mappings preserved verbatim. Wala tayo babawasan.
 */
Rectangle {
    id: notifRoot
    width: Theme.moduleHeight
    height: Theme.moduleHeight
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius

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

    // Matching your old format-icons:
    // notification: 󱅫, none: 󰂜, dnd-notification: 󰂠, dnd-none: 󰪓, etc
    property bool hasNotifications: false
    property bool dndEnabled: false

    property string notifIcon: {
        if (dndEnabled) {
            return hasNotifications ? "\udb80\udca0" : "\udb82\udd13"  // dnd-notification : dnd-none
        }
        return hasNotifications ? "\udb83\udd6b" : "\udb80\udc9c"  // notification : none
    }

    Process {
        id: poll
        command: ["swaync-client", "-swb"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    notifRoot.hasNotifications = (d.count || 0) > 0
                    notifRoot.dndEnabled = d.dnd || false
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: poll.running = true
    }

    Text {
        anchors.centerIn: parent
        text: notifRoot.notifIcon
        color: notifRoot.hasNotifications ? ThemeService.yellow : ThemeService.fg
        font.family: Theme.monoFont
        font.pixelSize: 18
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached({command: ["swaync-client", "-t", "-sw"]})
            else
                Quickshell.execDetached({command: ["swaync-client", "-d", "-sw"]})
        }
    }
}
