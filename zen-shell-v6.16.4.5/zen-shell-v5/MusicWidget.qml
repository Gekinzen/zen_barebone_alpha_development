import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Rectangle {
    id: musicRoot
    implicitWidth: visible ? musicText.implicitWidth + 24 : 0
    height: Theme.moduleHeight
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
    color: Theme.alpha(Theme.bg0, 0.9)
    border.width: 1
    border.color: Theme.bg1

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
        color: Theme.pink
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
