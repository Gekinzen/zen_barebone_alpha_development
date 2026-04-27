import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*
 * MusicWidget v6.16.4.12.6 (Hikari · Frosted)
 *
 * v6.16.4.12.6:
 *   - Background switched from Theme.alpha(Theme.bg0, 0.9) → ThemeService.bg0
 *     at alpha 0.32 so it falls below Hyprland's `ignore_alpha 0.5` blur
 *     threshold for the zen-shell-bar layer. Result: Hyprland's layer blur
 *     shows through and the module reads as part of the bar instead of a
 *     solid pill embedded in it.
 *   - Border/text colors now bind to ThemeService (not the old Theme
 *     singleton) so live theme switches and the new matugen wallpaper-sync
 *     repaint immediately. Theme.fontFamily / Theme.moduleHeight kept as-is
 *     since those layout tokens haven't moved.
 *   - All click logic, MPRIS bindings, and visibility rules preserved.
 *     Wala tayo babawasan.
 */
Rectangle {
    id: musicRoot
    implicitWidth: visible ? musicText.implicitWidth + 24 : 0
    height: Theme.moduleHeight
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius

    // Frosted: low alpha so Hyprland layer blur passes through
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.32)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.10)

    // Subtle inner highlight for depth (top edge catches light)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.04)
    }

    property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property string nowPlaying: {
        if (!activePlayer) return ""
        const a = activePlayer.trackArtist || ""
        const t = activePlayer.trackTitle || ""
        if (a && t) return a + " - " + t
        return t || ""
    }
    property bool isPlaying: activePlayer ? activePlayer.playbackState === MprisPlaybackState.Playing : false

    visible: nowPlaying !== ""

    Text {
        id: musicText
        anchors.centerIn: parent
        text: (isPlaying ? "\uf04b  " : "\uf04c  ") + (nowPlaying.length > 35 ? nowPlaying.substring(0, 32) + "..." : nowPlaying)
        color: ThemeService.pink
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (!activePlayer) return
            if (mouse.button === Qt.LeftButton) activePlayer.playPause()
            else if (mouse.button === Qt.RightButton) activePlayer.next()
            else activePlayer.previous()
        }
    }
}
