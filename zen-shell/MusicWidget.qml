import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*
 * MusicWidget v7.0.0-beta.1-hf95.3 (Karui)
 *
 * v7.0.0-beta.1-hf95.3:
 *   - Vertical bar: set an explicit width so the click MouseArea has a
 *     real hit area (play/pause taps were swallowed in the vertical host).
 *   - Added a hover tooltip (now-playing track + click controls) using the
 *     proven SysRow PopupWindow pattern. Wala tayong babawasan.
 *
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

    // v7.0.0-beta.1-hf93: explicit vertical mode. Vertical → a compact
    // play/pause icon (the full track text doesn't fit a thin bar; the
    // music strings carry the visual). Default false → original pill.
    property bool zenVertical: false

    implicitWidth: zenVertical ? Math.round(Theme.moduleHeight) : (visible ? musicText.implicitWidth + 24 : 0)
    implicitHeight: zenVertical ? (visible ? Math.round(Theme.moduleHeight) : 0) : Theme.moduleHeight
    // v7.0.0-beta.1-hf95.3: set an explicit width, not just implicitWidth.
    // In the vertical bar this module is loaded by BarVertical's
    // VerticalModuleHost → Loader, which sizes itself to the item. Without
    // an explicit width the click MouseArea ended up with no reliable hit
    // area, so play/pause taps were swallowed. Clock.qml already sets
    // explicit width/height for exactly this reason — mirror it here. In a
    // horizontal RowLayout this is overridden by the layout, so the
    // original horizontal behaviour is unchanged. Wala tayong babawasan.
    width: implicitWidth
    height: implicitHeight
    radius: Theme.styleMode === "round" ? (zenVertical ? width / 2 : height / 2) : Theme.moduleRadius

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
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        id: musicText
        anchors.centerIn: parent
        text: musicRoot.zenVertical
              ? (isPlaying ? "\uf04b" : "\uf04c")
              : ((isPlaying ? "\uf04b  " : "\uf04c  ") + (nowPlaying.length > 35 ? nowPlaying.substring(0, 32) + "..." : nowPlaying))
        color: ThemeService.pink
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }

    MouseArea {
        id: musicMouse
        anchors.fill: parent
        hoverEnabled: true            // hf95.3: needed for the hover tooltip below
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (!activePlayer) return
            if (mouse.button === Qt.LeftButton) activePlayer.playPause()
            else if (mouse.button === Qt.RightButton) activePlayer.next()
            else activePlayer.previous()
        }
    }

    // v7.0.0-beta.1-hf95.3: hover tooltip. On a vertical bar only the
    // play/pause glyph fits, so hovering reveals what is actually playing
    // (full, untruncated) plus the click controls. Uses the same
    // PopupWindow pattern that already works for SysRow's tooltips
    // (anchor.item + PanelState anchor edges/gravity) rather than a bare
    // module-anchored popup. Shows in both orientations — in horizontal it
    // surfaces the full title that the inline label truncates at 35 chars.
    PopupWindow {
        id: musicTip
        anchor.item: musicRoot
        anchor.edges: PanelState.popupAnchorEdges
        anchor.gravity: PanelState.popupAnchorGravity
        visible: musicMouse.containsMouse && musicRoot.nowPlaying !== ""
        implicitWidth: Math.max(musicTipCol.implicitWidth + 24, 180)
        implicitHeight: musicTipCol.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g,
                           ThemeService.bg0.b, 0.95)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)

            Column {
                id: musicTipCol
                anchors.centerIn: parent
                spacing: 3

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: musicRoot.isPlaying ? "Now playing" : "Paused"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: musicRoot.nowPlaying
                          + "\n• Click: play / pause"
                          + "\n• Right-click: next"
                          + "\n• Middle-click: previous"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.alpha(ThemeService.fg, 0.7)
                }
            }
        }
    }
}
