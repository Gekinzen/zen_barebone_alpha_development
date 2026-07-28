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

    // v7.0.0-alpha.12-hf3: Replaced surrogate-pair Material codepoints
    // with proper Nerd Font glyphs that render reliably (since
    // MaterialIcons.materialAvailable is hardcoded false in alpha.10-hf6,
    // the old surrogate pairs were rendering as empty boxes).
    //
    //   Bell:       \uf0f3   (Nerd Font bell icon)
    //   Bell-slash: \uf1f6   (Nerd Font bell-slash for DND)
    property bool hasNotifications: false
    property bool dndEnabled: false
    property int  unreadCount: 0

    property string bellGlyph: dndEnabled ? "\uf1f6" : "\uf0f3"

    // v7.0.0-alpha.12: Primary source is NotificationService (native
    // zen-shell daemon). The swaync poll below is kept as defensive
    // fallback in case NotificationService isn't yet registered.
    Connections {
        target: NotificationService
        function onUnreadCountChanged() {
            notifRoot.unreadCount = NotificationService.unreadCount
            notifRoot.hasNotifications = NotificationService.unreadCount > 0
        }
        function onDndEnabledChanged() {
            notifRoot.dndEnabled = NotificationService.dndEnabled
        }
    }

    Component.onCompleted: {
        // Initial sync from NotificationService
        notifRoot.unreadCount = NotificationService.unreadCount
        notifRoot.hasNotifications = NotificationService.unreadCount > 0
        notifRoot.dndEnabled = NotificationService.dndEnabled
    }

    Process {
        id: poll
        command: ["swaync-client", "-swb"]
        running: false   // disabled by default in alpha.12 — NotificationService is primary
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    // Only adopt swaync state if NotificationService hasn't weighed in
                    if (NotificationService.notifications.length === 0) {
                        notifRoot.hasNotifications = (d.count || 0) > 0
                        notifRoot.unreadCount = d.count || 0
                        notifRoot.dndEnabled = d.dnd || false
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: false   // disabled in alpha.12
        repeat: true
        onTriggered: poll.running = true
    }

    // ── Bell glyph ──
    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        id: bellText
        anchors.centerIn: parent
        text: notifRoot.bellGlyph
        color: notifRoot.dndEnabled
               ? ThemeService.alpha(ThemeService.fg, 0.5)
               : (notifRoot.hasNotifications
                  ? ThemeService.yellow
                  : ThemeService.fg)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // ── Count badge — top-right of icon ──
    // Visible only when there are unread notifications AND DND is off
    Rectangle {
        visible: notifRoot.unreadCount > 0 && !notifRoot.dndEnabled
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.rightMargin: 1

        // Width grows for double-digit counts; minimum is square
        width: Math.max(14, countLabel.implicitWidth + 6)
        height: 14
        radius: 7
        color: ThemeService.red
        border.width: 1
        border.color: LookService.surfaceColor(ThemeService.bg0, 1.0)

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            id: countLabel
            anchors.centerIn: parent
            text: notifRoot.unreadCount > 9 ? "9+" : notifRoot.unreadCount.toString()
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: Font.Bold
            color: "#ffffff"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            // v7.0.0-beta.1-hf5: left-click toggles via PanelState
            // singleton directly — no external bash/IPC roundtrip,
            // no race condition, no stacking on rapid clicks.
            //   right-click = toggle DND directly
            if (mouse.button === Qt.LeftButton) {
                PanelState.toggleNotifPanel()
            } else {
                NotificationService.dndEnabled = !NotificationService.dndEnabled
            }
        }
    }
}
