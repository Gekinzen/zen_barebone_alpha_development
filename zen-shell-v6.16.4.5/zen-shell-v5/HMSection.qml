import QtQuick
import QtQuick.Layouts

/*
 * HMSection — HyprMod-style section
 *
 * Layout:
 *   UPPERCASE TITLE (small, muted)
 *   ┌────────────────────────────────┐
 *   │  content rows                   │
 *   │  ─────────────────              │ (separators handled per-row)
 *   │  content rows                   │
 *   └────────────────────────────────┘
 *
 * Matches the HyprMod screenshot: "GAPS", "BORDERS", "BORDER COLORS", etc.
 * The card body has a subtle border + bg tint so it reads as a cohesive
 * group, separate from other sections.
 */
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: contentLayout.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 8

        // Section header (uppercase small text, HyprMod style)
        Text {
            visible: root.title.length > 0
            text: root.title
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
            color: ThemeService.grey0
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.topMargin: 4
            Layout.bottomMargin: 2
        }

        Text {
            visible: root.subtitle.length > 0
            text: root.subtitle
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: ThemeService.grey1
            Layout.fillWidth: true
            Layout.leftMargin: 4
            wrapMode: Text.WordWrap
        }

        // Card body
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: contentLayout.implicitHeight + 12
            color: ThemeService.alpha(ThemeService.bg1, 0.55)
            radius: 12
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2
            }
        }
    }
}
