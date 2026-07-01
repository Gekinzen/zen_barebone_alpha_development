import QtQuick
import QtQuick.Layouts

/*
 * DenshoPageHeader v7.0.0-alpha.11
 *
 * Unified bilingual page header for Settings pages. When DenshoService.
 * denshoMode is enabled, renders kanji-primary with romaji + English
 * subtitle. When disabled, falls back to plain English title.
 *
 * Includes the Densho brush separator below the title for visual
 * grouping. The brush is conditionally rendered (only when
 * brushSeparators toggle is on) so users who want minimal aesthetics
 * can disable just the brush without disabling Densho mode entirely.
 *
 * Usage:
 *
 *   DenshoPageHeader {
 *       Layout.fillWidth: true
 *       title: "General"
 *       subtitle: "Window gaps, borders, layout, tearing, snap"
 *       kanji: "一般"
 *       romaji: "Ippan"
 *   }
 *
 * Wala tayong babawasan — fully additive component. Pages migrate
 * to this header at their own pace; existing inline header code
 * keeps working until pages adopt the new component.
 */
Item {
    id: header

    property string title: ""
    property string subtitle: ""
    property string kanji: ""           // optional — only shown when denshoMode is on
    property string romaji: ""          // optional — pronunciation hint

    implicitHeight: contentCol.implicitHeight + 16

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 4

        // ── Title row ──
        // In Densho mode: kanji is primary (large), English is secondary
        // In normal mode: English is primary (large)
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Kanji block — only visible when Densho mode AND kanji set
            ColumnLayout {
                visible: DenshoService.denshoMode && header.kanji.length > 0
                spacing: 0

                Text {
                    text: header.kanji
                    font.family: "Noto Sans CJK JP"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: ThemeService.fg
                }

                Text {
                    text: header.romaji
                    visible: header.romaji.length > 0
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.italic: true
                    color: ThemeService.alpha(ThemeService.fg, 0.55)
                }
            }

            // English title — primary in normal mode, secondary in Densho mode
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: header.title
                    font.family: Theme.fontFamily
                    font.pixelSize: DenshoService.denshoMode
                                    && header.kanji.length > 0
                                    ? 16
                                    : 22
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                }

                Text {
                    text: header.subtitle
                    visible: header.subtitle.length > 0
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.alpha(ThemeService.fg, 0.65)
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        // ── Densho brush separator ──
        // Only renders when both denshoMode AND brushSeparators are on.
        DenshoBrushSeparator {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: DenshoService.denshoMode
                     && DenshoService.brushSeparators
        }
    }
}
