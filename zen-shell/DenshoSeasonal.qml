import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * DenshoSeasonal v7.0.0-alpha.2 — vertical kanji seasonal column
 *
 * Renders a thin, low-opacity vertical column on the right edge of the
 * desktop showing the current 24-sekki (二十四節気) seasonal kanji.
 *
 * Auto-rotates every ~15 days driven by DenshoService.currentSekki.
 *
 * Visibility:
 *   visible: DenshoService.useSeasonalKanji
 *
 * Visual conventions:
 *   - Right-edge anchored, 50% screen height
 *   - Kanji column reads top-to-bottom: 立夏の候 (one character per row)
 *   - Color: ThemeService.fg at 18% opacity (Densho Hi)
 *           or ThemeService.fg at 22% opacity (Densho Yoru)
 *   - Font: serif preferred for traditional feel; falls back to system
 *
 * Wala tayong babawasan — instantiating this component is opt-in via
 * the seasonalKanji sub-toggle. When useSeasonalKanji is false, the
 * Item collapses to zero size and renders nothing.
 *
 * Suggested mount point: DesktopWidgets.qml (right edge, fixed Y center).
 */
Item {
    id: root

    visible: DenshoService.useSeasonalKanji
    width: visible ? 28 : 0
    height: visible ? Math.min(parent ? parent.height * 0.5 : 360, 360) : 0

    // Build the character array dynamically: kanji of the sekki + "の候"
    // e.g. ["立", "夏", "の", "候"] for Rikka.
    readonly property var displayChars: {
        if (!DenshoService.currentSekki) return []
        const k = DenshoService.currentSekki.kanji + "の候"
        const out = []
        for (var i = 0; i < k.length; i++) out.push(k.charAt(i))
        return out
    }

    // Slightly higher opacity in dark mode so it stays visible against
    // the sumi ground (which absorbs subtle text more aggressively).
    readonly property real charOpacity: {
        // Heuristic: if bg0 is dark, use 0.22; else 0.18.
        if (!ThemeService) return 0.18
        const c = ThemeService.bg0
        const luma = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        return luma < 0.5 ? 0.22 : 0.18
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.displayChars
            delegate: Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: modelData
                color: ThemeService ? ThemeService.fg : "#1A1410"
                opacity: root.charOpacity
                font.pixelSize: 18
                font.family: "Noto Serif CJK JP, serif"
                font.weight: Font.Normal
                horizontalAlignment: Text.AlignHCenter
                width: 24
            }
        }
    }

    // Optional tooltip on hover — surfaces the romaji + english reading
    // so users learn the sekki passively.
    MouseArea {
        id: tip
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        acceptedButtons: Qt.NoButton
    }

    Rectangle {
        visible: tip.containsMouse && DenshoService.currentSekki
        anchors.right: parent.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: tipCol.implicitWidth + 20
        height: tipCol.implicitHeight + 14
        radius: 6
        color: ThemeService ? ThemeService.bg2 : "#FBF5E5"
        border.color: ThemeService ? ThemeService.bg4 : "#D4C9A8"
        border.width: 1
        opacity: 0.95

        Column {
            id: tipCol
            anchors.centerIn: parent
            spacing: 2

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: DenshoService.currentSekki ? DenshoService.currentSekki.kanji : ""
                color: ThemeService ? ThemeService.red : "#B85540"
                font.pixelSize: 16
                font.family: "Noto Serif CJK JP, serif"
                font.weight: Font.Medium
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: DenshoService.currentSekki ? DenshoService.currentSekki.romaji : ""
                color: ThemeService ? ThemeService.fg : "#1A1410"
                font.pixelSize: 11
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: DenshoService.currentSekki ? DenshoService.currentSekki.english : ""
                color: ThemeService ? ThemeService.grey1 : "#6F4E37"
                font.pixelSize: 10
                font.italic: true
            }
        }

        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
}
