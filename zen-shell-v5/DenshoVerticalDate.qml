import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * DenshoVerticalDate v7.0.0-alpha.2 — vertical kanji year column
 *
 * A small Item meant to sit beside the existing Clock time display.
 * Shows the year as vertical kanji digits (e.g. 二〇二六) with a thin
 * sumi-ink divider, plus the day-of-week kanji in shu-iro accent.
 *
 * Visibility:
 *   visible: DenshoService.useVerticalDate
 *
 * Sizing:
 *   - Width: 22-28px (varies with year-digit count)
 *   - Height: matches the host clock label height
 *
 * Suggested mount point: Clock.qml — insert as a leading child in the
 * inner RowLayout, before iconText / clockText.
 *
 * Wala tayong babawasan — when useVerticalDate is false, Item collapses
 * to zero width (does not affect Clock layout).
 */
Item {
    id: root

    // Drive the displayed date from a property rather than recomputing
    // on each child — host can pass `now` from its existing time tick.
    property date now: new Date()

    visible: DenshoService.useVerticalDate
    implicitWidth:  visible ? 26 : 0
    implicitHeight: visible ? 60 : 0

    readonly property var yearDigits: DenshoService.yearKanji(now.getFullYear())

    Row {
        anchors.fill: parent
        spacing: 4

        // Year digits column — vertical, top-to-bottom
        Column {
            id: yearCol
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: root.yearDigits
                delegate: Text {
                    text: modelData
                    color: ThemeService ? ThemeService.fg : "#1A1410"
                    font.pixelSize: 11
                    font.family: "Noto Serif CJK JP, serif"
                    horizontalAlignment: Text.AlignHCenter
                    width: 14
                    height: 13
                }
            }
        }

        // Thin sumi divider
        Rectangle {
            width: 0.5
            height: parent.height * 0.7
            anchors.verticalCenter: parent.verticalCenter
            color: ThemeService ? ThemeService.fg : "#1A1410"
            opacity: 0.5
        }

        // Day-of-week kanji in shu-iro
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: DenshoService.weekdayKanji(root.now.getDay())
            color: ThemeService ? ThemeService.red : "#B85540"
            font.pixelSize: 14
            font.family: "Noto Serif CJK JP, serif"
            font.weight: Font.Medium
            width: 14
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
