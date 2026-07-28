/*
 * SettingRow — Single row with label/description + control slot on right
 *
 * v8.0.0-alpha-hf177 — OPTIONAL LEADING ICON
 *
 * "sa system trays naman paayos yun spacing nung icon and word like sound
 *  dapat may spacing katulad ng ginawa natin formatting sa bar modules"
 *
 * SysRowPage was building its Visible-Modules rows as
 *
 *     label: modelData.icon + "  " + modelData.label
 *
 * — one Text, one font. `Theme.fontFamily` has no Nerd Font glyphs, so the
 * glyph came from a fontconfig fallback while the two spaces were measured
 * in the primary font; at 13px that gap collapses to nothing and you get
 * "󰕾Sound" with the icon welded to the word. Padding the string with more
 * spaces would not fix it either — the mix of fallback advance widths is
 * what makes the gap unpredictable.
 *
 * BarModulesPage never had this problem because HMRow gives the icon its
 * own Text with its own family and lets a RowLayout `spacing` own the gap.
 * SettingRow now offers the same slot, so the two pages match.
 *
 * Wala tayong babawasan — `icon` defaults to "", the Text is `visible:
 * false` at that width, and the RowLayout collapses it. Every existing
 * SettingRow in the shell renders byte-identically.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property string label: ""
    property string description: ""
    // v8.0.0-alpha-hf177 — optional Nerd Font glyph, drawn in its own Text.
    property string icon: ""
    // Matches HMRow: lets a caller pass e.g. "Material Symbols Rounded".
    property string iconFont: "JetBrainsMono Nerd Font"
    default property alias control: controlSlot.data

    Layout.fillWidth: true
    implicitHeight: 48
    color: rowMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.03) : "transparent"
    radius: 6

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        // ── v8.0.0-alpha-hf177 — leading icon ──
        // Fixed 20px box + the RowLayout's 12px spacing gives every row the
        // same optical gutter regardless of how wide the glyph renders in
        // whichever font ends up serving it.
        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: 15
            color: LookService.textDimColor(ThemeService.grey0)
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: root.icon.length > 0 ? 20 : 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: ThemeService.fg
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: root.description
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.grey1
                visible: root.description.length > 0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Item {
            id: controlSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
